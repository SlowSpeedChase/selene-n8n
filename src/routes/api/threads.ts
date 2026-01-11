import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { db } from '../../lib/db';
import { logger } from '../../lib/logger';

/**
 * Threads API Routes
 * Provides REST endpoints for SeleneChat to access discussion threads over HTTP
 */

// Database row type (snake_case, matches SQLite schema)
// Combined discussion_threads_new + JOIN with raw_notes
interface ThreadRow {
  // discussion_threads_new columns
  id: number;
  raw_note_id: number | null;
  thread_type: string;
  prompt: string;
  status: string;
  created_at: string;
  surfaced_at: string | null;
  completed_at: string | null;
  related_concepts: string | null;
  project_id: number | null;
  thread_name: string | null;
  resurface_reason: string | null;
  last_resurfaced_at: string | null;
  test_run: string | null;
  // JOIN fields from raw_notes
  note_title: string | null;
  note_content: string | null;
}

// API response type (camelCase)
interface ThreadResponse {
  id: number;
  rawNoteId: number | null;
  threadType: string;
  prompt: string;
  status: string;
  createdAt: string;
  surfacedAt: string | null;
  completedAt: string | null;
  relatedConcepts: string[];
  projectId: number | null;
  threadName: string | null;
  resurfaceReason: string | null;
  lastResurfacedAt: string | null;
  // JOIN fields
  noteTitle: string | null;
  noteContent: string | null;
}

/**
 * Transform database row (snake_case) to API response (camelCase)
 * Also parses JSON fields
 */
function formatThread(row: ThreadRow): ThreadResponse {
  return {
    id: row.id,
    rawNoteId: row.raw_note_id,
    threadType: row.thread_type,
    prompt: row.prompt,
    status: row.status,
    createdAt: row.created_at,
    surfacedAt: row.surfaced_at,
    completedAt: row.completed_at,
    relatedConcepts: parseJsonArray(row.related_concepts),
    projectId: row.project_id,
    threadName: row.thread_name,
    resurfaceReason: row.resurface_reason,
    lastResurfacedAt: row.last_resurfaced_at,
    noteTitle: row.note_title,
    noteContent: row.note_content,
  };
}

/**
 * Safely parse JSON array, returning empty array on failure
 */
function parseJsonArray(json: string | null): string[] {
  if (!json) return [];
  try {
    const parsed = JSON.parse(json);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/**
 * Base SQL query that joins discussion_threads_new with raw_notes
 * Filters out test data by default
 */
const BASE_SELECT = `
  SELECT
    dt.id, dt.raw_note_id, dt.thread_type, dt.prompt, dt.status,
    dt.created_at, dt.surfaced_at, dt.completed_at,
    dt.related_concepts, dt.project_id, dt.thread_name,
    dt.resurface_reason, dt.last_resurfaced_at, dt.test_run,
    r.title AS note_title, r.content AS note_content
  FROM discussion_threads_new dt
  LEFT JOIN raw_notes r ON dt.raw_note_id = r.id
  WHERE dt.test_run IS NULL
`;

/**
 * Threads API plugin for Fastify
 */
export const threadsRoutes: FastifyPluginAsync = async (server: FastifyInstance) => {
  /**
   * GET /api/threads - List pending/active/review threads
   * Returns threads ordered by: review status first, then by created_at DESC
   * Query params:
   *   - limit: number of threads to return (default 50, max 500)
   */
  server.get<{
    Querystring: { limit?: string };
  }>('/api/threads', async (request, reply) => {
    const limitStr = request.query.limit;
    const limit = limitStr ? parseInt(limitStr, 10) : 50;
    if (isNaN(limit) || limit < 1 || limit > 500) {
      return reply.status(400).send({ error: 'Invalid limit parameter' });
    }

    const rows = db.prepare(`
      ${BASE_SELECT}
      AND dt.status IN ('pending', 'active', 'review')
      ORDER BY
        CASE WHEN dt.status = 'review' THEN 0 ELSE 1 END,
        dt.created_at DESC
      LIMIT ?
    `).all(limit) as ThreadRow[];

    return {
      threads: rows.map(formatThread),
      count: rows.length,
    };
  });

  /**
   * GET /api/threads/:id - Get single thread by ID
   */
  server.get<{
    Params: { id: string };
  }>('/api/threads/:id', async (request, reply) => {
    const id = parseInt(request.params.id, 10);

    if (isNaN(id)) {
      reply.status(400);
      return { error: 'Invalid thread ID' };
    }

    const row = db.prepare(`
      ${BASE_SELECT}
      AND dt.id = ?
    `).get(id) as ThreadRow | undefined;

    if (!row) {
      reply.status(404);
      return { error: 'Thread not found' };
    }

    return { thread: formatThread(row) };
  });

  /**
   * PATCH /api/threads/:id/status - Update thread status
   * Body: { status: string }
   * Side effects:
   *   - If status = 'active', sets surfaced_at = now
   *   - If status = 'completed' or 'dismissed', sets completed_at = now
   */
  server.patch<{
    Params: { id: string };
    Body: { status: string };
  }>('/api/threads/:id/status', async (request, reply) => {
    const id = parseInt(request.params.id, 10);
    const { status } = request.body || {};

    if (isNaN(id)) {
      reply.status(400);
      return { error: 'Invalid thread ID' };
    }

    if (!status) {
      reply.status(400);
      return { error: 'Status is required' };
    }

    const validStatuses = ['pending', 'active', 'review', 'completed', 'dismissed'];
    if (!validStatuses.includes(status)) {
      reply.status(400);
      return { error: `Status must be one of: ${validStatuses.join(', ')}` };
    }

    try {
      // Check if thread exists
      const existing = db.prepare('SELECT id FROM discussion_threads_new WHERE id = ? AND test_run IS NULL').get(id);

      if (!existing) {
        reply.status(404);
        return { error: 'Thread not found' };
      }

      const now = new Date().toISOString();

      // Build update based on status
      if (status === 'active') {
        // Set surfaced_at when becoming active
        db.prepare(`
          UPDATE discussion_threads_new
          SET status = ?, surfaced_at = COALESCE(surfaced_at, ?)
          WHERE id = ?
        `).run(status, now, id);
      } else if (status === 'completed' || status === 'dismissed') {
        // Set completed_at when completing or dismissing
        db.prepare(`
          UPDATE discussion_threads_new
          SET status = ?, completed_at = ?
          WHERE id = ?
        `).run(status, now, id);
      } else {
        // Simple status update for pending/review
        db.prepare(`
          UPDATE discussion_threads_new
          SET status = ?
          WHERE id = ?
        `).run(status, id);
      }

      logger.info({ threadId: id, status }, 'Thread status updated');

      return {
        status: 'updated',
        id,
        newStatus: status,
      };
    } catch (err) {
      const error = err as Error;
      logger.error({ err: error, threadId: id }, 'Failed to update thread status');
      reply.status(500);
      return { error: 'Failed to update thread status', message: error.message };
    }
  });
};
