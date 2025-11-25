#!/usr/bin/env node

/**
 * Test Suite for Task Extraction (Workflow 07)
 * Following TDD: These tests are written BEFORE implementation
 * They MUST fail initially, then pass after implementation
 */

const https = require('https');
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

// Configuration
const DB_PATH = '/Users/chaseeasterling/selene-n8n/data/selene.db';
const TEST_RUN_ID = `test-run-${Date.now()}`;

// ANSI colors for output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

let testResults = {
  passed: 0,
  failed: 0,
  errors: []
};

// Helper to execute SQL via sqlite3 CLI
async function execSQL(query) {
  try {
    const { stdout } = await execAsync(`sqlite3 "${DB_PATH}" "${query}"`);
    return stdout.trim();
  } catch (error) {
    throw new Error(`SQL execution failed: ${error.message}`);
  }
}

/**
 * Test utilities
 */
function assert(condition, message) {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

function assertEquals(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`${message}\n  Expected: ${expected}\n  Actual: ${actual}`);
  }
}

function assertNotNull(value, message) {
  if (value === null || value === undefined) {
    throw new Error(`${message} - Value is null or undefined`);
  }
}

function assertArrayLength(array, expectedLength, message) {
  if (!Array.isArray(array) || array.length !== expectedLength) {
    throw new Error(`${message}\n  Expected length: ${expectedLength}\n  Actual: ${array ? array.length : 'not an array'}`);
  }
}

async function runTest(name, testFn) {
  process.stdout.write(`${colors.cyan}Testing:${colors.reset} ${name}... `);

  try {
    await testFn();
    testResults.passed++;
    console.log(`${colors.green}✓ PASS${colors.reset}`);
    return true;
  } catch (error) {
    testResults.failed++;
    testResults.errors.push({ test: name, error: error.message });
    console.log(`${colors.red}✗ FAIL${colors.reset}`);
    console.log(`  ${colors.red}Error: ${error.message}${colors.reset}`);
    return false;
  }
}

/**
 * DATABASE MIGRATION TESTS
 * These test that the task_metadata table is created correctly
 */

async function test_database_table_exists() {
  const result = await execSQL(`
    SELECT name FROM sqlite_master
    WHERE type='table' AND name='task_metadata';
  `);

  assertNotNull(result, 'task_metadata table should exist');
  assertEquals(result, 'task_metadata', 'Table name should be task_metadata');
}

async function test_database_table_has_correct_columns() {
  const columns = db.prepare(`PRAGMA table_info(task_metadata)`).all();

  const expectedColumns = [
    'id',
    'raw_note_id',
    'things_task_id',
    'things_project_id',
    'energy_required',
    'estimated_minutes',
    'related_concepts',
    'related_themes',
    'overwhelm_factor',
    'task_type',
    'context_tags',
    'created_at',
    'synced_at',
    'completed_at'
  ];

  const actualColumns = columns.map(col => col.name);

  for (const expectedCol of expectedColumns) {
    assert(
      actualColumns.includes(expectedCol),
      `Column '${expectedCol}' should exist in task_metadata table`
    );
  }
}

async function test_database_indexes_exist() {
  const indexes = db.prepare(`
    SELECT name FROM sqlite_master
    WHERE type='index' AND tbl_name='task_metadata'
  `).all();

  const indexNames = indexes.map(idx => idx.name);

  assert(
    indexNames.some(name => name.includes('note')),
    'Index on raw_note_id should exist'
  );

  assert(
    indexNames.some(name => name.includes('things_id')),
    'Index on things_task_id should exist'
  );
}

async function test_database_can_insert_task_record() {
  // Insert a test task record
  const insert = db.prepare(`
    INSERT INTO task_metadata (
      raw_note_id,
      things_task_id,
      energy_required,
      estimated_minutes,
      task_type,
      overwhelm_factor,
      related_concepts,
      context_tags
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);

  const testNoteId = createTestNote();

  const result = insert.run(
    testNoteId,
    `things-test-${TEST_RUN_ID}`,
    'medium',
    30,
    'action',
    5,
    '["productivity", "testing"]',
    '["work", "technical"]'
  );

  assert(result.changes === 1, 'Should insert 1 record');
  assertNotNull(result.lastInsertRowid, 'Should return inserted row ID');

  // Clean up
  db.prepare('DELETE FROM task_metadata WHERE things_task_id LIKE ?').run(`things-test-${TEST_RUN_ID}`);
  db.prepare('DELETE FROM raw_notes WHERE id = ?').run(testNoteId);
}

async function test_database_enforces_energy_constraint() {
  const testNoteId = createTestNote();

  try {
    db.prepare(`
      INSERT INTO task_metadata (
        raw_note_id,
        things_task_id,
        energy_required
      ) VALUES (?, ?, ?)
    `).run(testNoteId, `things-test-invalid-${TEST_RUN_ID}`, 'invalid_energy');

    // Should not reach here
    throw new Error('Should have thrown constraint violation');
  } catch (error) {
    assert(
      error.message.includes('constraint') || error.message.includes('CHECK'),
      'Should enforce energy_required constraint'
    );
  } finally {
    // Clean up
    db.prepare('DELETE FROM raw_notes WHERE id = ?').run(testNoteId);
  }
}

async function test_database_foreign_key_to_raw_notes() {
  try {
    // Try to insert task with non-existent note ID
    db.prepare(`
      INSERT INTO task_metadata (
        raw_note_id,
        things_task_id
      ) VALUES (?, ?)
    `).run(999999, `things-test-fk-${TEST_RUN_ID}`);

    // Should not reach here
    throw new Error('Should have thrown foreign key violation');
  } catch (error) {
    assert(
      error.message.includes('FOREIGN KEY') || error.message.includes('constraint'),
      'Should enforce foreign key constraint to raw_notes'
    );
  }
}

/**
 * TASK EXTRACTION TESTS
 * These test the Ollama LLM task extraction
 */

async function test_ollama_extracts_tasks_from_note() {
  const testNote = {
    content: `Meeting notes: Need to email John about the project timeline.
               Also, schedule team sync for next week. Research competitor pricing models.`,
    energy_level: 'medium',
    concepts: JSON.stringify(['project', 'team', 'research']),
    themes: JSON.stringify(['work', 'planning']),
    emotional_tone: 'determined'
  };

  const tasks = await extractTasksViaOllama(testNote);

  assert(Array.isArray(tasks), 'Should return an array of tasks');
  assert(tasks.length >= 2, 'Should extract at least 2 tasks from the test note');

  // Verify task structure
  const task = tasks[0];
  assertNotNull(task.task_text, 'Task should have task_text');
  assertNotNull(task.energy_required, 'Task should have energy_required');
  assertNotNull(task.estimated_minutes, 'Task should have estimated_minutes');
  assertNotNull(task.task_type, 'Task should have task_type');
  assert(Array.isArray(task.context_tags), 'Task should have context_tags array');
  assertNotNull(task.overwhelm_factor, 'Task should have overwhelm_factor');
}

async function test_ollama_returns_empty_for_non_actionable_note() {
  const testNote = {
    content: 'Just thinking about how nice the weather is today. Feeling grateful.',
    energy_level: 'high',
    concepts: JSON.stringify(['gratitude', 'weather']),
    themes: JSON.stringify(['personal', 'reflection']),
    emotional_tone: 'calm'
  };

  const tasks = await extractTasksViaOllama(testNote);

  assert(Array.isArray(tasks), 'Should return an array');
  assertEquals(tasks.length, 0, 'Should return empty array for non-actionable note');
}

async function test_ollama_assigns_correct_energy_levels() {
  const testNote = {
    content: 'File the tax documents. Write strategic vision for Q2. Reply to Sarah\'s email.',
    energy_level: 'medium',
    concepts: JSON.stringify(['admin', 'strategy', 'communication']),
    themes: JSON.stringify(['work']),
    emotional_tone: 'focused'
  };

  const tasks = await extractTasksViaOllama(testNote);

  assert(tasks.length >= 3, 'Should extract 3 tasks');

  // Find the strategic task (should be high energy)
  const strategyTask = tasks.find(t =>
    t.task_text.toLowerCase().includes('strategic') ||
    t.task_text.toLowerCase().includes('vision')
  );

  if (strategyTask) {
    assertEquals(
      strategyTask.energy_required,
      'high',
      'Strategic/creative tasks should require high energy'
    );
  }

  // Find the filing task (should be low energy)
  const filingTask = tasks.find(t =>
    t.task_text.toLowerCase().includes('file') ||
    t.task_text.toLowerCase().includes('tax')
  );

  if (filingTask) {
    assertEquals(
      filingTask.energy_required,
      'low',
      'Filing/organizing tasks should require low energy'
    );
  }
}

/**
 * THINGS INTEGRATION TESTS
 * These test the Things URL scheme construction
 */

async function test_things_url_is_valid() {
  const task = {
    task_text: 'Test task for validation',
    notes: 'From note: Test note content'
  };

  const url = constructThingsURL(task);

  assert(url.startsWith('things:///add?'), 'URL should start with things:///add?');
  assert(url.includes('title='), 'URL should include title parameter');
  assert(url.includes('Test%20task'), 'URL should encode spaces in title');
}

async function test_things_url_includes_notes_parameter() {
  const task = {
    task_text: 'Test task',
    notes: 'Additional context here'
  };

  const url = constructThingsURL(task);

  assert(url.includes('notes='), 'URL should include notes parameter');
  assert(url.includes('Additional'), 'URL should include notes content');
}

async function test_things_url_handles_special_characters() {
  const task = {
    task_text: 'Task with & special = characters?',
    notes: 'Notes with #hashtag and @mention'
  };

  const url = constructThingsURL(task);

  // Should properly encode special characters
  assert(!url.includes('&title='), 'Should not have unencoded ampersand before parameter');
  assert(!url.includes('?notes='), 'Should not have unencoded question mark');
}

/**
 * INTEGRATION TESTS
 * These test the end-to-end workflow
 */

async function test_end_to_end_task_creation() {
  // Create a test note in database
  const noteId = createTestNote();

  // Extract tasks
  const tasks = await extractTasksViaOllama({
    content: 'Need to call dentist and schedule appointment. Also, update project documentation.',
    energy_level: 'medium',
    concepts: JSON.stringify(['health', 'documentation']),
    themes: JSON.stringify(['personal', 'work']),
    emotional_tone: 'focused'
  });

  assert(tasks.length >= 2, 'Should extract at least 2 tasks');

  // For each task, verify we can:
  // 1. Construct Things URL
  // 2. Store metadata in database

  for (const task of tasks) {
    // Construct URL
    const url = constructThingsURL(task);
    assert(url.startsWith('things:///add?'), 'Should create valid Things URL');

    // Store in database (simulate Things creation with test UUID)
    const taskId = `things-e2e-${Date.now()}-${Math.random()}`;
    const insert = db.prepare(`
      INSERT INTO task_metadata (
        raw_note_id,
        things_task_id,
        energy_required,
        estimated_minutes,
        task_type,
        overwhelm_factor
      ) VALUES (?, ?, ?, ?, ?, ?)
    `);

    insert.run(
      noteId,
      taskId,
      task.energy_required,
      task.estimated_minutes,
      task.task_type,
      task.overwhelm_factor
    );
  }

  // Verify tasks were stored
  const storedTasks = db.prepare(`
    SELECT COUNT(*) as count FROM task_metadata
    WHERE raw_note_id = ? AND things_task_id LIKE 'things-e2e-%'
  `).get(noteId);

  assert(storedTasks.count >= 2, 'Should store all extracted tasks');

  // Clean up
  db.prepare('DELETE FROM task_metadata WHERE raw_note_id = ?').run(noteId);
  db.prepare('DELETE FROM raw_notes WHERE id = ?').run(noteId);
}

/**
 * Helper Functions
 */

function createTestNote() {
  const insert = db.prepare(`
    INSERT INTO raw_notes (
      title,
      content,
      content_hash,
      source_type,
      created_at,
      test_run
    ) VALUES (?, ?, ?, ?, ?, ?)
  `);

  const result = insert.run(
    'Test Note for Task Extraction',
    'This is a test note for the task extraction workflow.',
    `test-hash-${Date.now()}`,
    'test',
    new Date().toISOString(),
    TEST_RUN_ID
  );

  return result.lastInsertRowid;
}

async function extractTasksViaOllama(note) {
  // This function will call Ollama API to extract tasks
  // For now, it's a placeholder that will be implemented

  const prompt = `You are a task extraction assistant for an ADHD-optimized productivity system.

Analyze the following note and extract actionable tasks.

NOTE CONTENT: ${note.content}
ENERGY LEVEL: ${note.energy_level}
CONCEPTS: ${note.concepts}
THEMES: ${note.themes}
EMOTIONAL TONE: ${note.emotional_tone}

Extract ONLY actionable tasks. Return JSON array with this structure:
[
  {
    "task_text": "Clear, actionable description starting with verb",
    "energy_required": "high|medium|low",
    "estimated_minutes": 5|15|30|60|120|240,
    "task_type": "action|decision|research|communication|learning|planning",
    "context_tags": ["work", "personal", "etc"],
    "overwhelm_factor": 1-10
  }
]

If no actionable tasks, return empty array: []`;

  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      model: 'mistral:7b',
      prompt: prompt,
      stream: false,
      format: 'json'
    });

    const options = {
      hostname: 'localhost',
      port: 11434,
      path: '/api/generate',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = https.request(options, (res) => {
      let responseData = '';

      res.on('data', (chunk) => {
        responseData += chunk;
      });

      res.on('end', () => {
        try {
          const response = JSON.parse(responseData);
          const tasks = JSON.parse(response.response);
          resolve(tasks);
        } catch (error) {
          reject(new Error(`Failed to parse Ollama response: ${error.message}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(new Error(`Ollama request failed: ${error.message}`));
    });

    req.write(data);
    req.end();
  });
}

function constructThingsURL(task) {
  // Construct Things URL scheme
  // Format: things:///add?title=TITLE&notes=NOTES

  const params = new URLSearchParams();
  params.append('title', task.task_text);

  if (task.notes) {
    params.append('notes', task.notes);
  }

  return `things:///add?${params.toString()}`;
}

/**
 * Test Runner
 */

async function runAllTests() {
  console.log(`${colors.blue}═══════════════════════════════════════════════════════${colors.reset}`);
  console.log(`${colors.blue}  Task Extraction Test Suite (TDD - RED Phase Expected)${colors.reset}`);
  console.log(`${colors.blue}═══════════════════════════════════════════════════════${colors.reset}`);
  console.log(`${colors.yellow}Test Run ID: ${TEST_RUN_ID}${colors.reset}\n`);

  // Open database
  try {
    db = new Database(DB_PATH);
    console.log(`${colors.green}✓ Database connected${colors.reset}\n`);
  } catch (error) {
    console.error(`${colors.red}✗ Failed to connect to database: ${error.message}${colors.reset}`);
    process.exit(1);
  }

  // Database Migration Tests
  console.log(`${colors.blue}━━━ DATABASE MIGRATION TESTS ━━━${colors.reset}`);
  await runTest('Table exists', test_database_table_exists);
  await runTest('Table has correct columns', test_database_table_has_correct_columns);
  await runTest('Indexes exist', test_database_indexes_exist);
  await runTest('Can insert task record', test_database_can_insert_task_record);
  await runTest('Enforces energy constraint', test_database_enforces_energy_constraint);
  await runTest('Foreign key to raw_notes', test_database_foreign_key_to_raw_notes);

  console.log();

  // Task Extraction Tests
  console.log(`${colors.blue}━━━ TASK EXTRACTION TESTS ━━━${colors.reset}`);
  await runTest('Ollama extracts tasks from note', test_ollama_extracts_tasks_from_note);
  await runTest('Ollama returns empty for non-actionable', test_ollama_returns_empty_for_non_actionable_note);
  await runTest('Ollama assigns correct energy levels', test_ollama_assigns_correct_energy_levels);

  console.log();

  // Things Integration Tests
  console.log(`${colors.blue}━━━ THINGS URL SCHEME TESTS ━━━${colors.reset}`);
  await runTest('Things URL is valid', test_things_url_is_valid);
  await runTest('Things URL includes notes', test_things_url_includes_notes_parameter);
  await runTest('Things URL handles special chars', test_things_url_handles_special_characters);

  console.log();

  // Integration Tests
  console.log(`${colors.blue}━━━ END-TO-END INTEGRATION TESTS ━━━${colors.reset}`);
  await runTest('End-to-end task creation', test_end_to_end_task_creation);

  // Summary
  console.log();
  console.log(`${colors.blue}═══════════════════════════════════════════════════════${colors.reset}`);
  console.log(`${colors.blue}  Test Summary${colors.reset}`);
  console.log(`${colors.blue}═══════════════════════════════════════════════════════${colors.reset}`);
  console.log(`${colors.green}Passed: ${testResults.passed}${colors.reset}`);
  console.log(`${colors.red}Failed: ${testResults.failed}${colors.reset}`);
  console.log(`Total: ${testResults.passed + testResults.failed}`);

  if (testResults.failed > 0) {
    console.log(`\n${colors.red}Failed Tests:${colors.reset}`);
    testResults.errors.forEach(({ test, error }) => {
      console.log(`  ${colors.red}✗${colors.reset} ${test}`);
      console.log(`    ${error}`);
    });
  }

  console.log();

  if (testResults.failed === 0) {
    console.log(`${colors.green}✓ ALL TESTS PASSED (GREEN phase complete!)${colors.reset}`);
  } else {
    console.log(`${colors.yellow}⚠ TESTS FAILING (Expected for RED phase of TDD)${colors.reset}`);
    console.log(`${colors.yellow}Next step: Implement features to make tests pass${colors.reset}`);
  }

  // Close database
  db.close();

  process.exit(testResults.failed > 0 ? 1 : 0);
}

// Run tests
runAllTests().catch(error => {
  console.error(`${colors.red}Test runner error: ${error.message}${colors.reset}`);
  if (db) db.close();
  process.exit(1);
});
