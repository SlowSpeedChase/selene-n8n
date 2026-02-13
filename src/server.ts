import Fastify from 'fastify';
import { config, logger } from './lib';
import { requireAuth } from './lib/auth';
import { ingest } from './workflows/ingest';
import { exportObsidian } from './workflows/export-obsidian';
import { getRelatedNotes, searchNotes } from './queries/related-notes';
import { notesRoutes } from './routes/notes';
import { threadsRoutes } from './routes/threads';
import { sessionsRoutes } from './routes/sessions';
import { memoriesRoutes } from './routes/memories';
import { llmRoutes } from './routes/llm';
import { briefingRoutes } from './routes/briefing';
import type { IngestInput, WebhookResponse } from './types';

const server = Fastify({
  logger: false, // We use our own logger
});

// Auth middleware for all /api/* routes
server.addHook('onRequest', async (request, reply) => {
  if (request.url.startsWith('/api/')) {
    await requireAuth(request, reply);
  }
});

// Health check endpoint
server.get('/health', async () => {
  return { status: 'ok', timestamp: new Date().toISOString() };
});

// Main webhook endpoint - same URL as n8n
server.post<{ Body: IngestInput }>('/webhook/api/drafts', async (request, reply) => {
  const { title, content, created_at, test_run } = request.body;

  logger.info({ title, test_run }, 'Webhook received');

  // Validate required fields
  if (!title || !content) {
    logger.warn({ title: !!title, content: !!content }, 'Missing required fields');
    reply.status(400);
    return { status: 'error', message: 'Title and content are required' } as WebhookResponse;
  }

  try {
    const result = await ingest({ title, content, created_at, test_run });

    if (result.duplicate) {
      logger.info({ title, existingId: result.existingId }, 'Duplicate skipped');
      return { status: 'duplicate', id: result.existingId } as WebhookResponse;
    }

    logger.info({ id: result.id, title }, 'Note created');
    return { status: 'created', id: result.id } as WebhookResponse;
  } catch (err) {
    const error = err as Error;
    logger.error({ err: error, title }, 'Ingestion failed');
    reply.status(500);
    return { status: 'error', message: error.message } as WebhookResponse;
  }
});

// Manual export trigger endpoint
server.post<{ Body: { noteId?: number } }>('/webhook/api/export-obsidian', async (request, reply) => {
  const { noteId } = request.body || {};

  logger.info({ noteId }, 'Export-obsidian webhook received');

  try {
    const result = await exportObsidian(noteId);
    return result;
  } catch (err) {
    const error = err as Error;
    logger.error({ err: error }, 'Export-obsidian failed');
    reply.status(500);
    return { success: false, exported_count: 0, errors: 1, message: error.message };
  }
});

// Related notes API - for SeleneChat vector search
server.post<{
  Body: { noteId: number; limit?: number; includeLive?: boolean };
}>('/api/related-notes', async (request, reply) => {
  const { noteId, limit = 10, includeLive = true } = request.body || {};

  if (!noteId || typeof noteId !== 'number') {
    reply.status(400);
    return { error: 'noteId is required and must be a number' };
  }

  try {
    const results = await getRelatedNotes(noteId, { limit, includeLive });
    return { noteId, count: results.length, results };
  } catch (err) {
    const error = err as Error;
    logger.error({ err: error, noteId }, 'Related notes query failed');
    reply.status(500);
    return { error: error.message };
  }
});

// Semantic search API - for SeleneChat
server.post<{
  Body: {
    query: string;
    limit?: number;
    noteType?: string;
    actionability?: string;
  };
}>('/api/search', async (request, reply) => {
  const { query, limit = 10, noteType, actionability } = request.body || {};

  if (!query || typeof query !== 'string') {
    reply.status(400);
    return { error: 'query is required and must be a string' };
  }

  try {
    const results = await searchNotes(query, { limit, noteType, actionability });
    return { query, count: results.length, results };
  } catch (err) {
    const error = err as Error;
    logger.error({ err: error, query }, 'Semantic search failed');
    reply.status(500);
    return { error: error.message };
  }
});

// Notes API routes
notesRoutes(server);

// Threads API routes
threadsRoutes(server);

// Sessions API routes
sessionsRoutes(server);

// Memories API routes
memoriesRoutes(server);

// LLM proxy routes
llmRoutes(server);

// Briefing routes
briefingRoutes(server);

// Start server
async function start() {
  try {
    await server.listen({ port: config.port, host: config.host });
    logger.info({ port: config.port, host: config.host }, 'Selene webhook server started');
  } catch (err) {
    logger.error({ err }, 'Server failed to start');
    process.exit(1);
  }
}

start();
