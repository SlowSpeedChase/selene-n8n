import { createWorkflowLogger, db } from '../lib';
import type { WorkflowResult } from '../types';

const log = createWorkflowLogger('thread-lifecycle');

// Configuration
const STALE_THRESHOLD_DAYS = 60;

// Types
interface ThreadRecord {
  id: number;
  name: string;
  why: string | null;
  summary: string | null;
  status: string;
  note_count: number;
  last_activity_at: string | null;
}

/**
 * Archive threads that have been inactive for longer than STALE_THRESHOLD_DAYS.
 * Sets status to 'archived' and records the change in thread_history.
 */
function archiveStaleThreads(): number {
  const now = new Date();
  const cutoff = new Date(now.getTime() - STALE_THRESHOLD_DAYS * 24 * 60 * 60 * 1000).toISOString();
  const nowIso = now.toISOString();

  // Find active threads with no activity in the threshold period
  const staleThreads = db
    .prepare(
      `SELECT id, name, why, summary, status, note_count, last_activity_at
       FROM threads
       WHERE status = 'active'
         AND (last_activity_at IS NULL OR last_activity_at < ?)
       ORDER BY last_activity_at ASC`
    )
    .all(cutoff) as ThreadRecord[];

  if (staleThreads.length === 0) {
    log.info({ cutoff, thresholdDays: STALE_THRESHOLD_DAYS }, 'No stale threads found');
    return 0;
  }

  log.info(
    { count: staleThreads.length, cutoff, thresholdDays: STALE_THRESHOLD_DAYS },
    'Found stale threads to archive'
  );

  const updateStmt = db.prepare(
    `UPDATE threads SET status = 'archived', updated_at = ? WHERE id = ?`
  );

  const historyStmt = db.prepare(
    `INSERT INTO thread_history (thread_id, summary_before, summary_after, change_type, created_at)
     VALUES (?, ?, ?, 'archived', ?)`
  );

  let archived = 0;

  for (const thread of staleThreads) {
    updateStmt.run(nowIso, thread.id);
    historyStmt.run(thread.id, thread.summary, thread.summary, nowIso);
    archived++;

    log.info(
      {
        threadId: thread.id,
        name: thread.name,
        lastActivity: thread.last_activity_at,
        noteCount: thread.note_count,
      },
      'Archived stale thread'
    );
  }

  log.info({ archived }, 'Stale thread archival complete');
  return archived;
}

/**
 * Main workflow: thread lifecycle management
 *
 * Phase 1: Archive stale threads (inactive > 60 days)
 * Phase 2: Split divergent threads (TODO)
 * Phase 3: Merge convergent threads (TODO)
 */
export async function threadLifecycle(): Promise<WorkflowResult> {
  log.info('Starting thread lifecycle');

  const result: WorkflowResult = {
    processed: 0,
    errors: 0,
    details: [],
  };

  // Phase 1: Archive stale threads
  try {
    const archivedCount = archiveStaleThreads();
    result.processed += archivedCount;
    if (archivedCount > 0) {
      result.details.push({ id: 0, success: true, error: `Archived ${archivedCount} stale threads` });
    }
  } catch (err) {
    const error = err as Error;
    log.error({ err: error }, 'Error in archive phase');
    result.errors++;
    result.details.push({ id: 0, success: false, error: error.message });
  }

  // Phase 2: Split divergent threads
  // TODO: Detect threads whose notes have drifted into distinct sub-clusters
  // and split them into separate threads

  // Phase 3: Merge convergent threads
  // TODO: Detect pairs of threads with high semantic overlap
  // and merge them into a single thread

  log.info(
    { processed: result.processed, errors: result.errors },
    'Thread lifecycle complete'
  );

  return result;
}

// CLI entry point
if (require.main === module) {
  threadLifecycle()
    .then((result) => {
      log.info({ result }, 'Thread lifecycle finished');
      process.exit(result.errors > 0 ? 1 : 0);
    })
    .catch((err) => {
      log.error({ err }, 'Thread lifecycle failed');
      process.exit(1);
    });
}
