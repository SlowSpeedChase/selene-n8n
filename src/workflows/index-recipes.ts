/**
 * index-recipes.ts — Scan the KitchenOS Obsidian vault, parse recipe files,
 * and upsert them into Selene's SQLite database.  Also indexes meal plan files.
 *
 * Usage:
 *   npx ts-node src/workflows/index-recipes.ts            # index recipes + meal plans
 *   npx ts-node src/workflows/index-recipes.ts --recipes   # recipes only
 *   npx ts-node src/workflows/index-recipes.ts --meals     # meal plans only
 */

import { readdirSync, readFileSync, existsSync } from 'fs';
import { join, relative } from 'path';
import { Database as DatabaseType } from 'better-sqlite3';
import { createWorkflowLogger, db as defaultDb, config } from '../lib';
import { parseRecipeFrontmatter, parseRecipeCookingMode } from '../lib/recipe-parser';
import type { RecipeRow } from '../lib/recipe-parser';
import type { WorkflowResult } from '../types';

const log = createWorkflowLogger('index-recipes');

// ── Helpers ──────────────────────────────────────────────────────

/** Recursively collect all .md files under a directory. */
function collectMarkdownFiles(dir: string): string[] {
  const files: string[] = [];

  if (!existsSync(dir)) return files;

  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    // Skip hidden directories (.history, .obsidian, .trash, etc.)
    if (entry.name.startsWith('.')) continue;

    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...collectMarkdownFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      files.push(fullPath);
    }
  }

  return files;
}

/** Detect whether a file uses YAML frontmatter format. */
function hasFrontmatter(content: string): boolean {
  return content.trimStart().startsWith('---');
}

/** Valid difficulty values for the database CHECK constraint. */
const VALID_DIFFICULTIES = new Set(['easy', 'medium', 'hard']);

/**
 * Normalize a difficulty string to match the database CHECK constraint.
 * Handles: "Easy" -> "easy", "Medium (with explanation)" -> "medium", null -> null
 */
function normalizeDifficulty(difficulty: string | null): string | null {
  if (!difficulty) return null;
  const lower = difficulty.toLowerCase().trim();
  for (const valid of VALID_DIFFICULTIES) {
    if (lower === valid || lower.startsWith(valid)) {
      return valid;
    }
  }
  return null; // Unknown difficulty — store as null rather than fail
}

// ── SQL Queries ──────────────────────────────────────────────────

const SQL = {
  selectRecipeByPath:
    'SELECT id, content_hash FROM recipes WHERE file_path = ? AND test_run IS NULL',

  insertRecipe: `
    INSERT INTO recipes (
      title, content_hash, source_url, source_channel, file_path,
      servings, prep_time_minutes, cook_time_minutes, difficulty, cuisine, protein,
      dish_type, meal_occasions, dietary, ingredients, calories, nutrition_protein,
      carbs, fat, indexed_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,

  updateRecipe: `
    UPDATE recipes SET
      title = ?, content_hash = ?, source_url = ?, source_channel = ?,
      servings = ?, prep_time_minutes = ?, cook_time_minutes = ?, difficulty = ?,
      cuisine = ?, protein = ?, dish_type = ?, meal_occasions = ?, dietary = ?,
      ingredients = ?, calories = ?, nutrition_protein = ?, carbs = ?, fat = ?,
      updated_at = ?
    WHERE file_path = ? AND test_run IS NULL`,

  selectMealPlanByWeek:
    'SELECT id FROM meal_plans WHERE week = ? AND test_run IS NULL',

  insertMealPlan:
    'INSERT INTO meal_plans (week, status, created_at) VALUES (?, ?, ?)',

  insertMealPlanItem:
    'INSERT OR REPLACE INTO meal_plan_items (meal_plan_id, day, meal, recipe_id, recipe_title) VALUES (?, ?, ?, ?, ?)',

  selectRecipeByTitle:
    'SELECT id FROM recipes WHERE title = ? AND test_run IS NULL',
} as const;

// ── indexRecipes ─────────────────────────────────────────────────

/**
 * Scan the KitchenOS vault's Recipes/ directory, parse each .md file,
 * and upsert into the recipes table.
 */
export function indexRecipes(vaultPath?: string): WorkflowResult {
  return indexRecipesWithDb(vaultPath || config.kitchenOsVaultPath, defaultDb);
}

/**
 * Testable version that accepts an explicit database connection.
 */
export function indexRecipesWithDb(vaultPath: string, database: DatabaseType): WorkflowResult {
  log.info({ vaultPath }, 'Starting recipe indexing');

  const recipesDir = join(vaultPath, 'Recipes');
  const files = collectMarkdownFiles(recipesDir);

  log.info({ fileCount: files.length }, 'Found recipe files');

  if (files.length === 0) {
    log.info('No recipe files found');
    return { processed: 0, errors: 0, details: [] };
  }

  const result: WorkflowResult = { processed: 0, errors: 0, details: [] };

  for (const filePath of files) {
    try {
      const content = readFileSync(filePath, 'utf-8');
      const relPath = relative(vaultPath, filePath);

      // Parse recipe based on format
      let recipe: RecipeRow;
      if (hasFrontmatter(content)) {
        recipe = parseRecipeFrontmatter(content, relPath);
      } else {
        recipe = parseRecipeCookingMode(content, relPath);
      }

      // Normalize difficulty to match DB CHECK constraint
      recipe.difficulty = normalizeDifficulty(recipe.difficulty);

      // Check if recipe already exists
      const existing = database
        .prepare(SQL.selectRecipeByPath)
        .get(relPath) as { id: number; content_hash: string } | undefined;

      if (existing) {
        if (existing.content_hash === recipe.content_hash) {
          // Unchanged — skip
          log.debug({ filePath: relPath }, 'Recipe unchanged, skipping');
          continue;
        }

        // Changed — update
        database.prepare(SQL.updateRecipe).run(
          recipe.title,
          recipe.content_hash,
          recipe.source_url,
          recipe.source_channel,
          recipe.servings,
          recipe.prep_time_minutes,
          recipe.cook_time_minutes,
          recipe.difficulty,
          recipe.cuisine,
          recipe.protein,
          recipe.dish_type,
          recipe.meal_occasions,
          recipe.dietary,
          recipe.ingredients,
          recipe.calories,
          recipe.nutrition_protein,
          recipe.carbs,
          recipe.fat,
          new Date().toISOString(),
          relPath
        );

        log.info({ id: existing.id, filePath: relPath }, 'Updated changed recipe');
        result.processed++;
        result.details.push({ id: existing.id, success: true });
      } else {
        // New — insert
        const insertResult = database.prepare(SQL.insertRecipe).run(
          recipe.title,
          recipe.content_hash,
          recipe.source_url,
          recipe.source_channel,
          recipe.file_path,
          recipe.servings,
          recipe.prep_time_minutes,
          recipe.cook_time_minutes,
          recipe.difficulty,
          recipe.cuisine,
          recipe.protein,
          recipe.dish_type,
          recipe.meal_occasions,
          recipe.dietary,
          recipe.ingredients,
          recipe.calories,
          recipe.nutrition_protein,
          recipe.carbs,
          recipe.fat,
          new Date().toISOString()
        );

        const newId = insertResult.lastInsertRowid as number;
        log.info({ id: newId, title: recipe.title, filePath: relPath }, 'Inserted new recipe');
        result.processed++;
        result.details.push({ id: newId, success: true });
      }
    } catch (err) {
      const error = err as Error;
      const relPath = relative(vaultPath, filePath);
      log.error({ filePath: relPath, err: error }, 'Failed to index recipe');
      result.errors++;
      result.details.push({ id: 0, success: false, error: error.message });
    }
  }

  log.info(
    { processed: result.processed, errors: result.errors, total: files.length },
    'Recipe indexing complete'
  );
  return result;
}

// ── Meal Plan Parsing ────────────────────────────────────────────

interface MealPlanEntry {
  day: string;
  meal: string;
  recipeTitle: string;
}

/** Valid day names for the database constraint. */
const VALID_DAYS = new Set([
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
]);

/** Valid meal names for the database constraint. */
const VALID_MEALS = new Set(['breakfast', 'lunch', 'dinner']);

/**
 * Parse a meal plan markdown file into structured entries.
 *
 * Expected format:
 *   ## Monday (Feb 10)
 *   ### Breakfast
 *   [[Recipe Name]]
 */
function parseMealPlanContent(content: string): MealPlanEntry[] {
  const entries: MealPlanEntry[] = [];
  const lines = content.split('\n');

  let currentDay: string | null = null;
  let currentMeal: string | null = null;

  for (const line of lines) {
    const trimmed = line.trim();

    // Match day header: ## Monday (...)  or  ## Monday
    const dayMatch = trimmed.match(/^##\s+(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\b/i);
    if (dayMatch) {
      currentDay = dayMatch[1].toLowerCase();
      currentMeal = null;
      continue;
    }

    // Match meal header: ### Breakfast / ### Lunch / ### Dinner
    const mealMatch = trimmed.match(/^###\s+(Breakfast|Lunch|Dinner)\b/i);
    if (mealMatch) {
      currentMeal = mealMatch[1].toLowerCase();
      continue;
    }

    // Match ### Notes — reset meal context so notes lines aren't captured
    if (/^###\s+Notes\b/i.test(trimmed)) {
      currentMeal = null;
      continue;
    }

    // Skip empty lines, code blocks, buttons
    if (!trimmed || trimmed.startsWith('```') || trimmed.startsWith('#')) {
      continue;
    }

    // We're inside a day + meal section
    if (currentDay && currentMeal && VALID_DAYS.has(currentDay) && VALID_MEALS.has(currentMeal)) {
      // Extract wiki link: [[Recipe Name]]
      const wikiMatch = trimmed.match(/\[\[([^\]]+)\]\]/);
      if (wikiMatch) {
        entries.push({
          day: currentDay,
          meal: currentMeal,
          recipeTitle: wikiMatch[1].trim(),
        });
      }
      // Plain text that isn't a wiki link is ignored (e.g., "Just a sandwich")
      // since we can't meaningfully resolve it to a recipe
    }
  }

  return entries;
}

/** Extract ISO week string from filename, e.g. "2026-W07.md" → "2026-W07" */
function extractWeekFromFilename(filename: string): string | null {
  const match = filename.match(/(\d{4}-W\d{2})/);
  return match ? match[1] : null;
}

// ── indexMealPlans ───────────────────────────────────────────────

/**
 * Scan the KitchenOS vault's Meal Plans/ directory, parse each file,
 * and insert into meal_plans and meal_plan_items tables.
 * Existing meal plans are NOT overwritten (preserves user edits).
 */
export function indexMealPlans(vaultPath?: string): WorkflowResult {
  return indexMealPlansWithDb(vaultPath || config.kitchenOsVaultPath, defaultDb);
}

/**
 * Testable version that accepts an explicit database connection.
 */
export function indexMealPlansWithDb(vaultPath: string, database: DatabaseType): WorkflowResult {
  log.info({ vaultPath }, 'Starting meal plan indexing');

  const mealPlansDir = join(vaultPath, 'Meal Plans');
  const result: WorkflowResult = { processed: 0, errors: 0, details: [] };

  if (!existsSync(mealPlansDir)) {
    log.info('No Meal Plans directory found');
    return result;
  }

  const files = readdirSync(mealPlansDir)
    .filter(f => f.endsWith('.md'))
    .map(f => join(mealPlansDir, f));

  log.info({ fileCount: files.length }, 'Found meal plan files');

  if (files.length === 0) {
    return result;
  }

  for (const filePath of files) {
    try {
      const filename = filePath.split('/').pop() || '';
      const week = extractWeekFromFilename(filename);

      if (!week) {
        log.warn({ filename }, 'Could not extract week from filename, skipping');
        continue;
      }

      // Check if meal plan already exists
      const existing = database
        .prepare(SQL.selectMealPlanByWeek)
        .get(week) as { id: number } | undefined;

      if (existing) {
        log.debug({ week }, 'Meal plan already exists, skipping');
        continue;
      }

      // Read and parse
      const content = readFileSync(filePath, 'utf-8');
      const entries = parseMealPlanContent(content);

      // Insert meal plan
      const now = new Date().toISOString();
      const planResult = database.prepare(SQL.insertMealPlan).run(week, 'active', now);
      const planId = planResult.lastInsertRowid as number;

      log.info({ planId, week, entryCount: entries.length }, 'Inserted meal plan');

      // Insert items
      for (const entry of entries) {
        // Try to resolve recipe_id
        const recipeRow = database
          .prepare(SQL.selectRecipeByTitle)
          .get(entry.recipeTitle) as { id: number } | undefined;
        const recipeId = recipeRow ? recipeRow.id : null;

        database.prepare(SQL.insertMealPlanItem).run(
          planId,
          entry.day,
          entry.meal,
          recipeId,
          entry.recipeTitle
        );

        log.debug(
          { day: entry.day, meal: entry.meal, title: entry.recipeTitle, resolved: !!recipeId },
          'Inserted meal plan item'
        );
      }

      result.processed++;
      result.details.push({ id: planId, success: true });
    } catch (err) {
      const error = err as Error;
      log.error({ filePath, err: error }, 'Failed to index meal plan');
      result.errors++;
      result.details.push({ id: 0, success: false, error: error.message });
    }
  }

  log.info(
    { processed: result.processed, errors: result.errors },
    'Meal plan indexing complete'
  );
  return result;
}

// ── CLI Entry Point ──────────────────────────────────────────────

if (require.main === module) {
  const args = process.argv.slice(2);
  const recipesOnly = args.includes('--recipes');
  const mealsOnly = args.includes('--meals');
  const doRecipes = !mealsOnly;
  const doMeals = !recipesOnly;

  const results: { recipes?: WorkflowResult; mealPlans?: WorkflowResult } = {};

  if (doRecipes) {
    results.recipes = indexRecipes();
    console.log('Recipe indexing:', JSON.stringify(results.recipes, null, 2));
  }

  if (doMeals) {
    results.mealPlans = indexMealPlans();
    console.log('Meal plan indexing:', JSON.stringify(results.mealPlans, null, 2));
  }

  const totalErrors = (results.recipes?.errors || 0) + (results.mealPlans?.errors || 0);
  process.exit(totalErrors > 0 ? 1 : 0);
}
