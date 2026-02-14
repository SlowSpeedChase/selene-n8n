import assert from 'assert';
import { generateMealPlanMarkdown, generateShoppingListMarkdown } from './meal-plan-exporter';

async function runTests() {
  console.log('Meal Plan Exporter Tests\n');

  // Test 1: Generates KitchenOS-format meal plan
  console.log('Test 1: Generates KitchenOS-format meal plan markdown');
  {
    const items = [
      { day: 'monday', meal: 'breakfast', recipe_title: 'Overnight Oats' },
      { day: 'monday', meal: 'lunch', recipe_title: 'Chicken Stir Fry' },
      { day: 'monday', meal: 'dinner', recipe_title: 'Pasta Carbonara' },
      { day: 'tuesday', meal: 'dinner', recipe_title: 'Sheet Pan Salmon' },
    ];

    const md = generateMealPlanMarkdown('2026-W08', items);

    assert.ok(md.includes('# Meal Plan - Week 08'), 'Should have week header');
    assert.ok(md.includes('## Monday'), 'Should have Monday header');
    assert.ok(md.includes('### Breakfast'), 'Should have meal headers');
    assert.ok(md.includes('[[Overnight Oats]]'), 'Should use wiki links');
    assert.ok(md.includes('[[Pasta Carbonara]]'), 'Should use wiki links');
    assert.ok(md.includes('## Tuesday'), 'Should have Tuesday');
    assert.ok(md.includes('[[Sheet Pan Salmon]]'), 'Should have Tuesday dinner');
    console.log('  PASS');
  }

  // Test 2: Generates shopping list markdown
  console.log('Test 2: Generates shopping list markdown');
  {
    const items = [
      { ingredient: 'spaghetti', amount: 400, unit: 'g', category: 'pantry' },
      { ingredient: 'chicken breast', amount: 500, unit: 'g', category: 'meat' },
      { ingredient: 'broccoli', amount: 1, unit: 'head', category: 'produce' },
    ];

    const md = generateShoppingListMarkdown('2026-W08', items);

    assert.ok(md.includes('# Shopping List'), 'Should have header');
    assert.ok(md.includes('## Produce'), 'Should group by category');
    assert.ok(md.includes('- [ ] 1 head broccoli'), 'Should have checkbox format');
    assert.ok(md.includes('## Meat'), 'Should have meat category');
    assert.ok(md.includes('## Pantry'), 'Should have pantry category');
    console.log('  PASS');
  }

  // Test 3: Handles items without category
  console.log('Test 3: Items without category go to "other"');
  {
    const items = [
      { ingredient: 'mystery item', amount: 1, unit: 'bag', category: null },
    ];

    const md = generateShoppingListMarkdown('2026-W08', items);
    assert.ok(md.includes('## Other'), 'Should have Other category');
    assert.ok(md.includes('mystery item'), 'Should include the item');
    console.log('  PASS');
  }

  // Test 4: Day ordering is correct
  console.log('Test 4: Days are ordered Monday-Sunday');
  {
    const items = [
      { day: 'friday', meal: 'dinner', recipe_title: 'Pizza' },
      { day: 'monday', meal: 'dinner', recipe_title: 'Pasta' },
      { day: 'wednesday', meal: 'dinner', recipe_title: 'Tacos' },
    ];

    const md = generateMealPlanMarkdown('2026-W08', items);
    const mondayIdx = md.indexOf('## Monday');
    const wednesdayIdx = md.indexOf('## Wednesday');
    const fridayIdx = md.indexOf('## Friday');

    assert.ok(mondayIdx < wednesdayIdx, 'Monday before Wednesday');
    assert.ok(wednesdayIdx < fridayIdx, 'Wednesday before Friday');
    console.log('  PASS');
  }

  console.log('\nAll meal plan exporter tests passed!');
}

runTests().catch(err => {
  console.error('\nTest failed:', err.message);
  process.exit(1);
});
