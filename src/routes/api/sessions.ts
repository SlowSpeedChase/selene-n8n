import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { db } from '../../lib/db';
import { logger } from '../../lib/logger';

/**
 * Sessions API Routes
 * Provides REST endpoints for SeleneChat to persist chat sessions over HTTP
 */

// Database row type (snake_case, matches SQLite schema)
interface SessionRow {
  id: string;
  title: string;
  created_at: string;
  updated_at: string;
  message_count: number;
  is_pinned: number; // SQLite stores boolean as 0/1
  compression_state: string;
  compressed_at: string | null;
  full_messages_json: string | null;
  summary_text: string | null;
}

// Message type for the messages array
interface ChatMessage {
  id: string;
  role: string;
  content: string;
  timestamp: string;
  noteIds?: number[];
}

// API request body type (camelCase, from client)
interface SessionBody {
  id: string;
  title: string;
  createdAt: string;
  updatedAt: string;
  messages: ChatMessage[];
  isPinned: boolean;
  compressionState: string;
  compressedAt: string | null;
  summaryText: string | null;
}

// API response type (camelCase, to client)
interface SessionResponse {
  id: string;
  title: string;
  createdAt: string;
  updatedAt: string;
  messageCount: number;
  isPinned: boolean;
  compressionState: string;
  compressedAt: string | null;
  messages: ChatMessage[];
  summaryText: string | null;
}

/**
 * Ensure chat_sessions table exists
 * Called once when routes are registered
 */
function ensureTableExists(): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS chat_sessions (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      message_count INTEGER NOT NULL,
      is_pinned INTEGER NOT NULL DEFAULT 0,
      compression_state TEXT NOT NULL DEFAULT 'full',
      compressed_at TEXT,
      full_messages_json TEXT,
      summary_text TEXT
    )
  `);

  // Create index if it doesn't exist
  db.exec(`
    CREATE INDEX IF NOT EXISTS index_chat_sessions_on_updated_at
    ON chat_sessions(updated_at)
  `);

  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_chat_sessions_compression
    ON chat_sessions(compression_state, created_at)
  `);
}

/**
 * Transform database row (snake_case) to API response (camelCase)
 * Also parses full_messages_json back to array
 */
function formatSession(row: SessionRow): SessionResponse {
  return {
    id: row.id,
    title: row.title,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    messageCount: row.message_count,
    isPinned: row.is_pinned === 1,
    compressionState: row.compression_state,
    compressedAt: row.compressed_at,
    messages: parseMessagesJson(row.full_messages_json),
    summaryText: row.summary_text,
  };
}

/**
 * Safely parse messages JSON, returning empty array on failure
 */
function parseMessagesJson(json: string | null): ChatMessage[] {
  if (!json) return [];
  try {
    const parsed = JSON.parse(json);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/**
 * Sessions API plugin for Fastify
 */
export const sessionsRoutes: FastifyPluginAsync = async (server: FastifyInstance) => {
  // Ensure table exists on startup
  ensureTableExists();

  /**
   * GET /api/sessions - List all sessions
   * Returns sessions ordered by updated_at DESC
   */
  server.get('/api/sessions', async () => {
    const rows = db.prepare(`
      SELECT * FROM chat_sessions
      ORDER BY updated_at DESC
    `).all() as SessionRow[];

    return {
      sessions: rows.map(formatSession),
      count: rows.length,
    };
  });

  /**
   * POST /api/sessions - Create or update session (upsert)
   * Body: SessionBody
   */
  server.post<{
    Body: SessionBody;
  }>('/api/sessions', async (request, reply) => {
    const body = request.body;

    // Validate required fields
    if (!body.id) {
      reply.status(400);
      return { error: 'Session ID is required' };
    }

    if (!body.title) {
      reply.status(400);
      return { error: 'Session title is required' };
    }

    if (!body.createdAt) {
      reply.status(400);
      return { error: 'createdAt is required' };
    }

    if (!body.updatedAt) {
      reply.status(400);
      return { error: 'updatedAt is required' };
    }

    if (!Array.isArray(body.messages)) {
      reply.status(400);
      return { error: 'messages must be an array' };
    }

    // Validate compression state
    const validStates = ['full', 'compressed', 'hybrid'];
    if (!validStates.includes(body.compressionState)) {
      reply.status(400);
      return { error: `compressionState must be one of: ${validStates.join(', ')}` };
    }

    try {
      // Upsert: INSERT OR REPLACE
      const stmt = db.prepare(`
        INSERT OR REPLACE INTO chat_sessions (
          id, title, created_at, updated_at, message_count,
          is_pinned, compression_state, compressed_at,
          full_messages_json, summary_text
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);

      stmt.run(
        body.id,
        body.title,
        body.createdAt,
        body.updatedAt,
        body.messages.length,
        body.isPinned ? 1 : 0,
        body.compressionState,
        body.compressedAt,
        JSON.stringify(body.messages),
        body.summaryText
      );

      logger.info({ sessionId: body.id, messageCount: body.messages.length }, 'Session saved');

      return {
        status: 'saved',
        id: body.id,
        messageCount: body.messages.length,
      };
    } catch (err) {
      const error = err as Error;
      logger.error({ err: error, sessionId: body.id }, 'Failed to save session');
      reply.status(500);
      return { error: 'Failed to save session', message: error.message };
    }
  });

  /**
   * DELETE /api/sessions/:id - Delete session
   */
  server.delete<{
    Params: { id: string };
  }>('/api/sessions/:id', async (request, reply) => {
    const { id } = request.params;

    if (!id) {
      reply.status(400);
      return { error: 'Session ID is required' };
    }

    try {
      // Check if session exists first
      const existing = db.prepare('SELECT id FROM chat_sessions WHERE id = ?').get(id);

      if (!existing) {
        reply.status(404);
        return { error: 'Session not found' };
      }

      db.prepare('DELETE FROM chat_sessions WHERE id = ?').run(id);

      logger.info({ sessionId: id }, 'Session deleted');

      return {
        status: 'deleted',
        id,
      };
    } catch (err) {
      const error = err as Error;
      logger.error({ err: error, sessionId: id }, 'Failed to delete session');
      reply.status(500);
      return { error: 'Failed to delete session', message: error.message };
    }
  });

  /**
   * PATCH /api/sessions/:id/pin - Toggle pin status
   */
  server.patch<{
    Params: { id: string };
  }>('/api/sessions/:id/pin', async (request, reply) => {
    const { id } = request.params;

    if (!id) {
      reply.status(400);
      return { error: 'Session ID is required' };
    }

    try {
      // Get current pin status
      const existing = db.prepare('SELECT id, is_pinned FROM chat_sessions WHERE id = ?').get(id) as
        | { id: string; is_pinned: number }
        | undefined;

      if (!existing) {
        reply.status(404);
        return { error: 'Session not found' };
      }

      // Toggle pin status
      const newPinStatus = existing.is_pinned === 1 ? 0 : 1;

      db.prepare(`
        UPDATE chat_sessions
        SET is_pinned = ?, updated_at = ?
        WHERE id = ?
      `).run(newPinStatus, new Date().toISOString(), id);

      logger.info({ sessionId: id, isPinned: newPinStatus === 1 }, 'Session pin toggled');

      return {
        status: 'updated',
        id,
        isPinned: newPinStatus === 1,
      };
    } catch (err) {
      const error = err as Error;
      logger.error({ err: error, sessionId: id }, 'Failed to toggle pin status');
      reply.status(500);
      return { error: 'Failed to toggle pin status', message: error.message };
    }
  });

  /**
   * POST /api/sessions/:id/compress - Compress session
   * Sets compression_state to 'compressed' and updates compressed_at
   */
  server.post<{
    Params: { id: string };
    Body: { summaryText?: string };
  }>('/api/sessions/:id/compress', async (request, reply) => {
    const { id } = request.params;
    const { summaryText } = request.body || {};

    if (!id) {
      reply.status(400);
      return { error: 'Session ID is required' };
    }

    try {
      // Check if session exists
      const existing = db.prepare('SELECT id FROM chat_sessions WHERE id = ?').get(id);

      if (!existing) {
        reply.status(404);
        return { error: 'Session not found' };
      }

      const compressedAt = new Date().toISOString();

      db.prepare(`
        UPDATE chat_sessions
        SET compression_state = 'compressed',
            compressed_at = ?,
            updated_at = ?,
            summary_text = COALESCE(?, summary_text)
        WHERE id = ?
      `).run(compressedAt, compressedAt, summaryText || null, id);

      logger.info({ sessionId: id, compressedAt }, 'Session compressed');

      return {
        status: 'compressed',
        id,
        compressedAt,
      };
    } catch (err) {
      const error = err as Error;
      logger.error({ err: error, sessionId: id }, 'Failed to compress session');
      reply.status(500);
      return { error: 'Failed to compress session', message: error.message };
    }
  });
};
