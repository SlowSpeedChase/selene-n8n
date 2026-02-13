import { FastifyRequest, FastifyReply } from 'fastify';
import { config } from './config';

export async function requireAuth(request: FastifyRequest, reply: FastifyReply) {
  // Skip auth if no token configured (local-only mode)
  if (!config.apiToken) return;

  const header = request.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    reply.status(401).send({ error: 'Missing or invalid Authorization header' });
    return;
  }

  const token = header.slice(7);
  if (token !== config.apiToken) {
    reply.status(403).send({ error: 'Invalid API token' });
    return;
  }
}
