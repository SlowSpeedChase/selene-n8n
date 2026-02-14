export { config } from './config';
export { logger, createWorkflowLogger } from './logger';
export {
  db,
  getPendingNotes,
  getProcessedNotes,
  markProcessed,
  findByContentHash,
  insertNote,
  getAllNotes,
  getNoteById,
  searchNotesKeyword,
  getRecentNotes,
  getNotesSince,
  getThreadAssignmentsForNotes,
} from './db';
export type { RawNote } from './db';
export { generate, embed, isAvailable } from './ollama';
export {
  getLanceDb,
  closeLanceDb,
  VECTOR_DIMENSIONS,
  getNotesTable,
  indexNote,
  indexNotes,
  deleteNoteVector,
  getIndexedNoteIds,
  searchSimilarNotes,
  type NoteVector,
  type SimilarNote,
  type SearchOptions,
} from './lancedb';
