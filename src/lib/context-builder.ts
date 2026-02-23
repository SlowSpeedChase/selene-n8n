/**
 * ContextBuilder: Assembles tiered note/thread context within a token budget.
 *
 * Tier rendering rules:
 *   full     -> title + full content
 *   high     -> title + essence + full content
 *   summary  -> title + essence + themes (no content)
 *   skeleton -> title + primary_theme
 *
 * Fallback: if essence is missing, uses concepts -> truncated content (150 chars)
 * Token estimation: character count / 4 (no external tokenizer)
 */

export type FidelityTier = 'full' | 'high' | 'summary' | 'skeleton';

export interface NoteContext {
  id: number;
  title: string;
  content: string;
  essence: string | null;
  primary_theme: string | null;
  concepts: string | null; // JSON array string
  fidelity_tier: FidelityTier;
}

export interface ThreadContext {
  id: number;
  name: string;
  thread_digest: string | null;
  summary: string | null;
  why: string | null;
  note_count: number;
}

const CHARS_PER_TOKEN = 4;
const FALLBACK_CONTENT_LENGTH = 150;

export class ContextBuilder {
  private budgetChars: number;
  private usedChars: number = 0;
  private blocks: string[] = [];

  constructor(budgetTokens: number) {
    this.budgetChars = budgetTokens * CHARS_PER_TOKEN;
  }

  /** Add a note rendered at its fidelity tier. */
  addNote(note: NoteContext): this {
    const block = this.renderNote(note, note.fidelity_tier);
    return this.appendBlock(block);
  }

  /** Add a note always rendered at full fidelity, regardless of tier. */
  addFullText(note: NoteContext): this {
    const block = this.renderNote(note, 'full');
    return this.appendBlock(block);
  }

  /** Add a thread rendered with digest or summary fallback. */
  addThread(thread: ThreadContext): this {
    const block = this.renderThread(thread);
    return this.appendBlock(block);
  }

  /** Get remaining token budget. */
  remainingTokens(): number {
    return Math.floor((this.budgetChars - this.usedChars) / CHARS_PER_TOKEN);
  }

  /** Build the final context string. */
  build(): string {
    return this.blocks.join('\n\n');
  }

  private appendBlock(block: string): this {
    const separatorCost = this.blocks.length > 0 ? 2 : 0; // '\n\n' between blocks
    if (this.usedChars + block.length + separatorCost > this.budgetChars) {
      return this;
    }
    this.blocks.push(block);
    this.usedChars += block.length + separatorCost;
    return this;
  }

  private renderNote(note: NoteContext, tier: FidelityTier): string {
    switch (tier) {
      case 'full':
        return `--- ${note.title} ---\n${note.content}`;

      case 'high':
        return note.essence
          ? `--- ${note.title} ---\n[Essence] ${note.essence}\n${note.content}`
          : `--- ${note.title} ---\n${note.content}`;

      case 'summary':
        if (note.essence) {
          const theme = note.primary_theme ? ` [${note.primary_theme}]` : '';
          return `--- ${note.title}${theme} ---\n${note.essence}`;
        }
        return `--- ${note.title} ---\n${this.getFallbackPreview(note)}`;

      case 'skeleton':
        return `- ${note.title} [${note.primary_theme || 'unthemed'}]`;

      default:
        return `--- ${note.title} ---\n${note.content}`;
    }
  }

  private renderThread(thread: ThreadContext): string {
    const lines: string[] = [`=== Thread: ${thread.name} (${thread.note_count} notes) ===`];

    if (thread.thread_digest) {
      lines.push(thread.thread_digest);
    } else if (thread.summary) {
      lines.push(thread.summary);
      if (thread.why) {
        lines.push(`Motivation: ${thread.why}`);
      }
    }

    return lines.join('\n');
  }

  private getFallbackPreview(note: NoteContext): string {
    if (note.concepts) {
      try {
        const conceptList = JSON.parse(note.concepts) as string[];
        if (conceptList.length > 0) {
          return `Concepts: ${conceptList.slice(0, 5).join(', ')}`;
        }
      } catch {
        // Fall through
      }
    }
    return note.content.slice(0, FALLBACK_CONTENT_LENGTH) + (note.content.length > FALLBACK_CONTENT_LENGTH ? '...' : '');
  }
}
