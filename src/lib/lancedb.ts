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
