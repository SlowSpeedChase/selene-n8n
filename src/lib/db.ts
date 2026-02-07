import Database, { Database as DatabaseType } from 'better-sqlite3';
import { config } from './config';
import { logger } from './logger';

// Initialize database connection
export const db: DatabaseType = new Database(config.dbPath);

// Enable WAL mode for better concurrency
db.pragma('journal_mode = WAL');

logger.info({ dbPath: config.dbPath, env: config.env }, 'Database connected');

// Fail-safe: Verify test environment is using test database
if (config.isTestEnv) {
  try {
    const result = db.prepare(
      "SELECT value FROM _selene_metadata WHERE key = 'environment'"
    ).get() as { value: string } | undefined;

    if (!result || result.value !== 'test') {
      logger.error(
        { dbPath: config.dbPath },
        'SELENE_ENV=test but database is not a test database. Run ./scripts/create-test-db.sh first.'
      );
      throw new Error(
        `SELENE_ENV=test but database is not marked as test environment.\n` +
        `Expected _selene_metadata.environment = 'test'.\n` +
        `Run ./scripts/create-test-db.sh to create a test database.`
      );
    }

    logger.info('Test environment verified');
  } catch (err: unknown) {
    // If table doesn't exist, that's also a failure
    if (err instanceof Error && err.message.includes('no such table')) {
      logger.error(
        { dbPath: config.dbPath },
        'SELENE_ENV=test but _selene_metadata table not found. Run ./scripts/create-test-db.sh first.'
      );
      throw new Error(
        `SELENE_ENV=test but _selene_metadata table not found.\n` +
        `Run ./scripts/create-test-db.sh to create a test database.`
      );
    }
    throw err;
  }
}

// Type for raw_notes table
export interface RawNote {
  id: number;
  title: string;
  content: string;
  content_hash: string;
  source_type: string;
  word_count: number;
  character_count: number;
  tags: string | null;
  created_at: string;
  imported_at: string;
  processed_at: string | null;
  exported_at: string | null;
  status: string;
  exported_to_obsidian: number;
  test_run: string | null;
}

// Helper: Get pending notes for processing
export function getPendingNotes(limit = 10): RawNote[] {
  return db
    .prepare('SELECT * FROM raw_notes WHERE status = ? ORDER BY created_at ASC LIMIT ?')
    .all('pending', limit) as RawNote[];
}

// Helper: Get processed notes needing further work
export function getProcessedNotes(limit = 10): RawNote[] {
  return db
    .prepare('SELECT * FROM raw_notes WHERE status = ? ORDER BY processed_at ASC LIMIT ?')
    .all('processed', limit) as RawNote[];
}

// Helper: Mark note as processed
export function markProcessed(id: number): void {
  db.prepare('UPDATE raw_notes SET status = ?, processed_at = ? WHERE id = ?').run(
    'processed',
    new Date().toISOString(),
    id
  );
}

// Helper: Check for duplicate by content hash
export function findByContentHash(hash: string): RawNote | undefined {
  return db.prepare('SELECT * FROM raw_notes WHERE content_hash = ?').get(hash) as
    | RawNote
    | undefined;
}

// Helper: Insert new note
export function insertNote(note: {
  title: string;
  content: string;
  contentHash: string;
  tags: string[];
  createdAt: string;
  testRun?: string;
}): number {
  const wordCount = note.content.split(/\s+/).filter(Boolean).length;
  const characterCount = note.content.length;

  const result = db
    .prepare(
      `INSERT INTO raw_notes
       (title, content, content_hash, tags, word_count, character_count, created_at, status, test_run)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?)`
    )
    .run(
      note.title,
      note.content,
      note.contentHash,
      JSON.stringify(note.tags),
      wordCount,
      characterCount,
      note.createdAt,
      note.testRun || null
    );

  return result.lastInsertRowid as number;
}

// Cleanup on process exit
process.on('exit', () => {
  db.close();
});
