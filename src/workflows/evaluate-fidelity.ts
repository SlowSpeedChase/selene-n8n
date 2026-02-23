import { createWorkflowLogger, db } from '../lib';
import type { WorkflowResult } from '../types';

const log = createWorkflowLogger('evaluate-fidelity');

interface TierInput {
  ageDays: number;
  hasEssence: boolean;
  threadStatus: string | null;
  lastAccessDays: number;
}

/**
 * Pure function: compute the fidelity tier for a note based on age and activity.
 *
 * Rules:
 *   FULL:     age < 7 days
 *   HIGH:     age < 90 days OR in active thread (requires essence)
 *   SUMMARY:  age >= 90 days AND thread inactive/archived (requires essence)
 *   SKELETON: thread archived AND no access in 180 days (requires essence)
 *
 * Guard: cannot demote below 'full' without an essence.
 */
export function computeTier(input: TierInput): string {
  const { ageDays, hasEssence, threadStatus, lastAccessDays } = input;

  // Fresh notes are always full
  if (ageDays < 7) return 'full';

  // Guard: no demotion without essence
  if (!hasEssence) return 'full';

  // Active thread keeps notes at high regardless of age
  if (threadStatus === 'active') return 'high';

  // Warm period
  if (ageDays < 90) return 'high';

  // Cold: archived + untouched 180+ days
  if (threadStatus === 'archived' && lastAccessDays >= 180) return 'skeleton';

  // Cool: 90+ days, inactive/archived
  return 'summary';
}

interface NoteForEvaluation {
  raw_note_id: number;
  fidelity_tier: string;
  essence: string | null;
  age_days: number;
  thread_status: string | null;
}

export async function evaluateFidelity(): Promise<WorkflowResult> {
  log.info('Starting fidelity evaluation');

  const notes = db
    .prepare(
      `SELECT
         pn.raw_note_id,
         pn.fidelity_tier,
         pn.essence,
         CAST(julianday('now') - julianday(rn.created_at) AS INTEGER) as age_days,
         t.status as thread_status
       FROM processed_notes pn
       JOIN raw_notes rn ON pn.raw_note_id = rn.id
       LEFT JOIN thread_notes tn ON rn.id = tn.raw_note_id
       LEFT JOIN threads t ON tn.thread_id = t.id
       WHERE pn.fidelity_tier != 'skeleton'
         AND rn.test_run IS NULL
       GROUP BY pn.raw_note_id`
    )
    .all() as NoteForEvaluation[];

  log.info({ noteCount: notes.length }, 'Notes to evaluate');

  const result: WorkflowResult = {
    processed: 0,
    errors: 0,
    details: [],
  };

  const now = new Date().toISOString();
  const updateStmt = db.prepare(
    `UPDATE processed_notes SET fidelity_tier = ?, fidelity_evaluated_at = ? WHERE raw_note_id = ?`
  );

  for (const note of notes) {
    const newTier = computeTier({
      ageDays: note.age_days,
      hasEssence: note.essence !== null,
      threadStatus: note.thread_status,
      lastAccessDays: note.age_days,
    });

    if (newTier !== note.fidelity_tier) {
      updateStmt.run(newTier, now, note.raw_note_id);
      log.info(
        { noteId: note.raw_note_id, from: note.fidelity_tier, to: newTier },
        'Tier changed'
      );
      result.processed++;
      result.details.push({ id: note.raw_note_id, success: true });
    }
  }

  log.info(
    { evaluated: notes.length, changed: result.processed },
    'Fidelity evaluation complete'
  );
  return result;
}

// CLI entry point
if (require.main === module) {
  evaluateFidelity()
    .then((result) => {
      console.log('Evaluate-fidelity complete:', result);
      process.exit(0);
    })
    .catch((err) => {
      console.error('Evaluate-fidelity failed:', err);
      process.exit(1);
    });
}
