import * as lancedb from '@lancedb/lancedb';
import type { Table } from '@lancedb/lancedb';
import path from 'path';
import { config } from './config';
import { logger } from './logger';

const log = logger.child({ module: 'lancedb' });

// Vector dimensions for nomic-embed-text
export const VECTOR_DIMENSIONS = 768;

// Database connection (lazy initialized)
let dbConnection: Awaited<ReturnType<typeof lancedb.connect>> | null = null;

/**
 * Get or create database connection
 */
export async function getLanceDb() {
  if (!dbConnection) {
    const dbPath = path.join(path.dirname(config.dbPath), 'vectors.lance');
    log.info({ dbPath }, 'Connecting to LanceDB');
    dbConnection = await lancedb.connect(dbPath);
  }
  return dbConnection;
}

/**
 * Close database connection (for cleanup)
 */
export async function closeLanceDb() {
  if (dbConnection) {
    dbConnection = null;
    log.info('LanceDB connection closed');
  }
}

// Schema for note vectors with metadata
export interface NoteVector {
  id: number;              // Matches raw_note_id
  vector: number[];        // 768-dim embedding from nomic-embed-text
  title: string;
  primary_theme: string | null;
  note_type: string | null;       // task, reflection, reference, idea, log
  actionability: string | null;   // actionable, someday, reference, done
  time_horizon: string | null;    // immediate, week, month, timeless
  context: string | null;         // JSON array of contexts
  created_at: string;
  indexed_at: string;
}

let notesTable: Table | null = null;

/**
 * Get or create the notes vector table
 */
export async function getNotesTable(): Promise<Table> {
  if (notesTable) return notesTable;

  const db = await getLanceDb();
  const tableNames = await db.tableNames();

  if (tableNames.includes('notes')) {
    log.info('Opening existing notes table');
    notesTable = await db.openTable('notes');
  } else {
    log.info('Creating new notes table with schema');
    // Create with placeholder to establish schema
    // Use empty strings for nullable fields so LanceDB can infer string type
    notesTable = await db.createTable('notes', [{
      id: -1,
      vector: new Array(VECTOR_DIMENSIONS).fill(0),
      title: '__schema_placeholder__',
      primary_theme: '',
      note_type: '',
      actionability: '',
      time_horizon: '',
      context: '',
      created_at: new Date().toISOString(),
      indexed_at: new Date().toISOString(),
    }]);
    // Delete placeholder
    await notesTable.delete('id = -1');
    log.info('Notes table created');
  }

  return notesTable;
}
