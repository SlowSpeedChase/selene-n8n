import { writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import { createWorkflowLogger, db, config } from '../lib';
import type { ExportableNote, ExportResult } from '../types';

const log = createWorkflowLogger('export-obsidian');

// Emoji mappings
const ENERGY_EMOJI: Record<string, string> = {
  high: '⚡',
  medium: '🔋',
  low: '🪫',
};

const EMOTION_EMOJI: Record<string, string> = {
  excited: '🚀',
  calm: '😌',
  anxious: '😰',
  frustrated: '😤',
  content: '😊',
  overwhelmed: '🤯',
  motivated: '💪',
  focused: '🎯',
  reflective: '🤔',
  curious: '🧐',
};

const SENTIMENT_EMOJI: Record<string, string> = {
  positive: '✅',
  negative: '⚠️',
  neutral: '⚪',
  mixed: '🔀',
};

// Helper: Safely parse JSON fields
function parseJson<T>(field: string | null, defaultValue: T): T {
  if (!field) return defaultValue;
  try {
    return JSON.parse(field) as T;
  } catch {
    return defaultValue;
  }
}

// Helper: Create URL-friendly slug
function createSlug(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .slice(0, 50);
}

// Helper: Extract action items from content
function extractActionItems(content: string): string[] {
  const items: string[] = [];

  // Pattern 1: Checkbox format
  const checkboxes = content.match(/^[-*]\s*\[[ x]\]\s*(.+)$/gim) || [];
  checkboxes.forEach((match) => {
    const item = match.replace(/^[-*]\s*\[[ x]\]\s*/i, '').trim();
    if (item) items.push(item);
  });

  // Pattern 2: TODO/TASK/ACTION format
  const todos = content.match(/^[-*]\s*(?:TODO|TASK|ACTION)[:)]\s*(.+)$/gim) || [];
  todos.forEach((match) => {
    const item = match.replace(/^[-*]\s*(?:TODO|TASK|ACTION)[:)]\s*/i, '').trim();
    if (item) items.push(item);
  });

  // Pattern 3: "need to", "should", etc.
  const intentions = content.match(/\b(?:need to|should|must|have to|remember to)\s+([^.!?]+)/gi) || [];
  intentions.forEach((match) => {
    const item = match.replace(/^(?:need to|should|must|have to|remember to)\s+/i, '').trim();
    if (item) items.push(item);
  });

  // Deduplicate and filter
  const unique = [...new Set(items)].filter((item) => item.length > 5 && item.length < 200);
  return unique.slice(0, 10);
}
