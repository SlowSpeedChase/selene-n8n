/**
 * Tests for index-recipes workflow.
 *
 * Creates a temp vault directory with recipe files (both formats) and a meal
 * plan file, then runs indexRecipes and indexMealPlans against an in-memory
 * SQLite database.
 */

import { mkdirSync, writeFileSync, rmSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import Database, { Database as DatabaseType } from 'better-sqlite3';

// ── Helpers ──────────────────────────────────────────────────────

function createTempVault(): string {
  const base = join(tmpdir(), `selene-test-vault-${Date.now()}`);
  mkdirSync(join(base, 'Recipes', 'Cooking Mode'), { recursive: true });
  mkdirSync(join(base, 'Meal Plans'), { recursive: true });
  return base;
}

function createTestDb(): DatabaseType {
  const db = new Database(':memory:');
  db.pragma('journal_mode = WAL');

  // Create the recipes table
  db.exec(`
    CREATE TABLE recipes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      content_hash TEXT UNIQUE NOT NULL,
      source_url TEXT,
      source_channel TEXT,
      file_path TEXT NOT NULL,
      servings INTEGER,
      prep_time_minutes INTEGER,
      cook_time_minutes INTEGER,
      difficulty TEXT CHECK(difficulty IN ('easy', 'medium', 'hard')),
      cuisine TEXT,
      protein TEXT,
      dish_type TEXT,
      meal_occasions TEXT,
      dietary TEXT,
      ingredients TEXT NOT NULL,
      calories INTEGER,
      nutrition_protein INTEGER,
      carbs INTEGER,
      fat INTEGER,
      indexed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT,
      status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived')),
      test_run TEXT DEFAULT NULL
    );
    CREATE INDEX idx_recipes_content_hash ON recipes(content_hash);
    CREATE INDEX idx_recipes_test_run ON recipes(test_run);

    CREATE TABLE meal_plans (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      week TEXT NOT NULL UNIQUE,
      status TEXT DEFAULT 'draft' CHECK(status IN ('draft', 'active', 'completed')),
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT,
      exported_at TEXT,
      test_run TEXT DEFAULT NULL
    );
    CREATE INDEX idx_meal_plans_week ON meal_plans(week);

    CREATE TABLE meal_plan_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      meal_plan_id INTEGER NOT NULL,
      day TEXT NOT NULL CHECK(day IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday')),
      meal TEXT NOT NULL CHECK(meal IN ('breakfast', 'lunch', 'dinner')),
      recipe_id INTEGER,
      recipe_title TEXT NOT NULL,
      notes TEXT,
      FOREIGN KEY (meal_plan_id) REFERENCES meal_plans(id) ON DELETE CASCADE,
      FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE SET NULL,
      UNIQUE(meal_plan_id, day, meal)
    );
    CREATE INDEX idx_meal_plan_items_plan ON meal_plan_items(meal_plan_id);
  `);

  return db;
}

// ── Test Fixtures ────────────────────────────────────────────────

const FRONTMATTER_RECIPE = `---
title: "Spaghetti Carbonara"
source_url: "https://example.com/carbonara"
source_channel: "TestKitchen"
prep_time: "10 min"
cook_time: "20 min"
servings: 4
difficulty: "medium"
cuisine: "Italian"
protein: "pork"
dish_type: "Pasta"
meal_occasion:
  - dinner
  - lunch
dietary:
  - nut-free
calories: 500
nutrition_protein: 25
carbs: 55
fat: 18
---

# Spaghetti Carbonara

> Classic Italian pasta.

## Ingredients

| Amount | Unit | Ingredient |
|--------|------|------------|
| 400 | g | spaghetti |
| 200 | g | guanciale |
| 4 | whole | egg yolks |
| 100 | g | pecorino romano |

## Instructions

1. Cook the pasta.
2. Fry the guanciale.
3. Combine.
`;

const COOKING_MODE_RECIPE = `# Quick Garlic Toast

Quick and easy garlic bread snack.

*snack, appetizer*

---

- *4 slices* bread
- *2 tbsp* butter
- *3 cloves* garlic

---

1. Toast the bread.
2. Spread butter and garlic.
3. Serve hot.

*Source: [Garlic Toast Video](https://example.com/toast) by SnackChef*
`;

const MEAL_PLAN_CONTENT = `# Meal Plan - Week 07 (Feb 10 - Feb 16)

\`\`\`button
name Generate Shopping List
type link
action kitchenos://generate-shopping-list?week=2026-W07
\`\`\`

## Monday (Feb 10)
### Breakfast
[[Quick Garlic Toast]]
### Lunch

### Dinner
[[Spaghetti Carbonara]]
### Notes


## Tuesday (Feb 11)
### Breakfast

### Lunch
Just a sandwich

### Dinner

### Notes


## Wednesday (Feb 12)
### Breakfast

### Lunch

### Dinner

### Notes


## Thursday (Feb 13)
### Breakfast

### Lunch

### Dinner

### Notes


## Friday (Feb 14)
### Breakfast

### Lunch

### Dinner

### Notes


## Saturday (Feb 15)
### Breakfast

### Lunch

### Dinner

### Notes


## Sunday (Feb 16)
### Breakfast

### Lunch

### Dinner

### Notes
`;

// ── Test Runner ──────────────────────────────────────────────────

interface TestResult {
  name: string;
  passed: boolean;
  error?: string;
}

const results: TestResult[] = [];

function test(name: string, fn: () => void): void {
  try {
    fn();
    results.push({ name, passed: true });
  } catch (err) {
    const error = err as Error;
    results.push({ name, passed: false, error: error.message });
  }
}

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(`Assertion failed: ${message}`);
}

function assertEqual<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

// ── Tests ────────────────────────────────────────────────────────

async function runTests(): Promise<void> {
  // Dynamically import the module under test
  // We need to patch db before importing, so we use a different approach:
  // The workflow functions accept a db parameter for testability.
  const { indexRecipesWithDb, indexMealPlansWithDb } = await import('./index-recipes');

  // ── indexRecipes tests ────────────────────────────────────────

  test('indexRecipes: scans and inserts frontmatter recipes', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      writeFileSync(join(vault, 'Recipes', 'Carbonara.md'), FRONTMATTER_RECIPE);

      const result = indexRecipesWithDb(vault, db);

      assertEqual(result.processed, 1, 'processed count');
      assertEqual(result.errors, 0, 'error count');

      const row = db.prepare('SELECT * FROM recipes WHERE title = ?').get('Spaghetti Carbonara') as Record<string, unknown>;
      assert(row !== undefined, 'recipe row should exist');
      assertEqual(row.cuisine, 'Italian', 'cuisine');
      assertEqual(row.difficulty, 'medium', 'difficulty');
      assertEqual(row.servings, 4, 'servings');
      assertEqual(row.prep_time_minutes, 10, 'prep_time_minutes');
      assertEqual(row.cook_time_minutes, 20, 'cook_time_minutes');
      assertEqual(row.protein, 'pork', 'protein');
      assertEqual(row.calories, 500, 'calories');
      assertEqual(row.nutrition_protein, 25, 'nutrition_protein');
      assertEqual(row.carbs, 55, 'carbs');
      assertEqual(row.fat, 18, 'fat');

      // Verify ingredients parsed
      const ingredients = JSON.parse(row.ingredients as string);
      assert(ingredients.length === 4, `expected 4 ingredients, got ${ingredients.length}`);
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  test('indexRecipes: scans and inserts cooking mode recipes', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      writeFileSync(join(vault, 'Recipes', 'Cooking Mode', 'Garlic Toast.recipe.md'), COOKING_MODE_RECIPE);

      const result = indexRecipesWithDb(vault, db);

      assertEqual(result.processed, 1, 'processed count');
      assertEqual(result.errors, 0, 'error count');

      const row = db.prepare('SELECT * FROM recipes WHERE title = ?').get('Quick Garlic Toast') as Record<string, unknown>;
      assert(row !== undefined, 'recipe row should exist');

      // Verify ingredients parsed
      const ingredients = JSON.parse(row.ingredients as string);
      assert(ingredients.length === 3, `expected 3 ingredients, got ${ingredients.length}`);

      // Verify source extracted
      assertEqual(row.source_url, 'https://example.com/toast', 'source_url');
      assertEqual(row.source_channel, 'SnackChef', 'source_channel');
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  test('indexRecipes: skips unchanged recipes (same content_hash)', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      writeFileSync(join(vault, 'Recipes', 'Carbonara.md'), FRONTMATTER_RECIPE);

      // First run: inserts
      const result1 = indexRecipesWithDb(vault, db);
      assertEqual(result1.processed, 1, 'first run processed');

      // Second run: should skip
      const result2 = indexRecipesWithDb(vault, db);
      assertEqual(result2.processed, 0, 'second run processed (should be 0)');
      assertEqual(result2.errors, 0, 'second run errors');
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  test('indexRecipes: updates changed recipes', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      writeFileSync(join(vault, 'Recipes', 'Carbonara.md'), FRONTMATTER_RECIPE);

      // First run: insert
      indexRecipesWithDb(vault, db);

      const rowBefore = db.prepare('SELECT id, content_hash FROM recipes WHERE title = ?').get('Spaghetti Carbonara') as Record<string, unknown>;

      // Modify the recipe
      const modifiedContent = FRONTMATTER_RECIPE.replace('servings: 4', 'servings: 6');
      writeFileSync(join(vault, 'Recipes', 'Carbonara.md'), modifiedContent);

      // Second run: should update
      const result = indexRecipesWithDb(vault, db);
      assertEqual(result.processed, 1, 'updated count');

      const rowAfter = db.prepare('SELECT id, content_hash, servings FROM recipes WHERE title = ?').get('Spaghetti Carbonara') as Record<string, unknown>;
      assertEqual(rowAfter.id, rowBefore.id, 'id should remain the same');
      assert(rowAfter.content_hash !== rowBefore.content_hash, 'content_hash should change');
      assertEqual(rowAfter.servings, 6, 'servings should be updated');
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  test('indexRecipes: handles both formats in same vault', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      writeFileSync(join(vault, 'Recipes', 'Carbonara.md'), FRONTMATTER_RECIPE);
      writeFileSync(join(vault, 'Recipes', 'Cooking Mode', 'Garlic Toast.recipe.md'), COOKING_MODE_RECIPE);

      const result = indexRecipesWithDb(vault, db);

      assertEqual(result.processed, 2, 'processed both');
      assertEqual(result.errors, 0, 'no errors');

      const count = (db.prepare('SELECT COUNT(*) as c FROM recipes').get() as { c: number }).c;
      assertEqual(count, 2, 'two recipes in db');
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  test('indexRecipes: stores relative file_path', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      writeFileSync(join(vault, 'Recipes', 'Carbonara.md'), FRONTMATTER_RECIPE);

      indexRecipesWithDb(vault, db);

      const row = db.prepare('SELECT file_path FROM recipes WHERE title = ?').get('Spaghetti Carbonara') as { file_path: string };
      assertEqual(row.file_path, 'Recipes/Carbonara.md', 'file_path should be relative to vault');
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  // ── indexMealPlans tests ──────────────────────────────────────

  test('indexMealPlans: inserts meal plan and items', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      // First index recipes so we can resolve links
      writeFileSync(join(vault, 'Recipes', 'Carbonara.md'), FRONTMATTER_RECIPE);
      writeFileSync(join(vault, 'Recipes', 'Cooking Mode', 'Garlic Toast.recipe.md'), COOKING_MODE_RECIPE);
      indexRecipesWithDb(vault, db);

      // Write meal plan
      writeFileSync(join(vault, 'Meal Plans', '2026-W07.md'), MEAL_PLAN_CONTENT);

      const result = indexMealPlansWithDb(vault, db);
      assertEqual(result.processed, 1, 'processed meal plan');
      assertEqual(result.errors, 0, 'no errors');

      // Verify meal_plan row
      const plan = db.prepare('SELECT * FROM meal_plans WHERE week = ?').get('2026-W07') as Record<string, unknown>;
      assert(plan !== undefined, 'meal plan should exist');
      assertEqual(plan.status, 'active', 'meal plan status');

      // Verify meal_plan_items
      const items = db.prepare('SELECT * FROM meal_plan_items WHERE meal_plan_id = ? ORDER BY day, meal').all(plan.id) as Array<Record<string, unknown>>;

      // We expect 2 items: Monday breakfast (Garlic Toast) and Monday dinner (Carbonara)
      assertEqual(items.length, 2, `expected 2 items, got ${items.length}`);

      // Monday breakfast: Quick Garlic Toast
      const mondayBreakfast = items.find(i => i.day === 'monday' && i.meal === 'breakfast') as Record<string, unknown>;
      assert(mondayBreakfast !== undefined, 'monday breakfast should exist');
      assertEqual(mondayBreakfast.recipe_title, 'Quick Garlic Toast', 'recipe title');
      assert(mondayBreakfast.recipe_id !== null, 'recipe_id should be resolved');

      // Monday dinner: Spaghetti Carbonara
      const mondayDinner = items.find(i => i.day === 'monday' && i.meal === 'dinner') as Record<string, unknown>;
      assert(mondayDinner !== undefined, 'monday dinner should exist');
      assertEqual(mondayDinner.recipe_title, 'Spaghetti Carbonara', 'recipe title');
      assert(mondayDinner.recipe_id !== null, 'recipe_id should be resolved');
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  test('indexMealPlans: skips existing meal plans', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      writeFileSync(join(vault, 'Meal Plans', '2026-W07.md'), MEAL_PLAN_CONTENT);

      // First run
      const result1 = indexMealPlansWithDb(vault, db);
      assertEqual(result1.processed, 1, 'first run processed');

      // Second run: should skip
      const result2 = indexMealPlansWithDb(vault, db);
      assertEqual(result2.processed, 0, 'second run should skip');
      assertEqual(result2.errors, 0, 'no errors');
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  test('indexMealPlans: extracts week from filename', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      writeFileSync(join(vault, 'Meal Plans', '2026-W07.md'), MEAL_PLAN_CONTENT);

      indexMealPlansWithDb(vault, db);

      const plan = db.prepare('SELECT week FROM meal_plans').get() as { week: string };
      assertEqual(plan.week, '2026-W07', 'week extracted from filename');
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  test('indexMealPlans: handles unresolved recipe links', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      // Don't index recipes first - links won't resolve
      writeFileSync(join(vault, 'Meal Plans', '2026-W07.md'), MEAL_PLAN_CONTENT);

      const result = indexMealPlansWithDb(vault, db);
      assertEqual(result.processed, 1, 'processed meal plan');

      // Items should still be created, just with null recipe_id
      const items = db.prepare('SELECT * FROM meal_plan_items').all() as Array<Record<string, unknown>>;
      assert(items.length > 0, 'items should exist even without recipe resolution');

      for (const item of items) {
        assertEqual(item.recipe_id, null, 'recipe_id should be null for unresolved links');
      }
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  test('indexRecipes: handles empty vault gracefully', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      const result = indexRecipesWithDb(vault, db);
      assertEqual(result.processed, 0, 'nothing to process');
      assertEqual(result.errors, 0, 'no errors');
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  test('indexMealPlans: handles empty vault gracefully', () => {
    const vault = createTempVault();
    const db = createTestDb();

    try {
      const result = indexMealPlansWithDb(vault, db);
      assertEqual(result.processed, 0, 'nothing to process');
      assertEqual(result.errors, 0, 'no errors');
    } finally {
      rmSync(vault, { recursive: true, force: true });
      db.close();
    }
  });

  // ── Report ─────────────────────────────────────────────────────

  console.log('\n--- index-recipes test results ---\n');

  let passed = 0;
  let failed = 0;

  for (const r of results) {
    if (r.passed) {
      console.log(`  PASS  ${r.name}`);
      passed++;
    } else {
      console.log(`  FAIL  ${r.name}`);
      console.log(`        ${r.error}`);
      failed++;
    }
  }

  console.log(`\n  ${passed} passed, ${failed} failed, ${results.length} total\n`);
  process.exit(failed > 0 ? 1 : 0);
}

runTests().catch((err) => {
  console.error('Test runner failed:', err);
  process.exit(1);
});
