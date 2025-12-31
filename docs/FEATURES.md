# Selene Features Reference

> **Maintainer Note:** Update this document when adding new features. See [Keeping This Document Updated](#keeping-this-document-updated) at the end.

---

## Feature Overview

Selene is an ADHD-focused knowledge management system with three tiers:

| Tier | Purpose | Components |
|------|---------|------------|
| **Capture** | Notes enter system | Drafts App, Workflow 01 |
| **Process** | Notes analyzed | Workflows 02, 03, 05, 06, 07 |
| **Retrieve** | Notes accessed | SeleneChat, Obsidian Export |

---

## Feature Relationship Diagram

```
                           CAPTURE
                              │
                    ┌─────────▼─────────┐
                    │   Drafts App      │
                    │   (iOS/macOS)     │
                    └─────────┬─────────┘
                              │ HTTP POST
                    ┌─────────▼─────────┐
                    │  01-Ingestion     │
                    │  raw_notes table  │
                    └─────────┬─────────┘
                              │
                           PROCESS
                              │
                    ┌─────────▼─────────┐
                    │ 02-LLM Processing │
                    │ processed_notes   │
                    └────┬───┬───┬──────┘
         ┌───────────────┘   │   └───────────────┐
         ▼                   ▼                   ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│ 05-Sentiment   │  │ 03-Pattern     │  │ 07-Task        │
│ Analysis       │  │ Detection      │  │ Extraction     │
│ sentiment_     │  │ detected_      │  │                │
│ history        │  │ patterns       │  │                │
└───────┬────────┘  └───────┬────────┘  └───────┬────────┘
        │                   │                   │
        └─────────┬─────────┘                   │
                  │                             ▼
                  │                    ┌────────────────┐
               RETRIEVE                │ Things 3 App  │
                  │                    └────────────────┘
        ┌─────────┴─────────┐
        ▼                   ▼
┌────────────────┐  ┌────────────────┐
│ 04-Obsidian    │  │ SeleneChat     │
│ Export         │  │ (macOS app)    │
│ vault files    │  │ SQLite queries │
└────────────────┘  └────────────────┘
```

---

## Features by Tier

### Tier 1: Capture

#### Drafts App Integration
**Type:** External integration
**Purpose:** Zero-friction note capture from iOS/macOS

| Aspect | Details |
|--------|---------|
| **Input** | User-created notes |
| **Output** | HTTP POST to Workflow 01 |
| **Payload** | `{title, content, uuid, created_at}` |

**ADHD Value:** One-click capture eliminates friction

---

#### Workflow 01: Ingestion
**Location:** `workflows/01-ingestion/`
**Purpose:** Receive, deduplicate, and store notes

| Aspect | Details |
|--------|---------|
| **Trigger** | Webhook POST |
| **Input** | Drafts payload |
| **Output** | `raw_notes` table entry |
| **Depends on** | Drafts App |
| **Downstream** | Workflow 02 |

**Key Features:**
- SHA256 content hash for duplicate detection
- Draft UUID tracking for edit detection
- Hashtag extraction from content
- Test data isolation via `test_run` marker

**Status:** Production ready (6/7 tests passing)

---

### Tier 2: Process

#### Workflow 02: LLM Processing
**Location:** `workflows/02-llm-processing/`
**Purpose:** Extract concepts, themes, and metadata via Ollama

| Aspect | Details |
|--------|---------|
| **Trigger** | Cron (30s interval) |
| **Input** | `raw_notes` where `status='pending'` |
| **Output** | `processed_notes` table entry |
| **Depends on** | Workflow 01, Ollama |
| **Downstream** | Workflows 03, 04, 05, 07 |

**Extracts:**
- 3-5 concepts per note
- Primary and secondary themes
- Confidence scores (0.0-1.0)
- Note type classification

**Performance:** 10-30s per note (~60-100 notes/hour)

**Status:** Production ready

---

#### Workflow 03: Pattern Detection
**Location:** `workflows/03-pattern-detection/`
**Purpose:** Detect recurring themes and concept clusters

| Aspect | Details |
|--------|---------|
| **Trigger** | Daily + on-demand webhook |
| **Input** | All `processed_notes` |
| **Output** | `detected_patterns`, `pattern_reports` |
| **Depends on** | Workflow 02 |
| **Downstream** | Obsidian export, Analysis queries |

**Detects:**
- Concept clusters (co-occurring concepts)
- Dominant concepts (cross-theme)
- Energy patterns (distribution)
- Sentiment trends
- Emotional tone patterns

**ADHD Value:** Makes patterns visible that memory misses

**Status:** Ready for testing

---

#### Workflow 05: Sentiment Analysis
**Location:** `workflows/05-sentiment-analysis/`
**Purpose:** Analyze emotional tone, energy, and ADHD markers

| Aspect | Details |
|--------|---------|
| **Trigger** | Cron (45s interval) |
| **Input** | `processed_notes` where `sentiment_analyzed=0` |
| **Output** | `sentiment_history` table entry |
| **Depends on** | Workflow 02, Ollama |
| **Downstream** | Workflows 03, 04 |

**Analyzes:**
- Overall sentiment (positive/negative/neutral/mixed)
- Emotional tone (7+ states)
- Energy level (high/medium/low)
- Stress indicators
- ADHD markers (overwhelm, hyperfocus, executive dysfunction)

**ADHD Value:** Energy tracking for capacity matching

**Status:** Production ready

---

#### Workflow 06: Connection Network
**Location:** `workflows/06-connection-network/`
**Purpose:** Analyze concept-based connections between notes

| Aspect | Details |
|--------|---------|
| **Trigger** | TBD |
| **Input** | `processed_notes` |
| **Output** | `network_analysis_history` |
| **Depends on** | Workflow 02 |
| **Downstream** | Visualization, Analysis |

**Status:** Planned

---

#### Workflow 07: Task Extraction
**Location:** `workflows/07-task-extraction/`
**Purpose:** Extract actionable tasks and create in Things 3

| Aspect | Details |
|--------|---------|
| **Trigger** | Webhook with note ID |
| **Input** | Note content and metadata |
| **Output** | Things 3 tasks |
| **Depends on** | Workflow 02, Things 3 HTTP wrapper |
| **Downstream** | Things 3 App |

**Extracts:**
- Actionable tasks
- Energy required (high/medium/low)
- Estimated duration
- Overwhelm factor (1-10)
- Context tags

**ADHD Value:** Automatic task capture with energy estimation

**Status:** Ready for import

---

### Tier 3: Retrieve

#### Workflow 04: Obsidian Export
**Location:** `workflows/04-obsidian-export/`
**Purpose:** Export to Obsidian with ADHD-optimized organization

| Aspect | Details |
|--------|---------|
| **Trigger** | Hourly + on-demand |
| **Input** | Processed + sentiment-analyzed notes |
| **Output** | Markdown files in vault |
| **Depends on** | Workflows 01, 02, 05 |
| **Downstream** | Obsidian App |

**Export Views:**
1. **By-Concept/** - Primary navigation
2. **By-Theme/** - Theme-based
3. **By-Energy/** - Energy level folders (high/medium/low)
4. **Timeline/** - Chronological backup

**ADHD Features:**
- Visual emoji indicators
- Energy-matched organization
- TL;DR context boxes
- Action item extraction
- Brain state tracking

**Status:** Production ready

---

#### SeleneChat (macOS App)
**Location:** `SeleneChat/`
**Purpose:** Conversational note retrieval with AI assistance

| Aspect | Details |
|--------|---------|
| **Language** | Swift 5.9+ / SwiftUI |
| **Database** | Direct SQLite.swift connection |
| **LLM** | Ollama integration |
| **Depends on** | SQLite database, Ollama |

**Features:**
- Natural language queries
- Full-text search with filters
  - Concept filter
  - Theme filter
  - Energy level filter
  - Date range filter
- Clickable citations [1], [2] linking to sources
- Note detail view with full metadata

**Privacy Model (Planned):**
1. On-Device (Apple Intelligence)
2. Private Cloud (Apple PCC)
3. External (Claude API)

**Status:** Phase 1 complete (search, filter, chat working)

---

## Database Schema

| Table | Purpose | Created By | Used By |
|-------|---------|------------|---------|
| `raw_notes` | Original notes | Workflow 01 | All workflows |
| `processed_notes` | LLM-extracted data | Workflow 02 | Workflows 03-07, SeleneChat |
| `sentiment_history` | Emotional tracking | Workflow 05 | Workflows 03, 04, SeleneChat |
| `detected_patterns` | Recurring themes | Workflow 03 | Analysis, Export |
| `pattern_reports` | Pattern summaries | Workflow 03 | Reporting |
| `network_analysis_history` | Note connections | Workflow 06 | Visualization |

---

## External Integrations

| System | Integration Type | Purpose |
|--------|-----------------|---------|
| **Drafts** | Webhook POST | Note capture |
| **Ollama** | HTTP API | LLM processing |
| **Obsidian** | File export | Note browsing |
| **Things 3** | HTTP wrapper | Task management |

---

## Feature Dependency Matrix

```
Feature                  Depends On                    Enables
─────────────────────────────────────────────────────────────────
01-Ingestion            Drafts                        02-LLM Processing
02-LLM Processing       01-Ingestion, Ollama          03, 04, 05, 06, 07
03-Pattern Detection    02-LLM Processing             Analysis, Reports
04-Obsidian Export      01, 02, 05                    Obsidian browsing
05-Sentiment Analysis   02-LLM Processing, Ollama     03, 04, SeleneChat
06-Connection Network   02-LLM Processing             Visualization
07-Task Extraction      02-LLM Processing, Ollama     Things 3
SeleneChat              Database, Ollama              User queries
```

---

## Keeping This Document Updated

### When to Update
- Adding a new workflow
- Adding a new external integration
- Adding new SeleneChat features
- Changing feature dependencies
- Changing database schema

### How to Update

1. **New Workflow:**
   - Add entry under appropriate tier (Capture/Process/Retrieve)
   - Update Feature Relationship Diagram
   - Update Feature Dependency Matrix
   - Add to Database Schema table if it creates tables

2. **New Integration:**
   - Add to External Integrations table
   - Update relevant workflow entries
   - Update dependency matrix

3. **Schema Changes:**
   - Update Database Schema table
   - Update affected workflow entries

4. **Status Changes:**
   - Update status in relevant feature entry

### Template for New Workflow

```markdown
#### Workflow XX: [Name]
**Location:** `workflows/XX-name/`
**Purpose:** [One-line description]

| Aspect | Details |
|--------|---------|
| **Trigger** | [Cron/Webhook/Manual] |
| **Input** | [Source table or data] |
| **Output** | [Destination table or system] |
| **Depends on** | [Upstream features] |
| **Downstream** | [What uses this] |

**Key Features:**
- [Feature 1]
- [Feature 2]

**ADHD Value:** [How it helps ADHD users]

**Status:** [Planned/In Progress/Ready/Production]
```

---

## Version History

| Date | Change |
|------|--------|
| 2025-12-30 | Initial document created |

