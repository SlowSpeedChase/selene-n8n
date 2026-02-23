import assert from 'assert';

async function runTests() {
  const { computeTier } = await import('./evaluate-fidelity');

  // Test 1: Fresh note (< 7 days) → full
  {
    const tier = computeTier({ ageDays: 3, hasEssence: false, threadStatus: 'active', lastAccessDays: 1 });
    assert.strictEqual(tier, 'full');
    console.log('  ✓ fresh note → full');
  }

  // Test 2: Warm note (30 days, active thread) → high
  {
    const tier = computeTier({ ageDays: 30, hasEssence: true, threadStatus: 'active', lastAccessDays: 5 });
    assert.strictEqual(tier, 'high');
    console.log('  ✓ warm active thread note → high');
  }

  // Test 3: Warm note without essence stays full
  {
    const tier = computeTier({ ageDays: 30, hasEssence: false, threadStatus: 'active', lastAccessDays: 5 });
    assert.strictEqual(tier, 'full');
    console.log('  ✓ warm note without essence stays full');
  }

  // Test 4: Cool note (120 days, archived, has essence) → summary
  {
    const tier = computeTier({ ageDays: 120, hasEssence: true, threadStatus: 'archived', lastAccessDays: 100 });
    assert.strictEqual(tier, 'summary');
    console.log('  ✓ cool inactive note → summary');
  }

  // Test 5: Cold note (200 days, archived, no access) → skeleton
  {
    const tier = computeTier({ ageDays: 200, hasEssence: true, threadStatus: 'archived', lastAccessDays: 200 });
    assert.strictEqual(tier, 'skeleton');
    console.log('  ✓ cold archived note → skeleton');
  }

  // Test 6: Old note in active thread → high (rehydration)
  {
    const tier = computeTier({ ageDays: 200, hasEssence: true, threadStatus: 'active', lastAccessDays: 2 });
    assert.strictEqual(tier, 'high');
    console.log('  ✓ old note in active thread → high (rehydration)');
  }

  // Test 7: Cannot demote without essence
  {
    const tier = computeTier({ ageDays: 200, hasEssence: false, threadStatus: 'archived', lastAccessDays: 200 });
    assert.strictEqual(tier, 'full');
    console.log('  ✓ cannot demote without essence');
  }

  console.log('\nAll evaluate-fidelity tests passed!');
}

runTests().catch((err) => {
  console.error('Tests failed:', err);
  process.exit(1);
});
