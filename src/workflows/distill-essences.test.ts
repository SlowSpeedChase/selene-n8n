import assert from 'assert';

async function runTests() {
  const { getNotesNeedingEssence } = await import('./distill-essences');

  // Test 1: Function exists and is callable
  {
    assert.strictEqual(typeof getNotesNeedingEssence, 'function');
    console.log('  ✓ getNotesNeedingEssence is exported');
  }

  console.log('\nAll distill-essences tests passed!');
}

runTests().catch((err) => {
  console.error('Tests failed:', err);
  process.exit(1);
});
