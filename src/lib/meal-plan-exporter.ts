/**
 * meal-plan-exporter.ts — Generate KitchenOS-format meal plan and shopping list
 * markdown files for export to the KitchenOS Obsidian vault.
 */

import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';
import type { Database as DatabaseType } from 'better-sqlite3';

// ── Types ─────────────────────────────────────────────────────────

export interface MealPlanItem {
  day: string;
  meal: string;
  recipe_title: string;
}

export interface ShoppingItem {
  ingredient: string;
  amount: number | null;
  unit: string | null;
  category: string | null;
}

// ── Day ordering ──────────────────────────────────────────────────

const DAY_ORDER = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const MEAL_ORDER = ['breakfast', 'lunch', 'dinner'];
const CATEGORY_ORDER = ['produce', 'dairy', 'meat', 'pantry', 'frozen', 'bakery', 'other'];

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// ── Meal Plan Markdown ────────────────────────────────────────────

/**
 * Generate a KitchenOS-format meal plan markdown file.
 * Uses wiki links for recipe references so KitchenOS can resolve them.
 */
export function generateMealPlanMarkdown(week: string, items: MealPlanItem[]): string {
  // Extract week number from format like "2026-W08"
  const weekNum = week.replace(/^\d{4}-W/, '');

  let md = `# Meal Plan - Week ${weekNum}\n\n`;

  // Group items by day
  const byDay = new Map<string, MealPlanItem[]>();
  for (const item of items) {
    const day = item.day.toLowerCase();
    if (!byDay.has(day)) byDay.set(day, []);
    byDay.get(day)!.push(item);
  }

  // Output days in order
  for (const day of DAY_ORDER) {
    const dayItems = byDay.get(day);
    if (!dayItems) continue;

    md += `## ${capitalize(day)}\n`;

    // Sort meals within day
    dayItems.sort((a, b) => MEAL_ORDER.indexOf(a.meal.toLowerCase()) - MEAL_ORDER.indexOf(b.meal.toLowerCase()));

    for (const item of dayItems) {
      md += `### ${capitalize(item.meal)}\n`;
      md += `[[${item.recipe_title}]]\n\n`;
    }
  }

  return md;
}

// ── Shopping List Markdown ────────────────────────────────────────

/**
 * Generate a shopping list markdown file grouped by category
 * with checkbox format for easy checking off.
 */
export function generateShoppingListMarkdown(week: string, items: ShoppingItem[]): string {
  const weekNum = week.replace(/^\d{4}-W/, '');

  let md = `# Shopping List - Week ${weekNum}\n\n`;

  // Group by category
  const byCategory = new Map<string, ShoppingItem[]>();
  for (const item of items) {
    const cat = item.category || 'other';
    if (!byCategory.has(cat)) byCategory.set(cat, []);
    byCategory.get(cat)!.push(item);
  }

  // Output categories in order
  for (const cat of CATEGORY_ORDER) {
    const catItems = byCategory.get(cat);
    if (!catItems) continue;

    md += `## ${capitalize(cat)}\n`;

    for (const item of catItems) {
      const parts: string[] = [];
      if (item.amount != null) parts.push(String(item.amount));
      if (item.unit) parts.push(item.unit);
      parts.push(item.ingredient);
      md += `- [ ] ${parts.join(' ')}\n`;
    }

    md += '\n';
  }

  return md;
}

// ── Vault Export ──────────────────────────────────────────────────

/**
 * Write meal plan and shopping list files to the KitchenOS Obsidian vault.
 */
export function exportToVault(
  vaultPath: string,
  week: string,
  items: MealPlanItem[],
  shoppingItems: ShoppingItem[]
): { mealPlanPath: string; shoppingListPath: string } {
  const mealPlansDir = join(vaultPath, 'Meal Plans');
  if (!existsSync(mealPlansDir)) mkdirSync(mealPlansDir, { recursive: true });

  const mealPlanPath = join(mealPlansDir, `${week}.md`);
  const shoppingListPath = join(mealPlansDir, `${week}-Shopping.md`);

  writeFileSync(mealPlanPath, generateMealPlanMarkdown(week, items), 'utf-8');
  writeFileSync(shoppingListPath, generateShoppingListMarkdown(week, shoppingItems), 'utf-8');

  return { mealPlanPath, shoppingListPath };
}

// ── CLI Entry Point ───────────────────────────────────────────────

/**
 * Export a meal plan from the database to the KitchenOS vault.
 * Usage: npx ts-node src/lib/meal-plan-exporter.ts --week 2026-W08
 */
async function main(): Promise<void> {
  const weekIdx = process.argv.indexOf('--week');
  if (weekIdx === -1 || !process.argv[weekIdx + 1]) {
    console.error('Usage: npx ts-node src/lib/meal-plan-exporter.ts --week <YYYY-Wnn>');
    process.exit(1);
  }
  const week = process.argv[weekIdx + 1];

  // Dynamic imports to avoid requiring these for library-only usage
  const { db, config } = await import('../lib');

  const vaultPath = config.kitchenOsVaultPath;
  if (!vaultPath || !existsSync(vaultPath)) {
    console.error(`KitchenOS vault not found at: ${vaultPath}`);
    process.exit(1);
  }

  // Query meal plan items
  const planRow = (db as DatabaseType).prepare(
    'SELECT id FROM meal_plans WHERE week = ? AND test_run IS NULL'
  ).get(week) as { id: number } | undefined;

  if (!planRow) {
    console.error(`No meal plan found for week: ${week}`);
    process.exit(1);
  }

  const items = (db as DatabaseType).prepare(
    'SELECT day, meal, recipe_title FROM meal_plan_items WHERE meal_plan_id = ? ORDER BY day, meal'
  ).all(planRow.id) as MealPlanItem[];

  const shoppingItems = (db as DatabaseType).prepare(
    'SELECT ingredient, amount, unit, category FROM shopping_items WHERE meal_plan_id = ?'
  ).all(planRow.id) as ShoppingItem[];

  // Export
  const result = exportToVault(vaultPath, week, items, shoppingItems);
  console.log(`Exported meal plan to: ${result.mealPlanPath}`);
  console.log(`Exported shopping list to: ${result.shoppingListPath}`);

  // Update exported_at
  (db as DatabaseType).prepare(
    'UPDATE meal_plans SET exported_at = datetime("now") WHERE id = ?'
  ).run(planRow.id);
}

// Run if called directly
if (require.main === module) {
  main().catch(err => {
    console.error('Export failed:', err.message);
    process.exit(1);
  });
}
