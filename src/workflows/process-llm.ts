import {
  createWorkflowLogger,
  getPendingNotes,
  markProcessed,
  generate,
  isAvailable,
  db,
} from '../lib';
import type { WorkflowResult } from '../types';

const log = createWorkflowLogger('process-llm');

const EXTRACT_PROMPT = `Analyze this note and extract key information.

Note Title: {title}
Note Content: {content}

Respond in JSON format:
{
  "concepts": ["concept1", "concept2", "concept3"],
  "primary_theme": "main theme or category",
  "secondary_themes": ["related theme 1", "related theme 2"],
  "overall_sentiment": "positive|negative|neutral|mixed",
  "emotional_tone": "reflective|anxious|excited|frustrated|calm|curious|etc",
  "energy_level": "high|medium|low"
}

JSON response:`;

const ESSENCE_PROMPT = `Distill this note into 1-2 sentences capturing what it means to the person who wrote it. Focus on the core insight, decision, or question — not a summary of the text.

Title: {title}
Content: {content}
{context}

Respond with ONLY the 1-2 sentence distillation, no quotes or explanation:`;

export function buildEssencePrompt(
  title: string,
  content: string,
  concepts: string | null,
  primaryTheme: string | null
): string {
  const contextParts: string[] = [];
  if (concepts) {
    try {
      const conceptList = JSON.parse(concepts);
      if (conceptList.length > 0) {
        contextParts.push(`Key concepts: ${conceptList.join(', ')}`);
      }
    } catch { /* ignore */ }
  }
  if (primaryTheme) {
    contextParts.push(`Theme: ${primaryTheme}`);
  }
  const contextStr = contextParts.length > 0
    ? contextParts.join('\n')
    : '';

  return ESSENCE_PROMPT
    .replace('{title}', title)
    .replace('{content}', content)
    .replace('{context}', contextStr);
}

export async function processLlm(limit = 10): Promise<WorkflowResult> {
  log.info({ limit }, 'Starting LLM processing run');

  // Check Ollama availability
  if (!(await isAvailable())) {
    log.error('Ollama is not available');
    return { processed: 0, errors: 0, details: [] };
  }

  const notes = getPendingNotes(limit);
  log.info({ noteCount: notes.length }, 'Found pending notes');

  const result: WorkflowResult = {
    processed: 0,
    errors: 0,
    details: [],
  };

  for (const note of notes) {
    try {
      log.info({ noteId: note.id, title: note.title }, 'Processing note');

      const prompt = EXTRACT_PROMPT.replace('{title}', note.title).replace(
        '{content}',
        note.content
      );

      const response = await generate(prompt);

      // Try to parse JSON response
      let extracted;
      try {
        // Find JSON in response (Ollama sometimes adds extra text)
        const jsonMatch = response.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          extracted = JSON.parse(jsonMatch[0]);
        } else {
          throw new Error('No JSON found in response');
        }
      } catch (parseErr) {
        log.warn({ noteId: note.id, response }, 'Failed to parse LLM response as JSON');
        extracted = {
          concepts: [],
          primary_theme: null,
          secondary_themes: [],
          overall_sentiment: 'neutral',
          emotional_tone: null,
          energy_level: 'medium',
        };
      }

      // Store in processed_notes table
      db.prepare(
        `INSERT OR REPLACE INTO processed_notes
         (raw_note_id, concepts, primary_theme, secondary_themes, overall_sentiment, emotional_tone, energy_level, processed_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
      ).run(
        note.id,
        JSON.stringify(extracted.concepts || []),
        extracted.primary_theme || null,
        JSON.stringify(extracted.secondary_themes || []),
        extracted.overall_sentiment || 'neutral',
        extracted.emotional_tone || null,
        extracted.energy_level || 'medium',
        new Date().toISOString()
      );

      // Mark note as processed
      markProcessed(note.id);

      // Compute essence inline
      try {
        const essencePrompt = buildEssencePrompt(
          note.title,
          note.content,
          JSON.stringify(extracted.concepts || []),
          extracted.primary_theme || null
        );
        const essenceResponse = await generate(essencePrompt);
        const essence = essenceResponse.trim();
        if (essence && essence.length > 10) {
          db.prepare(
            `UPDATE processed_notes SET essence = ?, essence_at = ? WHERE raw_note_id = ?`
          ).run(essence, new Date().toISOString(), note.id);
          log.info({ noteId: note.id, essenceLength: essence.length }, 'Essence computed');
        }
      } catch (essenceErr) {
        // Non-fatal — distill-essences workflow will retry
        log.warn({ noteId: note.id, err: essenceErr as Error }, 'Essence computation failed, will retry later');
      }

      log.info({ noteId: note.id, concepts: extracted.concepts, theme: extracted.primary_theme }, 'Note processed successfully');
      result.processed++;
      result.details.push({ id: note.id, success: true });
    } catch (err) {
      const error = err as Error;
      log.error({ noteId: note.id, err: error }, 'Failed to process note');
      result.errors++;
      result.details.push({ id: note.id, success: false, error: error.message });
    }
  }

  log.info({ processed: result.processed, errors: result.errors }, 'LLM processing run complete');
  return result;
}

// CLI entry point
if (require.main === module) {
  processLlm()
    .then((result) => {
      console.log('Process-LLM complete:', result);
      process.exit(result.errors > 0 ? 1 : 0);
    })
    .catch((err) => {
      console.error('Process-LLM failed:', err);
      process.exit(1);
    });
}
