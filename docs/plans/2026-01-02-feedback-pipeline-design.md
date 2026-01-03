# Feedback Pipeline Design

**Status:** Ready for Implementation
**Created:** 2026-01-02
**Phase:** Infrastructure

---

## Problem

Selene development feedback captured via Drafts (`#selene-feedback` tag) currently stores to `feedback_notes` table but doesn't get transformed into actionable backlog items. The feedback sits unused instead of becoming user stories, feature requests, or bug reports.

---

## Solution

Extend Workflow 01 (Ingestion) to classify feedback using Ollama and append structured items to `docs/backlog/user-stories.md`.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ EXISTING FLOW (Workflow 01)                                     │
│                                                                 │
│ Drafts → Webhook → Parse → Check Feedback Tag                   │
│                              ↓                                  │
│                    ┌─────────┴─────────┐                       │
│                    │ Is Feedback?      │                       │
│                    └─────────┬─────────┘                       │
│                        YES ↓      ↓ NO                          │
│              Insert Feedback    [Normal ingestion path]         │
│                    ↓                                            │
│              ⬛ STOP (current)                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ NEW EXTENSION                                                   │
│                                                                 │
│ Insert Feedback Note                                            │
│         ↓                                                       │
│ ┌───────────────────────────────────────────────────────────┐  │
│ │ Ollama: Classify Feedback                                  │  │
│ │ → user_story | feature_request | bug | improvement | noise │  │
│ └───────────────────────────────────────────────────────────┘  │
│         ↓                                                       │
│ ┌───────────────────────────────────────────────────────────┐  │
│ │ Check Duplicate (compare against existing backlog items)   │  │
│ └───────────────────────────────────────────────────────────┘  │
│         ↓                                                       │
│    ┌────┴────┐                                                  │
│  NOISE/DUP   VALID                                             │
│    ↓           ↓                                                │
│  Log only   Append to BACKLOG.md                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Classification Categories

| Category | Description | Example | Action |
|----------|-------------|---------|--------|
| **user_story** | Clear need from user perspective | "I wanted to see where a task came from but couldn't" | Add to User Stories section |
| **feature_request** | Specific capability request | "Add dark mode to SeleneChat" | Add to Feature Requests section |
| **bug** | Something broken or wrong | "Task extraction gave high-energy when I said tired" | Add to Bugs section |
| **improvement** | Enhancement to existing feature | "Make the citation links more visible" | Add to Improvements section |
| **noise** | Not actionable feedback | "Testing the feedback system", "asdf" | Log to `feedback_notes`, skip backlog |

### AI Output Format

```json
{
  "category": "user_story",
  "title": "See task source notes",
  "description": "User wants to trace tasks back to the notes they came from",
  "confidence": 0.85,
  "duplicate_of": null,
  "reasoning": "Contains 'I wanted to' + unmet need"
}
```

### Duplicate Detection

Before appending, compare new `title` against existing backlog titles. If Ollama detects a close match, it sets `duplicate_of` to the existing ID.

---

## Backlog File Format

Location: `docs/backlog/user-stories.md`

```markdown
# Selene Development Backlog

Last updated: 2026-01-02 10:30 UTC

*Auto-generated from #selene-feedback notes. Manual edits to items are preserved.*

---

## User Stories

| ID | Story | Priority | Status | Source Date |
|----|-------|----------|--------|-------------|
| US-001 | See which notes a task originated from | - | Open | 2026-01-02 |
| US-002 | Filter tasks by current energy level | - | Open | 2026-01-02 |

---

## Feature Requests

| ID | Request | Priority | Status | Source Date |
|----|---------|----------|--------|-------------|
| FR-001 | Dark mode for SeleneChat | - | Open | 2026-01-02 |

---

## Bugs

| ID | Issue | Priority | Status | Source Date |
|----|-------|----------|--------|-------------|
| BUG-001 | Task extraction ignores stated energy level | - | Open | 2026-01-02 |

---

## Improvements

| ID | Enhancement | Priority | Status | Source Date |
|----|-------------|----------|--------|-------------|
| IMP-001 | Make citation links more visible | - | Open | 2026-01-02 |

---

## Completed

*Items move here after implementation. Include PR/commit reference.*

| ID | Description | Completed | Reference |
|----|-------------|-----------|-----------|
```

**Priority and Status:** Left blank by automation. User fills in during review sessions.

**ID Generation:** Auto-increment per category (US-001, FR-001, BUG-001, IMP-001).

---

## Workflow Implementation

### New Nodes (after Insert Feedback Note)

```
[Insert Feedback Note]
        ↓
[Build Classification Prompt]
        ↓
[Ollama: Classify Feedback]
        ↓
[Parse Classification]
        ↓
[Read Current Backlog]
        ↓
[Check Duplicate Title]
        ↓
    ┌───┴───┐
  DUP/NOISE  VALID
    ↓          ↓
[Update      [Generate Next ID]
 feedback_       ↓
 notes.      [Append to Backlog]
 status]         ↓
    ↓        [Write Backlog File]
    ↓            ↓
    └────────────┴────────┐
                          ↓
              [Update feedback_notes.status]
                          ↓
                   [Return Response]
```

### Implementation Details

1. **Ollama prompt** includes existing backlog titles for context (helps with duplicate detection and consistent naming)

2. **File I/O**: Read/write `docs/backlog/user-stories.md` using n8n's Read/Write File nodes (file is inside Docker volume at `/selene/docs/backlog/user-stories.md`)

3. **ID tracking**: Parse existing IDs from backlog to determine next number per category

4. **Atomic update**: Read → Parse → Append → Write in single transaction to avoid race conditions

5. **Status tracking**: `feedback_notes` table gets `status` column tracking progression

---

## Database Schema Changes

Migration: `database/migrations/012_feedback_classification.sql`

```sql
-- Add status tracking to feedback_notes
ALTER TABLE feedback_notes ADD COLUMN status TEXT DEFAULT 'pending';
ALTER TABLE feedback_notes ADD COLUMN category TEXT;
ALTER TABLE feedback_notes ADD COLUMN backlog_id TEXT;
ALTER TABLE feedback_notes ADD COLUMN classified_at DATETIME;
ALTER TABLE feedback_notes ADD COLUMN ai_confidence REAL;
ALTER TABLE feedback_notes ADD COLUMN ai_reasoning TEXT;

-- Index for finding unprocessed feedback
CREATE INDEX idx_feedback_status ON feedback_notes(status);
```

### Status Values

- `pending` - Just captured, awaiting classification
- `classified` - AI processed, category assigned
- `added_to_backlog` - Successfully appended to backlog
- `duplicate` - Matched existing backlog item
- `noise` - AI determined not actionable

---

## Classification Prompt

```
You are classifying user feedback about the Selene app into backlog items.

FEEDBACK:
"""
{{feedback_content}}
"""

EXISTING BACKLOG TITLES (for duplicate detection):
{{existing_titles}}

Classify this feedback into exactly ONE category:
- user_story: A need expressed from user perspective ("I wanted...", "I couldn't...")
- feature_request: A specific new capability ("Add X", "Support Y")
- bug: Something broken or producing wrong results
- improvement: Enhancement to existing functionality
- noise: Not actionable (test messages, incomplete thoughts, off-topic)

Respond in JSON only:
{
  "category": "user_story|feature_request|bug|improvement|noise",
  "title": "Brief title (max 60 chars, starts with verb for bugs/improvements)",
  "description": "One sentence explaining the need or issue",
  "confidence": 0.0-1.0,
  "duplicate_of": "ID if matches existing item, null otherwise",
  "reasoning": "Why this category and title"
}

Rules:
- If confidence < 0.5, default to "noise"
- If feedback closely matches an existing title, set duplicate_of
- Titles should be scannable and specific, not generic
```

**Model:** `mistral:7b` (consistent with other Selene workflows)

---

## Testing

1. Send test feedback with `test_run` marker
2. Verify classification stored in `feedback_notes`
3. Verify backlog file updated (or skipped for noise/duplicate)
4. Cleanup removes test entries from both `feedback_notes` and backlog file

---

## Not In Scope (YAGNI)

- Priority auto-assignment (user sets manually)
- Notification when items added
- Web UI for backlog management
- GitHub Issues integration
- Bidirectional sync

---

## Future Extensions

- `/backlog` command in SeleneChat to review items
- Promotion workflow: backlog item → design doc
- Weekly digest of new backlog items

---

## Implementation Checklist

- [ ] Create migration `012_feedback_classification.sql`
- [ ] Run migration on database
- [ ] Update backlog file format (`docs/backlog/user-stories.md`)
- [ ] Add nodes to Workflow 01 (after Insert Feedback Note)
- [ ] Test with `#selene-feedback` tagged notes
- [ ] Update Workflow 01 STATUS.md
- [ ] Commit all changes
