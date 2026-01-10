import { createWorkflowLogger, db, generate } from '../lib';
import type { WorkflowResult } from '../types';

const log = createWorkflowLogger('detect-threads');

// Configuration
// Tuned via US-046: 0.65 provides best balance between cluster detection and over-merging
const DEFAULT_SIMILARITY_THRESHOLD = 0.65;
const MIN_CLUSTER_SIZE = 3;
const MAX_NOTES_PER_SYNTHESIS = 15;

// Types
interface NoteRecord {
  id: number;
  title: string;
  content: string;
  created_at: string;
}

interface AssociationRecord {
  note_a_id: number;
  note_b_id: number;
  similarity_score: number;
}

interface ThreadSynthesis {
  name: string;
  why: string;
  summary: string;
  direction: 'exploring' | 'emerging' | 'clear';
  emotional_tone: 'neutral' | 'positive' | 'negative' | 'mixed';
}

/**
 * Build adjacency list from associations
 */
function buildAdjacencyList(
  associations: AssociationRecord[],
  threshold: number
): Map<number, Set<number>> {
  const adjacency = new Map<number, Set<number>>();

  for (const assoc of associations) {
    if (assoc.similarity_score < threshold) continue;

    if (!adjacency.has(assoc.note_a_id)) {
      adjacency.set(assoc.note_a_id, new Set());
    }
    if (!adjacency.has(assoc.note_b_id)) {
      adjacency.set(assoc.note_b_id, new Set());
    }

    adjacency.get(assoc.note_a_id)!.add(assoc.note_b_id);
    adjacency.get(assoc.note_b_id)!.add(assoc.note_a_id);
  }

  return adjacency;
}

/**
 * Find connected components (clusters) using BFS
 */
function findClusters(adjacency: Map<number, Set<number>>): number[][] {
  const visited = new Set<number>();
  const clusters: number[][] = [];

  for (const nodeId of adjacency.keys()) {
    if (visited.has(nodeId)) continue;

    // BFS to find all connected nodes
    const cluster: number[] = [];
    const queue: number[] = [nodeId];

    while (queue.length > 0) {
      const current = queue.shift()!;
      if (visited.has(current)) continue;

      visited.add(current);
      cluster.push(current);

      const neighbors = adjacency.get(current) || new Set();
      for (const neighbor of neighbors) {
        if (!visited.has(neighbor)) {
          queue.push(neighbor);
        }
      }
    }

    if (cluster.length >= MIN_CLUSTER_SIZE) {
      clusters.push(cluster);
    }
  }

  return clusters;
}

/**
 * Get notes that are already assigned to threads
 */
function getThreadedNoteIds(): Set<number> {
  const rows = db.prepare('SELECT raw_note_id FROM thread_notes').all() as Array<{ raw_note_id: number }>;
  return new Set(rows.map((r) => r.raw_note_id));
}

/**
 * Get note content for synthesis
 */
function getNoteContent(noteIds: number[]): NoteRecord[] {
  const placeholders = noteIds.map(() => '?').join(',');
  return db
    .prepare(
      `SELECT id, title, content, created_at
       FROM raw_notes
       WHERE id IN (${placeholders})
       ORDER BY created_at ASC`
    )
    .all(...noteIds) as NoteRecord[];
}

/**
 * Build LLM prompt for thread synthesis
 */
function buildSynthesisPrompt(notes: NoteRecord[]): string {
  const noteTexts = notes
    .slice(0, MAX_NOTES_PER_SYNTHESIS)
    .map((n, i) => `--- Note ${i + 1} (${n.created_at}) ---\nTitle: ${n.title}\n${n.content}`)
    .join('\n\n');

  return `These notes were written over time by the same person. They cluster together based on semantic similarity.

${noteTexts}

Questions:
1. What thread of thinking connects these notes?
2. What is the underlying want, need, or motivation?
3. Is there a clear direction or is this still exploring?
4. Suggest a short name for this thread (2-5 words)

Respond ONLY with valid JSON (no explanation):
{
  "name": "Short Thread Name",
  "why": "The underlying motivation or goal",
  "summary": "What connects these notes together",
  "direction": "exploring|emerging|clear",
  "emotional_tone": "neutral|positive|negative|mixed"
}`;
}

/**
 * Parse LLM response into ThreadSynthesis
 */
function parseSynthesis(response: string): ThreadSynthesis | null {
  try {
    // Extract JSON from response (handle markdown code blocks)
    const jsonMatch = response.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      log.warn({ response }, 'No JSON found in LLM response');
      return null;
    }

    const parsed = JSON.parse(jsonMatch[0]);

    // Validate required fields
    if (!parsed.name || typeof parsed.name !== 'string') {
      log.warn({ parsed }, 'Missing or invalid name field');
      return null;
    }

    return {
      name: parsed.name,
      why: parsed.why || '',
      summary: parsed.summary || '',
      direction: ['exploring', 'emerging', 'clear'].includes(parsed.direction)
        ? parsed.direction
        : 'exploring',
      emotional_tone: ['neutral', 'positive', 'negative', 'mixed'].includes(parsed.emotional_tone)
        ? parsed.emotional_tone
        : 'neutral',
    };
  } catch (err) {
    log.error({ err, response }, 'Failed to parse LLM response');
    return null;
  }
}

/**
 * Create a thread and link notes to it
 */
function createThread(synthesis: ThreadSynthesis, noteIds: number[]): number {
  const now = new Date().toISOString();

  // Insert thread
  const result = db
    .prepare(
      `INSERT INTO threads (name, why, summary, status, note_count, last_activity_at, created_at, updated_at)
       VALUES (?, ?, ?, 'active', ?, ?, ?, ?)`
    )
    .run(synthesis.name, synthesis.why, synthesis.summary, noteIds.length, now, now, now);

  const threadId = result.lastInsertRowid as number;

  // Link notes to thread
  const linkStmt = db.prepare(
    `INSERT INTO thread_notes (thread_id, raw_note_id, added_at, relevance_score)
     VALUES (?, ?, ?, 1.0)`
  );

  for (const noteId of noteIds) {
    linkStmt.run(threadId, noteId, now);
  }

  // Record creation in history
  db.prepare(
    `INSERT INTO thread_history (thread_id, summary_after, change_type, created_at)
     VALUES (?, ?, 'created', ?)`
  ).run(threadId, synthesis.summary, now);

  log.info({ threadId, name: synthesis.name, noteCount: noteIds.length }, 'Thread created');

  return threadId;
}

/**
 * Main workflow: detect threads from note associations
 */
export async function detectThreads(threshold = DEFAULT_SIMILARITY_THRESHOLD): Promise<WorkflowResult> {
  log.info({ threshold, minClusterSize: MIN_CLUSTER_SIZE }, 'Starting thread detection');

  const result: WorkflowResult = {
    processed: 0,
    errors: 0,
    details: [],
  };

  // Get all associations
  const associations = db
    .prepare('SELECT note_a_id, note_b_id, similarity_score FROM note_associations')
    .all() as AssociationRecord[];

  log.info({ associationCount: associations.length }, 'Loaded associations');

  if (associations.length === 0) {
    log.info('No associations found - run compute-associations first');
    return result;
  }

  // Build adjacency list and find clusters
  const adjacency = buildAdjacencyList(associations, threshold);
  const clusters = findClusters(adjacency);

  log.info({ clusterCount: clusters.length }, 'Found clusters');

  if (clusters.length === 0) {
    log.info('No clusters found above minimum size');
    return result;
  }

  // Get already-threaded notes to avoid duplicates
  const threadedNoteIds = getThreadedNoteIds();

  // Process each cluster
  for (const cluster of clusters) {
    // Filter out already-threaded notes
    const unthreadedNotes = cluster.filter((id) => !threadedNoteIds.has(id));

    if (unthreadedNotes.length < MIN_CLUSTER_SIZE) {
      log.info(
        { clusterSize: cluster.length, unthreadedCount: unthreadedNotes.length },
        'Cluster too small after filtering threaded notes'
      );
      continue;
    }

    try {
      // Get note content
      const notes = getNoteContent(unthreadedNotes);

      if (notes.length < MIN_CLUSTER_SIZE) {
        log.warn({ noteIds: unthreadedNotes }, 'Could not fetch enough notes');
        continue;
      }

      // Build prompt and call LLM
      const prompt = buildSynthesisPrompt(notes);
      log.info({ noteCount: notes.length, promptLength: prompt.length }, 'Calling LLM for synthesis');

      const llmResponse = await generate(prompt);

      // Parse response
      const synthesis = parseSynthesis(llmResponse);
      if (!synthesis) {
        log.error({ cluster: unthreadedNotes }, 'Failed to synthesize thread');
        result.errors++;
        result.details.push({ id: unthreadedNotes[0], success: false, error: 'LLM synthesis failed' });
        continue;
      }

      // Create thread
      const threadId = createThread(synthesis, unthreadedNotes);

      // Mark these notes as threaded for subsequent iterations
      for (const noteId of unthreadedNotes) {
        threadedNoteIds.add(noteId);
      }

      result.processed++;
      result.details.push({ id: threadId, success: true });
    } catch (err) {
      const error = err as Error;
      log.error({ err: error, cluster }, 'Error processing cluster');
      result.errors++;
      result.details.push({ id: cluster[0], success: false, error: error.message });
    }
  }

  log.info(
    { threadsCreated: result.processed, errors: result.errors },
    'Thread detection complete'
  );

  return result;
}

// CLI entry point
if (require.main === module) {
  const threshold = process.argv[2] ? parseFloat(process.argv[2]) : DEFAULT_SIMILARITY_THRESHOLD;

  detectThreads(threshold)
    .then((result) => {
      console.log('Detect-threads complete:', result);
      process.exit(result.errors > 0 ? 1 : 0);
    })
    .catch((err) => {
      console.error('Detect-threads failed:', err);
      process.exit(1);
    });
}
