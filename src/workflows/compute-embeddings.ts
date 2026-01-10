import { createWorkflowLogger, db, embed, isAvailable } from '../lib';
import type { WorkflowResult } from '../types';

const log = createWorkflowLogger('compute-embeddings');

export async function computeEmbeddings(limit = 10): Promise<WorkflowResult> {
  log.info({ limit }, 'Starting embedding computation run');

  if (!(await isAvailable())) {
    log.error('Ollama is not available');
    return { processed: 0, errors: 0, details: [] };
  }

  // Get notes without embeddings
  const notes = db
    .prepare(
      `SELECT rn.id, rn.title, rn.content
       FROM raw_notes rn
       LEFT JOIN note_embeddings ne ON rn.id = ne.note_id
       WHERE ne.note_id IS NULL
       LIMIT ?`
    )
    .all(limit) as Array<{ id: number; title: string; content: string }>;

  log.info({ noteCount: notes.length }, 'Found notes needing embeddings');

  const result: WorkflowResult = { processed: 0, errors: 0, details: [] };

  for (const note of notes) {
    try {
      log.info({ noteId: note.id, title: note.title }, 'Computing embedding');

      // Combine title and content for embedding
      const text = `${note.title}\n\n${note.content}`;
      const embedding = await embed(text);

      // Store embedding
      db.prepare(
        `INSERT INTO note_embeddings (note_id, embedding, model, created_at)
         VALUES (?, ?, ?, ?)`
      ).run(note.id, JSON.stringify(embedding), 'nomic-embed-text', new Date().toISOString());

      log.info({ noteId: note.id, dimensions: embedding.length }, 'Embedding stored');
      result.processed++;
      result.details.push({ id: note.id, success: true });
    } catch (err) {
      const error = err as Error;
      log.error({ noteId: note.id, err: error }, 'Failed to compute embedding');
      result.errors++;
      result.details.push({ id: note.id, success: false, error: error.message });
    }
  }

  log.info(result, 'Embedding computation run complete');
  return result;
}

// CLI entry point
if (require.main === module) {
  computeEmbeddings()
    .then((result) => {
      console.log('Compute-embeddings complete:', result);
      process.exit(result.errors > 0 ? 1 : 0);
    })
    .catch((err) => {
      console.error('Compute-embeddings failed:', err);
      process.exit(1);
    });
}
