import assert from 'node:assert';
import { ContextBuilder, NoteContext, ThreadContext } from './context-builder';

function makeNote(overrides: Partial<NoteContext> = {}): NoteContext {
  return {
    id: 1,
    title: 'Test Note',
    content: 'This is the full content of the note.',
    essence: 'Core insight of the note.',
    primary_theme: 'testing',
    concepts: JSON.stringify(['concept-a', 'concept-b', 'concept-c']),
    fidelity_tier: 'full',
    ...overrides,
  };
}

function makeThread(overrides: Partial<ThreadContext> = {}): ThreadContext {
  return {
    id: 1,
    name: 'ADHD Strategies',
    thread_digest: 'A digest summarizing the thread.',
    summary: 'Thread summary text.',
    why: 'To improve focus.',
    note_count: 5,
    ...overrides,
  };
}

let passed = 0;

// Test 1: Empty builder returns empty string
{
  const cb = new ContextBuilder(1000);
  assert.strictEqual(cb.build(), '', 'Empty builder should return empty string');
  passed++;
  console.log('PASS 1: Empty builder returns empty string');
}

// Test 2: Full tier renders title + content
{
  const cb = new ContextBuilder(1000);
  const note = makeNote({ fidelity_tier: 'full' });
  cb.addNote(note);
  const result = cb.build();
  assert.ok(result.includes('--- Test Note ---'), 'Should include title');
  assert.ok(result.includes('This is the full content of the note.'), 'Should include content');
  assert.ok(!result.includes('[Essence]'), 'Full tier should not include [Essence] label');
  passed++;
  console.log('PASS 2: Full tier renders title + content');
}

// Test 3: High tier renders title + essence + content
{
  const cb = new ContextBuilder(1000);
  const note = makeNote({ fidelity_tier: 'high' });
  cb.addNote(note);
  const result = cb.build();
  assert.ok(result.includes('--- Test Note ---'), 'Should include title');
  assert.ok(result.includes('[Essence] Core insight of the note.'), 'Should include essence');
  assert.ok(result.includes('This is the full content of the note.'), 'Should include content');
  passed++;
  console.log('PASS 3: High tier renders title + essence + content');
}

// Test 4: Summary tier renders title + essence + themes (no content)
{
  const cb = new ContextBuilder(1000);
  const note = makeNote({ fidelity_tier: 'summary' });
  cb.addNote(note);
  const result = cb.build();
  assert.ok(result.includes('--- Test Note [testing] ---'), 'Should include title with theme');
  assert.ok(result.includes('Core insight of the note.'), 'Should include essence');
  assert.ok(!result.includes('This is the full content of the note.'), 'Summary should NOT include full content');
  passed++;
  console.log('PASS 4: Summary tier renders title + essence + themes (no content)');
}

// Test 5: Skeleton tier renders title + theme only
{
  const cb = new ContextBuilder(1000);
  const note = makeNote({ fidelity_tier: 'skeleton' });
  cb.addNote(note);
  const result = cb.build();
  assert.strictEqual(result, '- Test Note [testing]', 'Skeleton should be compact title + theme');
  passed++;
  console.log('PASS 5: Skeleton tier renders title + theme only');
}

// Test 6: Token budget enforcement - stops adding notes when full
{
  // Note 1 renders as "--- Note 1 ---\nContent of note one." = 36 chars
  // Budget of 10 tokens = 40 chars. Only first note fits.
  const cb = new ContextBuilder(10);
  const note1 = makeNote({ id: 1, title: 'Note 1', content: 'Content of note one.', fidelity_tier: 'full' });
  const note2 = makeNote({ id: 2, title: 'Note 2', content: 'Content of note two.', fidelity_tier: 'full' });

  cb.addNote(note1);
  cb.addNote(note2);

  const result = cb.build();
  // First note (36 chars) fits within 40 char budget; second (36 chars) would push to 72, dropped
  assert.ok(result.includes('Note 1'), 'First note should be included');
  assert.ok(!result.includes('Note 2'), 'Second note should be dropped (budget exceeded)');
  assert.ok(cb.remainingTokens() >= 0, 'Remaining tokens should be non-negative');
  assert.ok(cb.remainingTokens() <= 10, 'Remaining tokens should be small');
  passed++;
  console.log('PASS 6: Token budget enforcement');
}

// Test 7: Fallback chain - missing essence falls back to concepts then truncated content
{
  // 7a: Missing essence, has concepts -> summary shows concepts
  const cb1 = new ContextBuilder(1000);
  const noteWithConcepts = makeNote({
    fidelity_tier: 'summary',
    essence: null,
    concepts: JSON.stringify(['focus', 'attention', 'routine']),
  });
  cb1.addNote(noteWithConcepts);
  const result1 = cb1.build();
  assert.ok(result1.includes('Concepts: focus, attention, routine'), 'Should fall back to concepts');

  // 7b: Missing essence AND concepts -> truncated content
  const cb2 = new ContextBuilder(1000);
  const longContent = 'A'.repeat(200);
  const noteNoEssenceNoConcepts = makeNote({
    fidelity_tier: 'summary',
    essence: null,
    concepts: null,
    content: longContent,
  });
  cb2.addNote(noteNoEssenceNoConcepts);
  const result2 = cb2.build();
  assert.ok(result2.includes('A'.repeat(150) + '...'), 'Should fall back to truncated content');
  assert.ok(!result2.includes('A'.repeat(200)), 'Should NOT include full 200-char content');

  passed++;
  console.log('PASS 7: Fallback chain (essence -> concepts -> truncated content)');
}

// Test 8: Thread digest rendering
{
  const cb = new ContextBuilder(1000);
  const thread = makeThread();
  cb.addThread(thread);
  const result = cb.build();
  assert.ok(result.includes('=== Thread: ADHD Strategies (5 notes) ==='), 'Should include thread header');
  assert.ok(result.includes('A digest summarizing the thread.'), 'Should include digest');
  // When digest is present, summary should NOT appear (digest takes priority)
  assert.ok(!result.includes('Thread summary text.'), 'Should NOT include summary when digest exists');
  passed++;
  console.log('PASS 8: Thread digest rendering');
}

// Test 9: Thread without digest falls back to summary
{
  const cb = new ContextBuilder(1000);
  const thread = makeThread({ thread_digest: null });
  cb.addThread(thread);
  const result = cb.build();
  assert.ok(result.includes('=== Thread: ADHD Strategies (5 notes) ==='), 'Should include thread header');
  assert.ok(result.includes('Thread summary text.'), 'Should fall back to summary');
  assert.ok(result.includes('Motivation: To improve focus.'), 'Should include why');
  passed++;
  console.log('PASS 9: Thread without digest falls back to summary');
}

// Test 10: addFullText always uses full content regardless of tier
{
  const cb = new ContextBuilder(1000);
  const note = makeNote({ fidelity_tier: 'skeleton' }); // tier is skeleton but addFullText should override
  cb.addFullText(note);
  const result = cb.build();
  assert.ok(result.includes('--- Test Note ---'), 'Should include title');
  assert.ok(result.includes('This is the full content of the note.'), 'Should include full content even though tier is skeleton');
  assert.ok(!result.startsWith('- Test Note'), 'Should NOT use skeleton format');
  passed++;
  console.log('PASS 10: addFullText always uses full content regardless of tier');
}

console.log(`\nAll ${passed}/10 tests passed.`);
