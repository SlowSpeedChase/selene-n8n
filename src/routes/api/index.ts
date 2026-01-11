import { FastifyInstance } from 'fastify';
import { notesRoutes } from './notes';
import { sessionsRoutes } from './sessions';
import { threadsRoutes } from './threads';
import { appRoutes } from './app';

export async function apiRoutes(server: FastifyInstance) {
  await server.register(notesRoutes);
  await server.register(sessionsRoutes);
  await server.register(threadsRoutes);
  await server.register(appRoutes);
}
