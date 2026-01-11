import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { db } from '../../lib/db';

/**
 * Notes API Routes
 * Provides REST endpoints for SeleneChat to access notes over HTTP
 */

// Database row type (combined raw_notes + processed_notes)
interface NoteRow {
  // raw_notes columns
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
  source_uuid?: string | null;  // Column may not exist in all deployments
  test_run: string | null;
  // processed_notes columns
  concepts: string | null;
  concept_confidence: string | null;
  primary_theme: string | null;
  secondary_themes: string | null;
  theme_confidence: number | null;
  overall_sentiment: string | null;
  sentiment_score: number | null;
  emotional_tone: string | null;
  energy_level: string | null;
}

// API response type (camelCase)
interface NoteResponse {
  id: number;
  title: string;
  content: string;
  contentHash: string;
  sourceType: string;
  wordCount: number;
  characterCount: number;
  tags: string[];
  createdAt: string;
  importedAt: string;
  processedAt: string | null;
  exportedAt: string | null;
  status: string;
  exportedToObsidian: boolean;
  sourceUuid: string | null;
  // Processed data
  concepts: string[];
  conceptConfidence: Record<string, number>;
  primaryTheme: string | null;
  secondaryThemes: string[];
  themeConfidence: number | null;
  overallSentiment: string | null;
  sentimentScore: number | null;
  emotionalTone: string | null;
  energyLevel: string | null;
}

/**
 * Transform database row (snake_case) to API response (camelCase)
 * Also parses JSON fields
 */
function formatNote(row: NoteRow): NoteResponse {
  return {
    id: row.id,
    title: row.title,
    content: row.content,
    contentHash: row.content_hash,
    sourceType: row.source_type,
    wordCount: row.word_count,
    characterCount: row.character_count,
    tags: parseJsonArray(row.tags),
    createdAt: row.created_at,
    importedAt: row.imported_at,
    processedAt: row.processed_at,
    exportedAt: row.exported_at,
    status: row.status,
    exportedToObsidian: row.exported_to_obsidian === 1,
    sourceUuid: row.source_uuid ?? null,
    // Processed data
    concepts: parseJsonArray(row.concepts),
    conceptConfidence: parseJsonObject(row.concept_confidence),
    primaryTheme: row.primary_theme,
    secondaryThemes: parseJsonArray(row.secondary_themes),
    themeConfidence: row.theme_confidence,
    overallSentiment: row.overall_sentiment,
    sentimentScore: row.sentiment_score,
    emotionalTone: row.emotional_tone,
    energyLevel: row.energy_level,
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
 * Safely parse JSON object, returning empty object on failure
 */
function parseJsonObject(json: string | null): Record<string, number> {
  if (!json) return {};
  try {
    const parsed = JSON.parse(json);
    return typeof parsed === 'object' && parsed !== null ? parsed : {};
  } catch {
    return {};
  }
}

/**
 * Escape SQL LIKE wildcard characters (% and _)
 */
function escapeForLike(str: string): string {
  return str.replace(/[%_]/g, '\\$&');
}

/**
 * Base SQL query that joins raw_notes with processed_notes
 * Filters out test data by default
 */
const BASE_SELECT = `
  SELECT
    r.id, r.title, r.content, r.content_hash, r.source_type,
    r.word_count, r.character_count, r.tags, r.created_at,
    r.imported_at, r.processed_at, r.exported_at, r.status,
    r.exported_to_obsidian, r.test_run,
    p.concepts, p.concept_confidence, p.primary_theme,
    p.secondary_themes, p.theme_confidence, p.overall_sentiment,
    p.sentiment_score, p.emotional_tone, p.energy_level
  FROM raw_notes r
  LEFT JOIN processed_notes p ON r.id = p.raw_note_id
  WHERE r.test_run IS NULL
`;

/**
 * Notes API plugin for Fastify
 */
export const notesRoutes: FastifyPluginAsync = async (server: FastifyInstance) => {
  /**
   * GET /api/notes - List recent notes
   * Query params:
   *   - limit: number of notes to return (default 50, max 500)
   */
  server.get<{
    Querystring: { limit?: string };
  }>('/api/notes', async (request, reply) => {
    const limitStr = request.query.limit;
    const limit = limitStr ? parseInt(limitStr, 10) : 50;
    if (isNaN(limit) || limit < 1 || limit > 500) {
      return reply.status(400).send({ error: 'Invalid limit parameter' });
    }

    const rows = db.prepare(`
      ${BASE_SELECT}
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(limit) as NoteRow[];

    return {
      notes: rows.map(formatNote),
      count: rows.length,
    };
  });

  /**
   * GET /api/notes/:id - Get single note by ID
   */
  server.get<{
    Params: { id: string };
  }>('/api/notes/:id', async (request, reply) => {
    const id = parseInt(request.params.id, 10);

    if (isNaN(id)) {
      reply.status(400);
      return { error: 'Invalid note ID' };
    }

    const row = db.prepare(`
      ${BASE_SELECT}
      AND r.id = ?
    `).get(id) as NoteRow | undefined;

    if (!row) {
      reply.status(404);
      return { error: 'Note not found' };
    }

    return { note: formatNote(row) };
  });

  /**
   * GET /api/notes/search - Full-text search
   * Query params:
   *   - q: search query (required)
   *   - limit: number of results (default 50, max 500)
   */
  server.get<{
    Querystring: { q?: string; limit?: string };
  }>('/api/notes/search', async (request, reply) => {
    const query = request.query.q;
    const limitStr = request.query.limit;
    const limit = limitStr ? parseInt(limitStr, 10) : 50;
    if (isNaN(limit) || limit < 1 || limit > 500) {
      return reply.status(400).send({ error: 'Invalid limit parameter' });
    }

    if (!query) {
      reply.status(400);
      return { error: 'Search query (q) is required' };
    }

    // Use LIKE for simple search (SQLite FTS could be added later)
    // Escape SQL wildcards to prevent unintended pattern matching
    const escaped = escapeForLike(query);
    const searchPattern = `%${escaped}%`;

    const rows = db.prepare(`
      ${BASE_SELECT}
      AND (r.title LIKE ? OR r.content LIKE ?)
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(searchPattern, searchPattern, limit) as NoteRow[];

    return {
      notes: rows.map(formatNote),
      count: rows.length,
      query,
    };
  });

  /**
   * GET /api/notes/by-concept - Filter by concept
   * Query params:
   *   - concept: concept to filter by (required)
   *   - limit: number of results (default 50, max 500)
   */
  server.get<{
    Querystring: { concept?: string; limit?: string };
  }>('/api/notes/by-concept', async (request, reply) => {
    const concept = request.query.concept;
    const limitStr = request.query.limit;
    const limit = limitStr ? parseInt(limitStr, 10) : 50;
    if (isNaN(limit) || limit < 1 || limit > 500) {
      return reply.status(400).send({ error: 'Invalid limit parameter' });
    }

    if (!concept) {
      reply.status(400);
      return { error: 'Concept parameter is required' };
    }

    // Search in JSON array using LIKE (concepts stored as JSON array)
    // Escape SQL wildcards to prevent unintended pattern matching
    const escaped = escapeForLike(concept);
    const searchPattern = `%"${escaped}"%`;

    const rows = db.prepare(`
      ${BASE_SELECT}
      AND p.concepts LIKE ?
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(searchPattern, limit) as NoteRow[];

    return {
      notes: rows.map(formatNote),
      count: rows.length,
      concept,
    };
  });

  /**
   * GET /api/notes/by-theme - Filter by theme
   * Query params:
   *   - theme: theme to filter by (required)
   *   - limit: number of results (default 50, max 500)
   */
  server.get<{
    Querystring: { theme?: string; limit?: string };
  }>('/api/notes/by-theme', async (request, reply) => {
    const theme = request.query.theme;
    const limitStr = request.query.limit;
    const limit = limitStr ? parseInt(limitStr, 10) : 50;
    if (isNaN(limit) || limit < 1 || limit > 500) {
      return reply.status(400).send({ error: 'Invalid limit parameter' });
    }

    if (!theme) {
      reply.status(400);
      return { error: 'Theme parameter is required' };
    }

    // Match primary_theme exactly or search in secondary_themes JSON array
    // Escape SQL wildcards to prevent unintended pattern matching
    const escaped = escapeForLike(theme);
    const searchPattern = `%"${escaped}"%`;

    const rows = db.prepare(`
      ${BASE_SELECT}
      AND (p.primary_theme = ? OR p.secondary_themes LIKE ?)
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(theme, searchPattern, limit) as NoteRow[];

    return {
      notes: rows.map(formatNote),
      count: rows.length,
      theme,
    };
  });

  /**
   * GET /api/notes/by-energy - Filter by energy level
   * Query params:
   *   - energy: energy level (low, medium, high) (required)
   *   - limit: number of results (default 50, max 500)
   */
  server.get<{
    Querystring: { energy?: string; limit?: string };
  }>('/api/notes/by-energy', async (request, reply) => {
    const energy = request.query.energy?.toLowerCase();
    const limitStr = request.query.limit;
    const limit = limitStr ? parseInt(limitStr, 10) : 50;
    if (isNaN(limit) || limit < 1 || limit > 500) {
      return reply.status(400).send({ error: 'Invalid limit parameter' });
    }

    if (!energy) {
      reply.status(400);
      return { error: 'Energy parameter is required' };
    }

    const validLevels = ['low', 'medium', 'high'];
    if (!validLevels.includes(energy)) {
      reply.status(400);
      return { error: 'Energy must be one of: low, medium, high' };
    }

    const rows = db.prepare(`
      ${BASE_SELECT}
      AND p.energy_level = ?
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(energy, limit) as NoteRow[];

    return {
      notes: rows.map(formatNote),
      count: rows.length,
      energy,
    };
  });

  /**
   * GET /api/notes/by-date - Filter by date range
   * Query params:
   *   - from: start date (ISO format, required)
   *   - to: end date (ISO format, optional, defaults to now)
   *   - limit: number of results (default 50, max 500)
   */
  server.get<{
    Querystring: { from?: string; to?: string; limit?: string };
  }>('/api/notes/by-date', async (request, reply) => {
    const from = request.query.from;
    const to = request.query.to || new Date().toISOString();
    const limitStr = request.query.limit;
    const limit = limitStr ? parseInt(limitStr, 10) : 50;
    if (isNaN(limit) || limit < 1 || limit > 500) {
      return reply.status(400).send({ error: 'Invalid limit parameter' });
    }

    if (!from) {
      reply.status(400);
      return { error: 'From date parameter is required' };
    }

    // Validate dates
    const fromDate = new Date(from);
    const toDate = new Date(to);

    if (isNaN(fromDate.getTime())) {
      reply.status(400);
      return { error: 'Invalid from date format' };
    }

    if (isNaN(toDate.getTime())) {
      reply.status(400);
      return { error: 'Invalid to date format' };
    }

    const rows = db.prepare(`
      ${BASE_SELECT}
      AND r.created_at >= ? AND r.created_at <= ?
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(from, to, limit) as NoteRow[];

    return {
      notes: rows.map(formatNote),
      count: rows.length,
      from,
      to,
    };
  });
};
