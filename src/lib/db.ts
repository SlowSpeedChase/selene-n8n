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

// Helper: Get all notes with processed data
export function getAllNotes(limit = 100): RawNote[] {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level
    FROM raw_notes r
    LEFT JOIN processed_notes p ON r.id = p.raw_note_id
    WHERE r.test_run IS NULL
    ORDER BY r.created_at DESC
    LIMIT ?
  `);
  return stmt.all(limit) as RawNote[];
}

// Helper: Get note by ID with processed data
export function getNoteById(id: number): RawNote | undefined {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level
    FROM raw_notes r
    LEFT JOIN processed_notes p ON r.id = p.raw_note_id
    WHERE r.id = ? AND r.test_run IS NULL
  `);
  return stmt.get(id) as RawNote | undefined;
}

// Helper: Keyword search across notes
export function searchNotesKeyword(query: string, limit = 50): RawNote[] {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level
    FROM raw_notes r
    LEFT JOIN processed_notes p ON r.id = p.raw_note_id
    WHERE r.test_run IS NULL
      AND (r.content LIKE ? OR r.title LIKE ?)
    ORDER BY r.created_at DESC
    LIMIT ?
  `);
  const pattern = '%' + query + '%';
  return stmt.all(pattern, pattern, limit) as RawNote[];
}

// Helper: Get recent notes within N days
export function getRecentNotes(days: number, limit = 10): RawNote[] {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level
    FROM raw_notes r
    LEFT JOIN processed_notes p ON r.id = p.raw_note_id
    WHERE r.test_run IS NULL
      AND r.created_at >= datetime('now', '-' || ? || ' days')
    ORDER BY r.created_at DESC
    LIMIT ?
  `);
  return stmt.all(days, limit) as RawNote[];
}

// Helper: Get notes since a specific date
export function getNotesSince(date: string, limit = 20): RawNote[] {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level
    FROM raw_notes r
    LEFT JOIN processed_notes p ON r.id = p.raw_note_id
    WHERE r.test_run IS NULL
      AND r.created_at >= ?
    ORDER BY r.created_at DESC
    LIMIT ?
  `);
  return stmt.all(date, limit) as RawNote[];
}

// Helper: Get thread assignments for a batch of note IDs
export function getThreadAssignmentsForNotes(noteIds: number[]): Array<{ noteId: number; threadName: string; threadId: number }> {
  if (noteIds.length === 0) return [];
  const placeholders = noteIds.map(() => '?').join(',');
  const stmt = db.prepare(`
    SELECT tn.raw_note_id as noteId, t.name as threadName, t.id as threadId
    FROM thread_notes tn
    JOIN threads t ON tn.thread_id = t.id
    WHERE tn.raw_note_id IN (${placeholders})
  `);
  return stmt.all(...noteIds) as Array<{ noteId: number; threadName: string; threadId: number }>;
}

// Type for threads table
export interface Thread {
  id: number;
  name: string;
  why: string | null;
  summary: string | null;
  status: string;
  note_count: number;
  last_activity_at: string | null;
  emotional_charge: number | null;
  momentum_score: number | null;
  created_at: string;
  updated_at: string;
}

// Type for thread_tasks table
export interface ThreadTask {
  id: number;
  thread_id: number;
  things_task_id: string;
  created_at: string;
  completed_at: string | null;
}

// Type for notes joined with processed data (used by thread queries)
export interface NoteWithProcessedData extends RawNote {
  concepts: string | null;
  concept_confidence: string | null;
  primary_theme: string | null;
  secondary_themes: string | null;
  overall_sentiment: string | null;
  sentiment_score: number | null;
  emotional_tone: string | null;
  energy_level: string | null;
}

// Helper: Get active threads ordered by momentum
export function getActiveThreads(limit = 10): Thread[] {
  const stmt = db.prepare(`
    SELECT t.*,
      (SELECT COUNT(*) FROM thread_notes tn WHERE tn.thread_id = t.id) as note_count
    FROM threads t
    WHERE t.status = 'active'
    ORDER BY t.momentum_score DESC NULLS LAST, t.last_activity_at DESC
    LIMIT ?
  `);
  return stmt.all(limit) as Thread[];
}

// Helper: Get thread by ID
export function getThreadById(id: number): Thread | undefined {
  const stmt = db.prepare(`
    SELECT t.*,
      (SELECT COUNT(*) FROM thread_notes tn WHERE tn.thread_id = t.id) as note_count
    FROM threads t
    WHERE t.id = ?
  `);
  return stmt.get(id) as Thread | undefined;
}

// Helper: Fuzzy search thread by name
export function searchThreadByName(name: string): Thread | undefined {
  const stmt = db.prepare(`
    SELECT t.*,
      (SELECT COUNT(*) FROM thread_notes tn WHERE tn.thread_id = t.id) as note_count
    FROM threads t
    WHERE LOWER(t.name) LIKE LOWER(?)
    ORDER BY t.momentum_score DESC NULLS LAST
    LIMIT 1
  `);
  return stmt.get('%' + name + '%') as Thread | undefined;
}

// Helper: Get notes belonging to a thread with processed data
export function getThreadNotes(threadId: number, limit = 20): NoteWithProcessedData[] {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level
    FROM thread_notes tn
    JOIN raw_notes r ON tn.raw_note_id = r.id
    LEFT JOIN processed_notes p ON r.id = p.raw_note_id
    WHERE tn.thread_id = ?
    ORDER BY r.created_at DESC
    LIMIT ?
  `);
  return stmt.all(threadId, limit) as NoteWithProcessedData[];
}

// Helper: Get tasks associated with a thread
export function getTasksForThread(threadId: number): ThreadTask[] {
  const stmt = db.prepare(`
    SELECT * FROM thread_tasks
    WHERE thread_id = ?
    ORDER BY created_at DESC
  `);
  return stmt.all(threadId) as ThreadTask[];
}

// Cleanup on process exit
process.on('exit', () => {
  db.close();
});
