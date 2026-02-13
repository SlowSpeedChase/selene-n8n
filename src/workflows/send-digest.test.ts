import assert from 'assert';

async function runTests() {
  console.log('Testing TRMNL digest push...\n');

  // Test 1: buildTrmnlPayload formats digest text into merge_variables
  console.log('Test 1: buildTrmnlPayload splits digest into bullets');
  {
    const { buildTrmnlPayload } = await import('./send-digest');
    const digest = 'Focus on thread detection refinements\nReview voice input feedback\nCheck task extraction accuracy';
    const result = buildTrmnlPayload(digest);

    assert.strictEqual(result.merge_variables.title, 'Selene Daily');
    assert.ok(result.merge_variables.date.length > 0, 'date should be non-empty');
    assert.deepStrictEqual(result.merge_variables.bullets, [
      'Focus on thread detection refinements',
      'Review voice input feedback',
      'Check task extraction accuracy',
    ]);
    console.log('  ✓ PASS');
  }

  // Test 2: buildTrmnlPayload filters empty lines
  console.log('Test 2: buildTrmnlPayload filters empty lines');
  {
    const { buildTrmnlPayload } = await import('./send-digest');
    const digest = 'Line one\n\n\nLine two\n';
    const result = buildTrmnlPayload(digest);

    assert.deepStrictEqual(result.merge_variables.bullets, [
      'Line one',
      'Line two',
    ]);
    console.log('  ✓ PASS');
  }

  // Test 3: buildTrmnlPayload handles single-line digest
  console.log('Test 3: buildTrmnlPayload handles single-line digest');
  {
    const { buildTrmnlPayload } = await import('./send-digest');
    const digest = 'Just one bullet today';
    const result = buildTrmnlPayload(digest);

    assert.deepStrictEqual(result.merge_variables.bullets, [
      'Just one bullet today',
    ]);
    console.log('  ✓ PASS');
  }

  console.log('\nAll tests passed!');
}

runTests().catch((err) => {
  console.error('Test failed:', err);
  process.exit(1);
});
