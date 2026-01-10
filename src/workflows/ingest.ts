import { createHash } from 'crypto';
import { createWorkflowLogger, findByContentHash, insertNote } from '../lib';
import type { IngestInput, IngestResult } from '../types';

const log = createWorkflowLogger('ingest');

export async function ingest(input: IngestInput): Promise<IngestResult> {
  const { title, content, created_at, test_run } = input;

  log.info({ title, test_run }, 'Processing ingest request');

  // Generate content hash for duplicate detection
  const contentHash = createHash('sha256')
    .update(title + content)
    .digest('hex');

  // Check for duplicate
  const existing = findByContentHash(contentHash);

  if (existing) {
    log.info({ title, existingId: existing.id }, 'Duplicate detected');
    return { duplicate: true, existingId: existing.id };
  }

  // Extract tags from content
  const tags = content.match(/#\w+/g) || [];

  // Insert note
  const id = insertNote({
    title,
    content,
    contentHash,
    tags,
    createdAt: created_at || new Date().toISOString(),
    testRun: test_run,
  });

  log.info({ id, title, tags }, 'Note ingested successfully');

  return { id, duplicate: false };
}

// CLI entry point
if (require.main === module) {
  console.log('Ingest workflow - call via server or import as module');
  console.log('Usage: Import { ingest } from this file');
}
