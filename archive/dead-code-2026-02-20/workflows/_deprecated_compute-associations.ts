import { createWorkflowLogger, db } from '../lib';
import type { WorkflowResult } from '../types';

const log = createWorkflowLogger('compute-associations');

// Default similarity threshold - only store associations above this
const DEFAULT_THRESHOLD = 0.7;

// Type for embedding records from database
interface EmbeddingRecord {
  raw_note_id: number;
  embedding: string; // JSON string of number[]
}

// Type for computed association
interface Association {
  noteAId: number;
  noteBId: number;
  similarity: number;
}

/**
 * Compute cosine similarity between two vectors
 * Returns 0 if vectors are different lengths or have zero magnitude
 */
function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length) return 0;
  let dotProduct = 0,
    normA = 0,
    normB = 0;
  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  const denominator = Math.sqrt(normA) * Math.sqrt(normB);
  return denominator === 0 ? 0 : dotProduct / denominator;
}

/**
 * Get all embeddings from the database
 */
function getAllEmbeddings(): EmbeddingRecord[] {
  return db.prepare('SELECT raw_note_id, embedding FROM note_embeddings').all() as EmbeddingRecord[];
}

/**
 * Compute pairwise associations for all embeddings
 * Only returns associations above the threshold
 */
function computePairwiseAssociations(
  embeddings: EmbeddingRecord[],
  threshold: number
): Association[] {
  const associations: Association[] = [];
  const n = embeddings.length;

  log.info({ embeddingCount: n, pairsToCompute: (n * (n - 1)) / 2 }, 'Computing pairwise similarities');

  for (let i = 0; i < n; i++) {
    const embeddingA = JSON.parse(embeddings[i].embedding) as number[];
    const noteAId = embeddings[i].raw_note_id;

    for (let j = i + 1; j < n; j++) {
      const embeddingB = JSON.parse(embeddings[j].embedding) as number[];
      const noteBId = embeddings[j].raw_note_id;

      const similarity = cosineSimilarity(embeddingA, embeddingB);

      if (similarity >= threshold) {
        // Ensure note_a_id < note_b_id to satisfy table constraint
        const [smallerId, largerId] = noteAId < noteBId ? [noteAId, noteBId] : [noteBId, noteAId];
        associations.push({
          noteAId: smallerId,
          noteBId: largerId,
          similarity,
        });
      }
    }
  }

  return associations;
}

/**
 * Store associations in the database using INSERT OR REPLACE
 */
function storeAssociations(associations: Association[]): { inserted: number; errors: number } {
  const stmt = db.prepare(`
    INSERT OR REPLACE INTO note_associations
    (note_a_id, note_b_id, similarity_score, updated_at)
    VALUES (?, ?, ?, ?)
  `);

  let inserted = 0;
  let errors = 0;
  const now = new Date().toISOString();

  for (const assoc of associations) {
    try {
      stmt.run(assoc.noteAId, assoc.noteBId, assoc.similarity, now);
      inserted++;
    } catch (err) {
      const error = err as Error;
      log.error(
        { noteAId: assoc.noteAId, noteBId: assoc.noteBId, err: error },
        'Failed to store association'
      );
      errors++;
    }
  }

  return { inserted, errors };
}

/**
 * Compute associations between all notes based on embedding similarity
 * @param threshold Minimum similarity score to store (default: 0.7)
 * @returns WorkflowResult with processing statistics
 */
export async function computeAssociations(threshold = DEFAULT_THRESHOLD): Promise<WorkflowResult> {
  log.info({ threshold }, 'Starting association computation');

  const result: WorkflowResult = {
    processed: 0,
    errors: 0,
    details: [],
  };

  // Get all embeddings
  const embeddings = getAllEmbeddings();

  if (embeddings.length < 2) {
    log.info({ embeddingCount: embeddings.length }, 'Not enough embeddings to compute associations');
    return result;
  }

  // Compute pairwise associations
  const associations = computePairwiseAssociations(embeddings, threshold);
  log.info({ associationsFound: associations.length }, 'Associations above threshold');

  // Store associations
  const storeResult = storeAssociations(associations);

  result.processed = storeResult.inserted;
  result.errors = storeResult.errors;

  // Add summary detail
  result.details.push({
    id: 0,
    success: storeResult.errors === 0,
    error:
      storeResult.errors > 0
        ? `${storeResult.errors} associations failed to store`
        : undefined,
  });

  log.info(
    {
      embeddingsProcessed: embeddings.length,
      associationsComputed: associations.length,
      associationsStored: storeResult.inserted,
      errors: storeResult.errors,
    },
    'Association computation complete'
  );

  return result;
}

// CLI entry point
if (require.main === module) {
  const threshold = process.argv[2] ? parseFloat(process.argv[2]) : DEFAULT_THRESHOLD;

  computeAssociations(threshold)
    .then((result) => {
      console.log('Compute-associations complete:', result);
      process.exit(result.errors > 0 ? 1 : 0);
    })
    .catch((err) => {
      console.error('Compute-associations failed:', err);
      process.exit(1);
    });
}
