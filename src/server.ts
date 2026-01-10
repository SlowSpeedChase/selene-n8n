import Fastify from 'fastify';
import { config, logger } from './lib';
import { ingest } from './workflows/ingest';
import { exportObsidian } from './workflows/export-obsidian';
import type { IngestInput, WebhookResponse } from './types';

const server = Fastify({
  logger: false, // We use our own logger
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
