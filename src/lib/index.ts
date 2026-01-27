export { config } from './config';
export { logger, createWorkflowLogger } from './logger';
export {
  db,
  getPendingNotes,
  getProcessedNotes,
  markProcessed,
  findByContentHash,
  insertNote,
} from './db';
export type { RawNote } from './db';
export { generate, embed, isAvailable } from './ollama';
export { getLanceDb, closeLanceDb, VECTOR_DIMENSIONS } from './lancedb';
