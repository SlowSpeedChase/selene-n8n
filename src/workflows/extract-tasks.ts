import { writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import { createWorkflowLogger, db, generate, isAvailable, config } from '../lib';
import type { WorkflowResult } from '../types';

const log = createWorkflowLogger('extract-tasks');

const CLASSIFY_PROMPT = `Classify this note into one of three categories:
- actionable: Contains specific tasks that can be done
- needs_planning: Has ideas that need breakdown before acting
- archive_only: Reference material, no action needed

Note: {content}

Respond with just one word: actionable, needs_planning, or archive_only`;

const EXTRACT_TASKS_PROMPT = `Extract actionable tasks from this note.

Note: {content}

For each task, provide:
- title: Short task title
- notes: Any relevant context

Respond in JSON array format:
[{"title": "Task title", "notes": "Context"}]

JSON response:`;

export async function extractTasks(limit = 10): Promise<WorkflowResult> {
  log.info({ limit }, 'Starting task extraction run');

  if (!(await isAvailable())) {
    log.error('Ollama is not available');
    return { processed: 0, errors: 0, details: [] };
  }

  // Get processed notes that haven't been classified yet
  const notes = db
    .prepare(
      `SELECT rn.id, rn.title, rn.content, pn.actionable
       FROM raw_notes rn
       JOIN processed_notes pn ON rn.id = pn.note_id
       WHERE rn.status = 'processed'
       AND pn.task_classification IS NULL
       LIMIT ?`
    )
    .all(limit) as Array<{ id: number; title: string; content: string; actionable: number }>;

  log.info({ noteCount: notes.length }, 'Found notes needing classification');

  const result: WorkflowResult = { processed: 0, errors: 0, details: [] };

  // Ensure Things pending directory exists
  if (!existsSync(config.thingsPendingDir)) {
    mkdirSync(config.thingsPendingDir, { recursive: true });
  }

  for (const note of notes) {
    try {
      log.info({ noteId: note.id, title: note.title }, 'Classifying note');

      // Classify the note
      const classifyPrompt = CLASSIFY_PROMPT.replace('{content}', note.content);
      const classification = (await generate(classifyPrompt)).trim().toLowerCase();

      const validClassifications = ['actionable', 'needs_planning', 'archive_only'];
      const finalClassification = validClassifications.includes(classification)
        ? classification
        : 'archive_only';

      log.info({ noteId: note.id, classification: finalClassification }, 'Note classified');

      // Update classification in database
      db.prepare('UPDATE processed_notes SET task_classification = ? WHERE note_id = ?').run(
        finalClassification,
        note.id
      );

      // If actionable, extract tasks and write to Things bridge
      if (finalClassification === 'actionable') {
        const extractPrompt = EXTRACT_TASKS_PROMPT.replace('{content}', note.content);
        const tasksResponse = await generate(extractPrompt);

        let tasks = [];
        try {
          const jsonMatch = tasksResponse.match(/\[[\s\S]*\]/);
          if (jsonMatch) {
            tasks = JSON.parse(jsonMatch[0]);
          }
        } catch {
          log.warn({ noteId: note.id }, 'Failed to parse tasks JSON');
          tasks = [{ title: note.title, notes: note.content }];
        }

        // Write tasks to Things bridge directory
        for (const task of tasks) {
          const taskFile = join(
            config.thingsPendingDir,
            `task-${note.id}-${Date.now()}.json`
          );
          writeFileSync(taskFile, JSON.stringify(task, null, 2));
          log.info({ noteId: note.id, taskFile }, 'Task written to Things bridge');
        }
      }

      result.processed++;
      result.details.push({ id: note.id, success: true });
    } catch (err) {
      const error = err as Error;
      log.error({ noteId: note.id, err: error }, 'Failed to classify note');
      result.errors++;
      result.details.push({ id: note.id, success: false, error: error.message });
    }
  }

  log.info(result, 'Task extraction run complete');
  return result;
}

// CLI entry point
if (require.main === module) {
  extractTasks()
    .then((result) => {
      console.log('Extract-tasks complete:', result);
      process.exit(result.errors > 0 ? 1 : 0);
    })
    .catch((err) => {
      console.error('Extract-tasks failed:', err);
      process.exit(1);
    });
}
