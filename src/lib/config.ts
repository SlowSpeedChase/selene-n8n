import { join } from 'path';
import { homedir } from 'os';
import { config as loadEnv } from 'dotenv';

// Load environment variables from .env file
loadEnv();

// Load .env.development if it exists - override: true so test settings take precedence
loadEnv({ path: join(__dirname, '../..', '.env.development'), override: true });

const projectRoot = join(__dirname, '../..');

// Environment: 'test' or 'production' (default)
const isTestEnv = process.env.SELENE_ENV === 'test';

// Path resolution based on environment
function getDbPath(): string {
  // Explicit env var always wins
  if (process.env.SELENE_DB_PATH) {
    return process.env.SELENE_DB_PATH;
  }
  // Test environment uses project-local test database
  if (isTestEnv) {
    return join(projectRoot, 'data-test/selene.db');
  }
  // Production default
  return join(homedir(), 'selene-data/selene.db');
}

function getVectorsPath(): string {
  if (process.env.SELENE_VECTORS_PATH) {
    return process.env.SELENE_VECTORS_PATH;
  }
  if (isTestEnv) {
    return join(projectRoot, 'data-test/vectors.lance');
  }
  return join(homedir(), 'selene-data/vectors.lance');
}

function getVaultPath(): string {
  if (process.env.SELENE_VAULT_PATH) {
    return process.env.SELENE_VAULT_PATH;
  }
  if (isTestEnv) {
    return join(projectRoot, 'data-test/vault');
  }
  return join(projectRoot, 'vault');
}

function getDigestsPath(): string {
  if (process.env.SELENE_DIGESTS_PATH) {
    return process.env.SELENE_DIGESTS_PATH;
  }
  if (isTestEnv) {
    return join(projectRoot, 'data-test/digests');
  }
  return join(projectRoot, 'data', 'digests');
}

export const config = {
  // Environment
  env: isTestEnv ? 'test' : 'production',
  isTestEnv,

  // Paths - environment-aware
  dbPath: getDbPath(),
  vectorsPath: getVectorsPath(),
  vaultPath: getVaultPath(),
  digestsPath: getDigestsPath(),
  logsPath: process.env.SELENE_LOGS_PATH || join(projectRoot, 'logs'),
  projectRoot,

  // Ollama - same config as before
  ollamaUrl: process.env.OLLAMA_BASE_URL || 'http://localhost:11434',
  ollamaModel: process.env.OLLAMA_MODEL || 'mistral:7b',
  embeddingModel: process.env.OLLAMA_EMBED_MODEL || 'nomic-embed-text',

  // Server
  port: parseInt(process.env.PORT || '5678', 10),
  host: process.env.HOST || '0.0.0.0',

  // Things bridge - unchanged
  thingsPendingDir: join(projectRoot, 'scripts/things-bridge/pending'),

  // iMessage digest - disabled in test mode
  imessageDigestTo: process.env.IMESSAGE_DIGEST_TO || '',
  imessageDigestEnabled: !isTestEnv && process.env.IMESSAGE_DIGEST_ENABLED !== 'false',
};
