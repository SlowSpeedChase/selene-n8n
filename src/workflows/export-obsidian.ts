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

interface MarkdownData {
  markdown: string;
  dateStr: string;
  year: string;
  month: string;
  concepts: string[];
  theme: string;
  energy: string;
  title: string;
  slug: string;
}

function generateAdhdMarkdown(note: ExportableNote): MarkdownData {
  // Parse JSON fields
  const concepts = parseJson<string[]>(note.concepts, []);
  const secondaryThemes = parseJson<string[]>(note.secondary_themes, []);
  const tags = parseJson<string[]>(note.tags, []);
  const sentimentData = parseJson<{
    adhd_markers?: { overwhelm?: boolean; hyperfocus?: boolean; executive_dysfunction?: boolean };
    key_emotions?: string[];
    stress_indicators?: boolean;
    analysis_confidence?: number;
  }>(note.sentiment_data, {});

  // Extract ADHD markers
  const adhdMarkers = sentimentData.adhd_markers || {};
  const keyEmotions = sentimentData.key_emotions || [];
  const stressIndicators = sentimentData.stress_indicators || false;
  const analysisConfidence = sentimentData.analysis_confidence || 0.5;

  // Parse date
  const createdAt = new Date(note.created_at);
  const dateStr = createdAt.toISOString().split('T')[0];
  const timeStr = createdAt.toTimeString().slice(0, 5);
  const year = createdAt.getFullYear().toString();
  const month = (createdAt.getMonth() + 1).toString().padStart(2, '0');
  const dayOfWeek = createdAt.toLocaleDateString('en-US', { weekday: 'long' });

  // Get emojis
  const energyEmoji = ENERGY_EMOJI[note.energy_level] || '🔋';
  const emotionEmoji = EMOTION_EMOJI[note.emotional_tone] || '💭';
  const sentimentEmoji = SENTIMENT_EMOJI[note.overall_sentiment] || '⚪';

  // ADHD marker badges
  const adhdBadges: string[] = [];
  if (adhdMarkers.overwhelm) adhdBadges.push('🧠 OVERWHELM');
  if (adhdMarkers.hyperfocus) adhdBadges.push('🎯 HYPERFOCUS');
  if (adhdMarkers.executive_dysfunction) adhdBadges.push('⚠️ EXEC-DYS');
  if (stressIndicators) adhdBadges.push('😰 STRESS');
  const adhdBadgeStr = adhdBadges.length > 0 ? adhdBadges.join(' | ') : '✨ BASELINE';

  // Extract action items
  const actionItems = extractActionItems(note.content);

  // Generate TL;DR
  const sentences = note.content.split(/[.!?]\s+/);
  const firstSentences = sentences.slice(0, 2).join('. ');
  const tldr = firstSentences.length > 200 ? firstSentences.slice(0, 200) + '...' : firstSentences;

  // Reading time
  const readingTime = Math.max(1, Math.round(note.word_count / 200));

  // Build all tags
  const allTags = [
    note.primary_theme,
    ...secondaryThemes,
    ...tags,
    `energy-${note.energy_level}`,
    `mood-${note.emotional_tone}`,
    `sentiment-${note.overall_sentiment}`,
  ];
  if (adhdMarkers.overwhelm) allTags.push('adhd/overwhelm');
  if (adhdMarkers.hyperfocus) allTags.push('adhd/hyperfocus');
  if (stressIndicators) allTags.push('state/stressed');
  const uniqueTags = [...new Set(allTags.filter(Boolean))];

  // Escape title for YAML
  const titleEscaped = note.title.replace(/"/g, '\\"');
  const sentimentScore = note.sentiment_score || 0.5;

  // Build frontmatter
  const conceptsYaml = concepts.map((c) => `  - ${c}`).join('\n');
  const tagsYaml = uniqueTags.map((t) => `  - ${t}`).join('\n');

  const frontmatter = `---
title: "${titleEscaped}"
date: ${dateStr}
time: "${timeStr}"
day: ${dayOfWeek}
theme: ${note.primary_theme || 'uncategorized'}
energy: ${note.energy_level}
mood: ${note.emotional_tone || 'neutral'}
sentiment: ${note.overall_sentiment}
sentiment_score: ${sentimentScore}
concepts:
${conceptsYaml || '  - uncategorized'}
tags:
${tagsYaml}
adhd_markers:
  overwhelm: ${adhdMarkers.overwhelm || false}
  hyperfocus: ${adhdMarkers.hyperfocus || false}
  executive_dysfunction: ${adhdMarkers.executive_dysfunction || false}
stress: ${stressIndicators}
action_items: ${actionItems.length}
reading_time: ${readingTime}
word_count: ${note.word_count}
source: Selene
automated: true
---`;

  // Context concepts
  const contextConcepts = concepts.slice(0, 2).join(', ') || 'general notes';

  // Build status header
  const statusHeader = `# ${emotionEmoji} ${note.title}

## 🎯 Status at a Glance

| Indicator | Status | Details |
|-----------|--------|----------|
| Energy | ${energyEmoji} ${note.energy_level.toUpperCase()} | Brain capacity indicator |
| Mood | ${emotionEmoji} ${note.emotional_tone || 'neutral'} | Emotional state |
| Sentiment | ${sentimentEmoji} ${note.overall_sentiment} | Overall tone (${Math.round(sentimentScore * 100)}%) |
| ADHD | ${adhdBadgeStr} | Markers detected |
| Actions | 🎯 ${actionItems.length} items | Tasks extracted |

---`;

  // Build metadata section
  const conceptLinks = concepts.map((c) => `[[Concepts/${c}]]`).join(' • ') || 'none';
  const themeLinks = [note.primary_theme, ...secondaryThemes]
    .filter(Boolean)
    .map((t) => `[[Themes/${t}]]`)
    .join(' • ');

  const contextBox = `> **⚡ Quick Context**
> ${tldr}
>
> **Why this matters:** Related to ${contextConcepts}
> **Reading time:** ${readingTime} min
> **Brain state:** ${note.energy_level} energy, ${note.emotional_tone || 'neutral'}`;

  const metadataSection = `
**🏷️ Theme**: ${themeLinks || 'uncategorized'}
**💡 Concepts**: ${conceptLinks}
**📅 Created**: ${dateStr} (${dayOfWeek}) at ${timeStr}
**⏱️ Reading Time**: ${readingTime} min

---

${contextBox}

---`;

  // Build action items section
  let actionItemsSection = '';
  if (actionItems.length > 0) {
    const actionItemsList = actionItems.map((item) => `- [ ] ${item}`).join('\n');
    actionItemsSection = `
## ✅ Action Items Detected

${actionItemsList}

> **Tip:** Copy these to your daily todo list or use Obsidian Tasks plugin

---`;
  }

  // Content section
  const contentSection = `
## 📝 Full Content

${note.content}

---`;

  // Energy interpretation
  const energyInterpretation: Record<string, string> = {
    high: '⚡ Great time for complex tasks',
    low: '🪫 Consider rest or easy tasks',
    medium: '🔋 Moderate capacity available',
  };

  // Emotional insights
  const emotionalInsights: string[] = [];
  if (adhdMarkers.overwhelm) emotionalInsights.push('⚠️ Signs of overwhelm detected - consider breaking tasks down');
  if (adhdMarkers.hyperfocus) emotionalInsights.push('🎯 Hyperfocus detected - valuable insights likely!');
  if (stressIndicators) emotionalInsights.push('😰 Stress indicators present - be gentle with yourself');
  const emotionalInsightsStr = emotionalInsights.length > 0 ? '\n  - ' + emotionalInsights.join('\n  - ') : '';

  // Key emotions section
  let keyEmotionsSection = '';
  if (keyEmotions.length > 0) {
    keyEmotionsSection = `
### Key Emotions
${keyEmotions.map((e) => `- ${e}`).join('\n')}`;
  }

  const insightsSection = `
## 🧠 ADHD Insights

### Brain State Analysis

- **Energy Level**: ${note.energy_level} ${energyEmoji}
  - ${energyInterpretation[note.energy_level] || ''}

- **Emotional Tone**: ${note.emotional_tone || 'neutral'} ${emotionEmoji}${emotionalInsightsStr}

- **Sentiment**: ${note.overall_sentiment} (${Math.round(sentimentScore * 100)}%)
${keyEmotionsSection}

### Context Clues

- **When was this?** ${dayOfWeek}, ${dateStr} at ${timeStr}
- **What was I thinking about?** ${concepts.slice(0, 3).join(', ') || 'various topics'}
- **Theme**: ${note.primary_theme || 'uncategorized'}
- **How did I feel?** ${note.emotional_tone || 'neutral'}, ${note.overall_sentiment}

> **Memory Trigger**: Look for related notes tagged with these concepts to restore full context

---`;

  // Metadata footer
  const metadataFooter = `
## 📊 Processing Metadata

- **Processed**: ${new Date().toISOString().split('T')[0]}
- **Source**: Selene Knowledge Management System
- **Concept Count**: ${concepts.length}
- **Word Count**: ${note.word_count}
- **Sentiment Confidence**: ${Math.round(analysisConfidence * 100)}%

## 🔗 Related Notes

*Obsidian will automatically show backlinks here based on shared concepts and tags*

---

*🤖 This note was automatically processed and optimized for ADHD by Selene*
`;

  // Combine all sections
  const markdown = `${frontmatter}

${statusHeader}

${metadataSection}
${actionItemsSection}
${contentSection}
${insightsSection}
${metadataFooter}`;

  return {
    markdown,
    dateStr,
    year,
    month,
    concepts,
    theme: note.primary_theme || 'uncategorized',
    energy: note.energy_level,
    title: note.title,
    slug: createSlug(note.title),
  };
}

function writeNoteToVault(note: ExportableNote, markdownData: MarkdownData, vaultPath: string): string {
  const filename = `${markdownData.dateStr}-${markdownData.slug}.md`;

  // Define all 4 paths
  const paths = {
    timeline: join(vaultPath, 'Selene', 'Timeline', markdownData.year, markdownData.month, filename),
    concept: join(
      vaultPath,
      'Selene',
      'By-Concept',
      markdownData.concepts[0] || 'uncategorized',
      filename
    ),
    theme: join(vaultPath, 'Selene', 'By-Theme', markdownData.theme, filename),
    energy: join(vaultPath, 'Selene', 'By-Energy', markdownData.energy, filename),
  };

  // Create directories and write files
  for (const [pathType, filePath] of Object.entries(paths)) {
    const dir = filePath.substring(0, filePath.lastIndexOf('/'));
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    writeFileSync(filePath, markdownData.markdown, 'utf-8');
    log.debug({ pathType, filePath }, 'Wrote note to vault');
  }

  // Create concept hub pages
  const conceptsDir = join(vaultPath, 'Selene', 'Concepts');
  if (!existsSync(conceptsDir)) {
    mkdirSync(conceptsDir, { recursive: true });
  }

  for (const concept of markdownData.concepts) {
    const conceptFile = join(conceptsDir, `${concept}.md`);
    if (!existsSync(conceptFile)) {
      const conceptContent = `# ${concept}

**Type**: Concept Index
**Created**: ${new Date().toISOString().split('T')[0]}
**Auto-generated**: Yes

## 🎯 What is this?

This is a hub page for all notes related to **${concept}**. Obsidian will automatically show backlinks below.

## 📚 Related Notes

*Backlinks will appear here automatically*

## 🧠 ADHD Tips

- Use this page to see all notes about ${concept} in one place
- Great for refreshing your memory before diving into a specific note
- Check the backlinks section to find related context

---

*Auto-generated by Selene - edit freely!*
`;
      writeFileSync(conceptFile, conceptContent, 'utf-8');
      log.info({ concept, conceptFile }, 'Created concept hub page');
    }
  }

  return filename;
}
