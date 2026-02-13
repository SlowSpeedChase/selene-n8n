# Morning Briefing Redesign

**Date:** 2026-02-13
**Status:** Vision
**Author:** Chase + Claude
**Supersedes:** Morning briefing portion of `2026-02-05-selene-thinking-partner-design.md`

---

## Problem

The current morning briefing is largely useless:

1. **Too vague** — generates a generic LLM paragraph that doesn't point to specific notes
2. **Self-contained dead end** — no way to continue the conversation about anything it surfaces
3. **Generic actions** — "Yes, let's dig in" sends "Let's dig into [ThreadName]" with zero context loaded, so the AI has nothing to work with
4. **Meaningless numbers** — momentum scores and note counts displayed without explaining why they matter
5. **Wastes rich data** — the system has specific note content, concepts, energy levels, semantic associations, tasks, and conversation memory, but the briefing throws it all away for a vague paragraph

---

## Solution: Hybrid Data Cards + LLM Connections

Replace the single LLM-generated paragraph with structured, data-driven cards that point to specific notes and threads, with progressive disclosure and context-aware chat.

### Architecture

Three parallel data tracks, each with a different source:

| Section | Source | LLM Required? |
|---------|--------|---------------|
| **What Changed** | Pure DB queries | No |
| **Needs Attention** | Pure DB queries | No |
| **Connections** | Embeddings + LLM | Yes (for explanation) |
| **Intro sentence** | LLM (fed structured data) | Yes |

**Why hybrid?** The current briefing proves that asking the LLM to do everything produces vague output. "What Changed" and "Needs Attention" are factual — they come straight from the database. "Connections" is where LLM reasoning adds value: explaining *why* two notes from different threads relate.

---

## ADHD Value

| Feature | Cognitive Benefit |
|---------|-------------------|
| Specific note titles (not summaries) | Concrete anchors reduce "where was I?" confusion |
| Expandable cards | Low friction to see more, no overwhelm on load |
| "Discuss this" with deep context | Eliminates "explain what I was thinking" preamble |
| Needs Attention section | Externalizes tracking of stalled work |
| Connections section | Surfaces links you'd never notice across threads |
| No generic buttons | Every action leads somewhere specific |

---

## Data Sources

### What Changed

Query: Notes created since last app open (or last 24h, whichever is shorter).

```
Group by thread:
  "Thread X: 2 new notes — 'Note Title A', 'Note Title B'"

Each note shows:
  - Title
  - Date
  - Primary theme
  - Energy level emoji (high/medium/low)

Notes not assigned to any thread shown separately.
```

Database: `raw_notes` + `processed_notes` + `thread_notes` + `threads`

### Needs Attention

Query: Active threads matching any of these conditions:

- No new notes in 5+ days
- Has open tasks (from Things integration)
- Momentum score dropped significantly since last briefing

```
Each item shows:
  - Thread name
  - Why it needs attention ("no activity in 6 days", "3 open tasks")
  - Note count
```

Database: `threads` + `thread_tasks` + stored last-briefing momentum snapshot

### Connections

Query: `note_associations` for high-similarity pairs (>0.7) where notes belong to *different* threads. Filter to pairs involving at least one note from the last 7 days.

Pass top 3 pairs to LLM: "Here are two notes from different threads. Explain in one sentence what connects them."

```
Each card shows:
  - Two note titles
  - Their thread names
  - LLM-generated connection sentence
```

Database: `note_associations` + `raw_notes` + `threads`

### LLM Intro

Fed a structured summary after data is ready: "3 new notes yesterday across 2 threads. 1 thread needs attention. 2 connections found."

Generates 1-2 sentences. Conversational, grounding. Not a summary — an orientation.

---

## Card Interaction

### Collapsed State (on load)

Each card is a single row — enough to decide if you care:

- **What Changed**: `"Planning Deep Work Blocks"` · Thread: Focus Systems · yesterday · high energy
- **Needs Attention**: `Focus Systems` · no new notes in 6 days · 3 open tasks
- **Connections**: `"Planning Deep Work Blocks"` <> `"Morning Routine Experiment"` · "Both explore structuring time around energy levels"

### Expanded State (tap to expand inline)

- **What Changed**: First ~200 chars of note content, extracted concepts as tags, thread summary
- **Needs Attention**: Thread summary, its "why" motivation, last 2-3 note titles, open task titles
- **Connections**: ~200 char previews of both notes side by side, shared concepts, LLM connection explanation

### Action: "Discuss this with Selene"

One button per expanded card. Opens a chat session with deep context pre-loaded. No generic buttons anywhere.

---

## Deep Context Chat

When the user taps "Discuss this with Selene," the system assembles context before opening the chat:

| Context Layer | What Changed | Needs Attention | Connections |
|---|---|---|---|
| Specific note(s) full content | The note | Last 3 notes in thread | Both notes |
| Parent thread summary + why | Yes | Yes | Both threads |
| Related notes via embeddings | Top 3 similar | Top 3 similar to thread | Top 3 for each note |
| Open tasks for thread | Yes | Yes | Both threads |
| Conversation memory about topic | Yes | Yes | Yes |
| Thread history (recent changes) | No | Yes (shows what stalled) | No |

### System Prompt

```
You are Selene, a thinking partner. The user wants to discuss
something from their morning briefing.

Here is the specific context:
[assembled context from table above]

You already know this material. Don't summarize it back.
Start by asking a specific question or making a specific
observation that helps the user think deeper about this topic.
```

### Selene's Opening Message

Not generic. Informed by the loaded context. Example:

> "Your note 'Planning Deep Work Blocks' talks about blocking mornings for creative work, but your last 3 notes in Focus Systems were about evening routines. What shifted your thinking toward mornings?"

---

## What Changes

### New Components

- `BriefingCardView` — reusable expandable card with collapsed/expanded states
- `BriefingSection` — groups cards under section headers
- `BriefingContextBuilder` — assembles deep context for "Discuss this" chats from multiple DB queries

### Replaced

- `BriefingGenerator.buildBriefingPrompt()` — one big LLM prompt for whole briefing. Replaced by data queries + small LLM call for intro and connection explanations
- `BriefingViewModel.digIn()` / `showSomethingElse()` — generic string returns. Replaced by context-aware chat initialization
- The three generic buttons ("Yes, let's dig in" / "Show me something else" / "Skip")
- `ThinkingPartnerContextBuilder.buildBriefingContext()` — replaced by card-type-aware `BriefingContextBuilder`

### Stays

- `BriefingView` as container (rewritten internals)
- `BriefingViewModel` as coordinator (rewritten internals)
- `BriefingState` model (extended with structured card data)
- ContentView integration point (briefing on app open)
- OllamaService for LLM calls

### New DB Queries

- Notes since last app open (with thread grouping)
- Stalled threads (no activity in N days)
- Cross-thread high-similarity pairs from `note_associations`
- Momentum snapshot comparison (requires storing last-briefing values)

---

## Edge Cases

- **Ollama down**: "What Changed" and "Needs Attention" still work (pure DB). "Connections" falls back to showing note pairs with shared concepts listed. Intro uses template: "3 new notes since yesterday."
- **First launch / no data**: Welcome state instead of empty briefing
- **"Last app open" tracking**: Store timestamp in UserDefaults each time briefing loads
- **All sections empty**: "Nothing new since last time. Want to start writing?"

---

## Acceptance Criteria

- [ ] Briefing shows specific note titles grouped by thread, not vague LLM prose
- [ ] Each card expands inline to show note/thread content preview
- [ ] "Discuss this" opens a chat with deep context pre-loaded (note content, thread, related notes, tasks, memory)
- [ ] Selene's opening message in discuss-chat is specific to the loaded context, not generic
- [ ] "What Changed" and "Needs Attention" load without LLM (pure DB)
- [ ] "Connections" shows cross-thread note pairs with LLM-generated explanation
- [ ] Briefing degrades gracefully when Ollama is unavailable
- [ ] No generic buttons ("dig in", "show me something else") remain
- [ ] Empty states handled for each section independently

## ADHD Check

- [x] Reduces friction? — Yes. One tap to expand, one tap to discuss with full context loaded
- [x] Makes information visible? — Yes. Specific note titles, thread names, concrete reasons for attention
- [x] Externalizes cognition? — Yes. Stalled thread tracking and cross-thread connections you'd never notice
- [x] Avoids overwhelm? — Yes. Progressive disclosure, sections hidden when empty

## Scope Check

- [ ] Achievable in < 1 week of focused work? — Yes. Most data queries already exist. Main work is new card views, context builder, and rewiring the briefing flow.
