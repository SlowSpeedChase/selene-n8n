import { join } from 'path';
import { homedir } from 'os';

const projectRoot = join(__dirname, '../..');

export const config = {
  // Paths - same as current setup
  dbPath: process.env.SELENE_DB_PATH || join(homedir(), 'selene-data/selene.db'),
  logsPath: process.env.SELENE_LOGS_PATH || join(projectRoot, 'logs'),
  projectRoot,

  // Ollama - same config as n8n
  ollamaUrl: process.env.OLLAMA_BASE_URL || 'http://localhost:11434',
  ollamaModel: process.env.OLLAMA_MODEL || 'mistral:7b',
  embeddingModel: process.env.OLLAMA_EMBED_MODEL || 'nomic-embed-text',

  // Server
  port: parseInt(process.env.PORT || '5678', 10),
  host: process.env.HOST || '0.0.0.0',

  // Things bridge - unchanged
  thingsPendingDir: join(projectRoot, 'scripts/things-bridge/pending'),

  // iMessage digest
  imessageDigestTo: process.env.IMESSAGE_DIGEST_TO || '',
  imessageDigestEnabled: process.env.IMESSAGE_DIGEST_ENABLED !== 'false',
  digestsPath: join(projectRoot, 'data', 'digests'),
};
