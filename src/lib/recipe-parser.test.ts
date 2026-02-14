import assert from 'node:assert';
import { parseRecipeFrontmatter, parseRecipeCookingMode, parseTimeToMinutes } from './recipe-parser';

// ── Test Helpers ──────────────────────────────────────────────────

let passed = 0;
let failed = 0;

function test(name: string, fn: () => void): void {
  try {
    fn();
    passed++;
    console.log(`  \u2713 ${name}`);
  } catch (err: unknown) {
    failed++;
    const message = err instanceof Error ? err.message : String(err);
    console.log(`  \u2717 ${name}`);
    console.log(`    ${message}`);
  }
}

// ── Test Data ─────────────────────────────────────────────────────

const FRONTMATTER_RECIPE = `---
title: Pasta Carbonara
source_url: https://youtube.com/watch?v=xyz
source_channel: Binging with Babish
date_added: 2026-01-15
servings: 4
prep_time: 10 min
cook_time: 20 min
difficulty: medium
cuisine: Italian
protein: pork
dish_type: pasta
meal_occasion:
  - weeknight-dinner
  - date-night
dietary:
  - contains-gluten
  - contains-dairy
calories: 580
nutrition_protein: 25
carbs: 65
fat: 22
---

## Ingredients

| amount | unit | ingredient |
|--------|------|------------|
| 400 | g | spaghetti |
| 200 | g | guanciale |
| 4 | large | egg yolks |
| 100 | g | pecorino romano |

## Instructions

1. Cook pasta in salted water
2. Crisp guanciale in pan
3. Mix egg yolks with cheese
4. Combine and toss
`;

const COOKING_MODE_RECIPE = `# Butter Biscuits

> Flaky, buttery biscuits.

*breakfast, baking* **8 servings**

---

- *2 cups* all-purpose flour
- *1 tbsp* baking powder
- *1/2 tsp* salt
- *1/2 cup* cold butter

---

1. Mix dry ingredients
2. Cut in butter
3. Roll and cut
4. Bake at 425F for 12 minutes
`;

// ── 1. Parse YAML Frontmatter Recipe ──────────────────────────────

console.log('\nParse YAML frontmatter recipe:');

test('extracts title', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  assert.strictEqual(row.title, 'Pasta Carbonara');
});

test('extracts source_url and source_channel', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  assert.strictEqual(row.source_url, 'https://youtube.com/watch?v=xyz');
  assert.strictEqual(row.source_channel, 'Binging with Babish');
});

test('extracts servings as number', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  assert.strictEqual(row.servings, 4);
});

test('extracts prep_time and cook_time as minutes', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  assert.strictEqual(row.prep_time_minutes, 10);
  assert.strictEqual(row.cook_time_minutes, 20);
});

test('extracts difficulty, cuisine, protein, dish_type', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  assert.strictEqual(row.difficulty, 'medium');
  assert.strictEqual(row.cuisine, 'Italian');
  assert.strictEqual(row.protein, 'pork');
  assert.strictEqual(row.dish_type, 'pasta');
});

test('extracts meal_occasions as JSON array string', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  const occasions = JSON.parse(row.meal_occasions!) as string[];
  assert.deepStrictEqual(occasions, ['weeknight-dinner', 'date-night']);
});

test('extracts dietary as JSON array string', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  const dietary = JSON.parse(row.dietary!) as string[];
  assert.deepStrictEqual(dietary, ['contains-gluten', 'contains-dairy']);
});

test('extracts nutrition values', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  assert.strictEqual(row.calories, 580);
  assert.strictEqual(row.nutrition_protein, 25);
  assert.strictEqual(row.carbs, 65);
  assert.strictEqual(row.fat, 22);
});

test('extracts ingredient table as JSON array string', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  const ingredients = JSON.parse(row.ingredients) as Array<{ amount: string; unit: string; item: string }>;
  assert.strictEqual(ingredients.length, 4);
  assert.deepStrictEqual(ingredients[0], { amount: '400', unit: 'g', item: 'spaghetti' });
  assert.deepStrictEqual(ingredients[2], { amount: '4', unit: 'large', item: 'egg yolks' });
});

test('sets file_path correctly', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  assert.strictEqual(row.file_path, 'recipes/pasta-carbonara.md');
});

test('generates content_hash', () => {
  const row = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'recipes/pasta-carbonara.md');
  assert.ok(row.content_hash.length > 0, 'content_hash should not be empty');
  assert.ok(/^[a-f0-9]{64}$/.test(row.content_hash), 'content_hash should be a 64-char hex string');
});

// ── 2. Parse Time Strings ─────────────────────────────────────────

console.log('\nParse time strings:');

test('"5 min" -> 5', () => {
  assert.strictEqual(parseTimeToMinutes('5 min'), 5);
});

test('"5 minutes" -> 5', () => {
  assert.strictEqual(parseTimeToMinutes('5 minutes'), 5);
});

test('"1 hour" -> 60', () => {
  assert.strictEqual(parseTimeToMinutes('1 hour'), 60);
});

test('"2 hours" -> 120', () => {
  assert.strictEqual(parseTimeToMinutes('2 hours'), 120);
});

test('"1 hour 30 min" -> 90', () => {
  assert.strictEqual(parseTimeToMinutes('1 hour 30 min'), 90);
});

test('"2h 15m" -> 135', () => {
  assert.strictEqual(parseTimeToMinutes('2h 15m'), 135);
});

test('"1h" -> 60', () => {
  assert.strictEqual(parseTimeToMinutes('1h'), 60);
});

test('"45m" -> 45', () => {
  assert.strictEqual(parseTimeToMinutes('45m'), 45);
});

test('"garbage" -> null', () => {
  assert.strictEqual(parseTimeToMinutes('garbage'), null);
});

test('"" -> null', () => {
  assert.strictEqual(parseTimeToMinutes(''), null);
});

// ── 3. Parse Cooking Mode Format ──────────────────────────────────

console.log('\nParse Cooking Mode format:');

test('extracts title from H1', () => {
  const row = parseRecipeCookingMode(COOKING_MODE_RECIPE, 'recipes/butter-biscuits.md');
  assert.strictEqual(row.title, 'Butter Biscuits');
});

test('extracts ingredients from italic amount/unit pattern', () => {
  const row = parseRecipeCookingMode(COOKING_MODE_RECIPE, 'recipes/butter-biscuits.md');
  const ingredients = JSON.parse(row.ingredients) as Array<{ amount: string; unit: string; item: string }>;
  assert.strictEqual(ingredients.length, 4);
  assert.deepStrictEqual(ingredients[0], { amount: '2', unit: 'cups', item: 'all-purpose flour' });
  assert.deepStrictEqual(ingredients[2], { amount: '1/2', unit: 'tsp', item: 'salt' });
});

test('non-extractable metadata fields are null (no frontmatter)', () => {
  const row = parseRecipeCookingMode(COOKING_MODE_RECIPE, 'recipes/butter-biscuits.md');
  assert.strictEqual(row.source_url, null);
  assert.strictEqual(row.source_channel, null);
  assert.strictEqual(row.prep_time_minutes, null);
  assert.strictEqual(row.cook_time_minutes, null);
  assert.strictEqual(row.difficulty, null);
  assert.strictEqual(row.cuisine, null);
  assert.strictEqual(row.protein, null);
  assert.strictEqual(row.dish_type, null);
  assert.strictEqual(row.dietary, null);
  assert.strictEqual(row.calories, null);
  assert.strictEqual(row.nutrition_protein, null);
  assert.strictEqual(row.carbs, null);
  assert.strictEqual(row.fat, null);
});

test('sets file_path and content_hash', () => {
  const row = parseRecipeCookingMode(COOKING_MODE_RECIPE, 'recipes/butter-biscuits.md');
  assert.strictEqual(row.file_path, 'recipes/butter-biscuits.md');
  assert.ok(/^[a-f0-9]{64}$/.test(row.content_hash));
});

// ── 4. YAML null Literal Handling (C1 fix) ───────────────────────

console.log('\nYAML null literal handling:');

test('protein: null in YAML returns null (not "null")', () => {
  const recipe = `---
title: Test Recipe
protein: null
calories: null
---

## Ingredients

| amount | unit | ingredient |
|--------|------|------------|
| 1 | cup | rice |
`;
  const row = parseRecipeFrontmatter(recipe, 'test.md');
  assert.strictEqual(row.protein, null, 'protein should be null, not the string "null"');
  assert.strictEqual(row.calories, null, 'calories should be null, not NaN');
});

test('getString returns null for YAML null, getNumber returns null for YAML null', () => {
  const recipe = `---
title: Null Test
cuisine: null
servings: null
difficulty: null
fat: null
---
`;
  const row = parseRecipeFrontmatter(recipe, 'test.md');
  assert.strictEqual(row.cuisine, null);
  assert.strictEqual(row.servings, null);
  assert.strictEqual(row.difficulty, null);
  assert.strictEqual(row.fat, null);
});

// ── 5. Decimal Time Parsing (C2 fix) ─────────────────────────────

console.log('\nDecimal time parsing:');

test('"1.5 hours" -> 90', () => {
  assert.strictEqual(parseTimeToMinutes('1.5 hours'), 90);
});

test('"0.5 hours" -> 30', () => {
  assert.strictEqual(parseTimeToMinutes('0.5 hours'), 30);
});

test('"2.5h" -> 150', () => {
  assert.strictEqual(parseTimeToMinutes('2.5h'), 150);
});

test('"1.5 min" -> 2 (rounded)', () => {
  assert.strictEqual(parseTimeToMinutes('1.5 min'), 2);
});

// ── 6. Cooking Mode Metadata Extraction (I1 fix) ────────────────

console.log('\nCooking Mode metadata extraction:');

test('extracts servings from **N servings** pattern', () => {
  const row = parseRecipeCookingMode(COOKING_MODE_RECIPE, 'recipes/butter-biscuits.md');
  assert.strictEqual(row.servings, 8);
});

test('extracts tags from italic line as meal_occasions', () => {
  const row = parseRecipeCookingMode(COOKING_MODE_RECIPE, 'recipes/butter-biscuits.md');
  assert.notStrictEqual(row.meal_occasions, null, 'meal_occasions should not be null');
  const tags = JSON.parse(row.meal_occasions!) as string[];
  assert.deepStrictEqual(tags, ['breakfast', 'baking']);
});

test('extracts source URL and channel from Source line', () => {
  const recipeWithSource = `# Kung Pao Chicken

> A spicy Sichuan classic.

*Source: [Kung Pao Chicken](https://youtube.com/watch?v=abc) by Kenji Lopez-Alt*

*chinese, main course* **4 servings**

---

- *2 lbs* chicken thighs
- *1 tbsp* soy sauce

---

1. Cut chicken
2. Stir fry
`;
  const row = parseRecipeCookingMode(recipeWithSource, 'recipes/kung-pao.md');
  assert.strictEqual(row.source_url, 'https://youtube.com/watch?v=abc');
  assert.strictEqual(row.source_channel, 'Kenji Lopez-Alt');
  assert.strictEqual(row.servings, 4);
  const tags = JSON.parse(row.meal_occasions!) as string[];
  assert.deepStrictEqual(tags, ['chinese', 'main course']);
});

test('cooking mode without extractable metadata returns nulls', () => {
  const minimal = `# Simple Soup

---

- *1 cup* water
- *1 tsp* salt

---

1. Boil water
2. Add salt
`;
  const row = parseRecipeCookingMode(minimal, 'recipes/soup.md');
  assert.strictEqual(row.servings, null);
  assert.strictEqual(row.source_url, null);
  assert.strictEqual(row.source_channel, null);
  assert.strictEqual(row.meal_occasions, null);
});

// ── 7. Content Hash Determinism ───────────────────────────────────

console.log('\nContent hash determinism:');

test('same content produces same hash', () => {
  const row1 = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'path1.md');
  const row2 = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'path2.md');
  assert.strictEqual(row1.content_hash, row2.content_hash);
});

test('different content produces different hash', () => {
  const row1 = parseRecipeFrontmatter(FRONTMATTER_RECIPE, 'a.md');
  const row2 = parseRecipeCookingMode(COOKING_MODE_RECIPE, 'b.md');
  assert.notStrictEqual(row1.content_hash, row2.content_hash);
});

// ── Summary ───────────────────────────────────────────────────────

console.log(`\n${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
