# Phase 7: Things Integration

**Status:** 🚧 Phase 7.1 Complete ✅ | Phase 7.2 Design Revised 📋
**Started:** 2025-11-24
**Phase 7.1 Completed:** 2025-12-30
**Phase 7.2 Design Revised:** 2026-01-02
**Goal:** Integrate Selene with Things 3 via user-controlled planning - ALL notes go through SeleneChat for triage before any tasks are created

---

## Overview

> **DESIGN REVISION (2026-01-02):** The original auto-routing design has been replaced with a user-controlled triage model. See `docs/plans/2026-01-02-planning-inbox-redesign.md` for the complete revised design.

Phase 7 brings Selene's note processing intelligence into task management via **user-controlled triage**. Local AI enriches every note with metadata and suggests categorization, but the **user decides** what becomes a task through SeleneChat's Inbox.

**Key Innovation:**
- **No auto-routing:** ALL notes park in SeleneChat Inbox for user triage
- **User confirms everything:** Tasks only created after user approval
- **Active/Parked structure:** Prevents overwhelm in planning view
- **Classification as hint:** AI suggests note type, user decides action
- **Context memory:** Projects preserve history when reopened with new notes

**Design Documents:**
- **Current:** `docs/plans/2026-01-02-planning-inbox-redesign.md` (this design)
- **Superseded:** `docs/plans/2025-12-30-task-extraction-planning-design.md` (auto-routing)

---

## Architecture

### Architectural Layers (Revised 2026-01-02)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CAPTURE LAYER                                │
│  Drafts App = Raw capture, brain dump, zero friction                │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      PROCESSING LAYER (Local AI)                     │
│                                                                      │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │ Extract Metadata │    │  Classify       │    │  Suggest        │ │
│  │ - concepts       │ →  │  (as UI hint)   │ →  │  - note type    │ │
│  │ - themes         │    │ - actionable    │    │  - project link │ │
│  │ - energy         │    │ - needs_planning│    │                 │ │
│  │ - overwhelm      │    │ - archive_only  │    │                 │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│                                                                      │
│  Ollama (mistral:7b) - All processing stays local                   │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────┐
                    │     ALL NOTES PARK HERE     │
                    │                             │
                    │   SeleneChat Planning Tab   │
                    │        📥 Inbox             │
                    └─────────────┬───────────────┘
                                  │
                           USER TRIAGE
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
    ┌───────────┐          ┌───────────┐          ┌───────────┐
    │Create Task│          │  Start    │          │   Park    │
    │(confirm)  │          │  Project  │          │           │
    └─────┬─────┘          └─────┬─────┘          └─────┬─────┘
          │                      │                      │
          ▼                      ▼                      ▼
    ┌───────────┐          ┌───────────┐          ┌───────────┐
    │  Things   │          │ Planning  │          │  Parked   │
    │   Inbox   │          │   Conv    │          │   List    │
    └───────────┘          └─────┬─────┘          └───────────┘
                                 │
                                 ▼
                           ┌───────────┐
                           │  Tasks →  │
                           │  Things   │
                           └───────────┘
```

### AI Layer Responsibilities

| Layer | Tool | Responsibilities |
|-------|------|------------------|
| **Local AI** | Ollama | Metadata extraction, classification (as hint), project matching |
| **Cloud AI** (Phase 7.3+) | External service | Planning conversations, scoping, breakdown |
| **SeleneChat** | macOS app | **All triage + planning** - Inbox, Active/Parked projects, conversations |
| **Things** | Task manager | Receives tasks **only after user confirmation** |

### Data Flow (Revised)

1. **Note Capture** (existing): Drafts → n8n → SQLite
2. **Metadata Extraction**: Ollama extracts concepts, themes, energy, overwhelm, task_type
3. **Classification as Hint**: Ollama suggests type (quick_task, relates_to_project, new_project, reflection)
4. **Park in Inbox**: ALL notes go to SeleneChat Inbox (no auto-routing)
5. **User Triage**: User sees notes with suggested types, decides action:
   - Create Task → Confirm text → Things
   - Start Project → Planning conversation → Tasks
   - Add to Project → Attach to existing project
   - Park → Save for later
   - Archive → Store but hide from Planning
6. **Planning Conversations** (Phase 7.2): Guided breakdown produces tasks → Things
7. **Cloud AI** (Phase 7.3): Sanitized requests for complex planning

---

## Sub-Phases

### Phase 7.1: Task Extraction with Classification (Complete, Behavior Revised)

**Status:** ✅ Complete (workflow exists) | Behavior revised 2026-01-02

**Original Goal:** Extract metadata and classify notes - route actionable items to Things inbox

**Revised Behavior:** Workflow 07 still extracts metadata and classifies, but:
- **No longer auto-routes to Things**
- Classification becomes a **UI hint** for SeleneChat Inbox
- Suggests note type and related projects
- User decides all routing through triage

**Design Documents:**
- Original: `docs/plans/2025-12-30-task-extraction-planning-design.md`
- **Revised:** `docs/plans/2026-01-02-planning-inbox-redesign.md`

**Classification Categories (now UI hints):**

| Classification | UI Badge | Suggested Actions | Example |
|----------------|----------|-------------------|---------|
| `actionable` | 📋 Quick task | Create Task, Park | "Call dentist tomorrow" |
| `needs_planning` | 🆕 New project | Start Project, Park | "Want to redo my website" |
| `archive_only` | 💭 Reflection | Keep in Knowledge, Archive | "Thinking about how attention works" |
| (concept match) | 🔗 Relates to... | Add to Project, New Project | (any note matching existing project) |

**Database Changes:**

```sql
-- Extend processed_notes with classification
ALTER TABLE processed_notes ADD COLUMN classification TEXT
    CHECK(classification IN ('actionable', 'needs_planning', 'archive_only'));
ALTER TABLE processed_notes ADD COLUMN planning_status TEXT
    CHECK(planning_status IN ('pending_review', 'planned', 'archived'));

-- New table: extracted_tasks (for actionable items)
CREATE TABLE extracted_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL,
    task_text TEXT NOT NULL,

    -- Metadata (see docs/architecture/metadata-definitions.md)
    energy_required TEXT CHECK(energy_required IN ('high', 'medium', 'low')),
    estimated_minutes INTEGER CHECK(estimated_minutes IN (5,15,30,60,120,240)),
    overwhelm_factor INTEGER CHECK(overwhelm_factor BETWEEN 1 AND 10),
    task_type TEXT CHECK(task_type IN ('action','decision','research','communication','learning','planning')),
    context_tags TEXT,
    related_concepts TEXT,
    related_themes TEXT,

    -- Things integration
    things_task_id TEXT UNIQUE,
    synced_to_things_at DATETIME,

    -- Timestamps
    extracted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,

    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id) ON DELETE CASCADE
);

-- New table: discussion_threads (for SeleneChat continuations)
CREATE TABLE discussion_threads (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL,
    thread_prompt TEXT,
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'continued', 'archived')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    continued_at DATETIME,
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id) ON DELETE CASCADE
);
```

**Metadata Field Specifications:** See `docs/architecture/metadata-definitions.md`

**New Workflow: 07-task-extraction**

Location: `/workflows/07-task-extraction/`

**Trigger:** Event-driven (after LLM processing) or Schedule (every 2 minutes)

**Core Behavior:** Classifies notes and routes actionable items directly to Things

**Nodes:**
1. **Trigger**: Event from workflow 02 or schedule
2. **Query Pending Notes**: WHERE classification IS NULL
3. **Ollama Classification**: LLM analyzes note and classifies
   - Prompt: Classify as actionable/needs_planning/archive_only
   - Extract full metadata for all notes
   - Output: JSON with classification and metadata
4. **Route by Classification**:
   - `actionable` → Create task in Things inbox, store in extracted_tasks
   - `needs_planning` → Flag in database, create discussion_thread prompt
   - `archive_only` → Update classification only (Obsidian export handles rest)
5. **Update Note Classification**: Set classification field on processed_notes

**MCP Configuration:**

```json
// ~/Library/Application Support/Claude/claude_desktop_config.json
{
  "mcpServers": {
    "MCP_DOCKER": { ... },
    "things-mcp": {
      "command": "npx",
      "args": ["-y", "github:hildersantos/things-mcp"]
    }
  }
}
```

**Ollama Prompt Template:**

```
Analyze this note and classify it, then extract metadata.

Note content: {content}
Existing concepts: {concepts}
Existing themes: {themes}

CLASSIFICATION RULES:
- "actionable": Clear verb + object, can be done in one session, unambiguous "done" state
- "needs_planning": Goal or desired outcome, multiple potential tasks, requires scoping, overwhelm_factor > 7
- "archive_only": Reflective thought, no implied action, information capture, emotional processing

Provide:
1. classification: actionable/needs_planning/archive_only
2. task_text: (if actionable) Clear description starting with verb
3. energy_required: high/medium/low
4. estimated_minutes: 5, 15, 30, 60, 120, or 240
5. task_type: action/decision/research/communication/learning/planning
6. context_tags: Relevant contexts (e.g., work, personal, urgent)
7. overwhelm_factor: 1-10 (complexity + emotional weight)
8. planning_prompt: (if needs_planning) Question to surface in SeleneChat

Return JSON:
{
  "classification": "actionable",
  "task_text": "Call dentist about appointment",
  "energy_required": "low",
  "estimated_minutes": 15,
  "task_type": "communication",
  "context_tags": ["health", "phone"],
  "overwhelm_factor": 2,
  "planning_prompt": null
}
```

**SeleneChat Role (Phase 7.2+):**

SeleneChat becomes the **primary interface** for:

1. **Knowledge Querying** - Search across personal archive
2. **Topic Discussion** - Explore and refine ideas from notes
3. **Planning Sessions** - Work through `needs_planning` items
4. **Thread Continuation** - Surface contextually related topics

**Surfacing Behavior (ambient, not interruptive):**

| Trigger | Behavior |
|---------|----------|
| You mention related topic | "This connects to something you wrote about last week..." |
| You open SeleneChat | "Threads to continue" section visible |
| You ask | "What needs planning?" shows flagged items |

No push notifications. No scheduled reminders. Available when you engage.

**Testing Plan:**
- [ ] Database migration creates tables correctly
- [ ] Classification accuracy validated (90%+ target)
- [ ] Actionable items reach Things inbox within 2 minutes
- [ ] needs_planning items correctly flagged in database
- [ ] archive_only items exported to Obsidian only
- [ ] Full metadata attached to all notes
- [ ] E2E: Drafts → Classify → Route (Things or flag)
- [ ] UAT: 5 real-world scenarios

**Success Metrics:**
- 90%+ classification accuracy (validated by user)
- Actionable tasks reach Things within 2 minutes
- needs_planning items correctly flagged
- Full metadata attached to all notes
- Things inbox stays clean (no ambiguous items)

---

### Phase 7.2: SeleneChat Planning Integration (Design Revised 2026-01-02)

**Status:** 📋 DESIGN REVISED
**Design Docs:**
- **Current:** [Planning Inbox Redesign](../plans/2026-01-02-planning-inbox-redesign.md)
- **Previous:** [Phase 7.2 Design](../plans/2025-12-31-phase-7.2-selenechat-planning-design.md)

**Goal:** SeleneChat becomes the central hub for ALL note triage and planning

**Key Design Decisions (2026-01-02):**
- **All notes to Inbox:** No auto-routing - everything parks in SeleneChat for user triage
- **Active/Parked structure:** Prevents overwhelm (3-5 active projects max)
- **Buttons-first triage:** Quick actions, conversation only when needed
- **Context memory:** Projects preserve history when reopened with new notes
- **User confirms all tasks:** Nothing goes to Things without user approval

**Scope (Revised):**
- **Inbox section:** All new notes with suggested types and actions
- **Active projects:** Currently working on (limited to 3-5)
- **Parked projects:** Everything else - not deleted, just not in focus
- **Quick task flow:** Confirm text → Things (no full conversation needed)
- **Planning conversations:** For complex projects, guided breakdown

**Planning Tab Structure:**

```
┌─────────────────────────────────────────────────────────┐
│  Planning                                        ⚙️     │
├─────────────────────────────────────────────────────────┤
│  📥 Inbox (4)                                           │
│  [New notes with triage buttons]                        │
│                                                         │
│  🔥 Active (2)                                          │
│  [Projects you're currently working on]                 │
│                                                         │
│  🅿️ Parked (12)                              [View →]   │
│  [Everything else]                                      │
└─────────────────────────────────────────────────────────┘
```

**Triage Actions:**

| Note Type | Primary Actions |
|-----------|-----------------|
| 📋 Quick task | Create Task (confirm text), Park, Archive |
| 🔗 Relates to project | Add to Project, New Project, Park |
| 🆕 New project idea | Start Project (→ conversation), Park |
| 💭 Reflection | Keep in Knowledge, Link to..., Archive |

**Database Queries:**

```sql
-- Get items needing planning
SELECT * FROM processed_notes
WHERE classification = 'needs_planning'
AND (planning_status IS NULL OR planning_status = 'pending_review');

-- Get pending discussion threads
SELECT dt.*, rn.title, rn.content
FROM discussion_threads dt
JOIN raw_notes rn ON dt.raw_note_id = rn.id
WHERE dt.status = 'pending';
```

**Testing Plan:**
- [ ] SeleneChat queries flagged items correctly
- [ ] "Threads to continue" UI works
- [ ] Planning conversation generates valid tasks
- [ ] Generated tasks reach Things inbox

**Success Metrics:**
- Planning sessions feel helpful (user feedback)
- Generated tasks are specific and actionable
- Reduces overwhelm for complex items

---

### Phase 7.3: Cloud AI Integration (Weeks 5-6)

**Goal:** Add cloud AI for complex planning with privacy-preserving sanitization

**Scope:**
- Sanitization layer for personal data
- Cloud AI planning sessions (opt-in)
- User sensitivity configuration
- Re-personalization of cloud responses

**Sanitization Layer:**

| Context | Sanitization Level | Details |
|---------|-------------------|---------|
| Simple tasks | Light | Names replaced with generic equivalents |
| Work projects | Medium | User can mark specific details to keep/remove |
| Health/finance/relationships | Heavy | Abstract the problem completely |
| User-configured sensitive topics | Per rules | User defines patterns to always sanitize |

**Example Flow:**

```
Raw note: "Plan trip to visit mom in Seattle, $2000 budget,
          need to work around her chemo schedule"

Sanitized: "Plan a week-long trip to a major west coast city,
           moderate budget, need flexibility around a
           fixed recurring commitment"

Cloud returns: Generic trip planning structure

Local re-applies: Specifics from original note
```

**User Controls:**
- Sensitive topics require confirmation before sending
- User can override sanitization level
- User configures sensitive patterns (names, medical terms, amounts, etc.)

**Testing Plan:**
- [ ] Sanitization removes personal details correctly
- [ ] Cloud AI returns useful planning structure
- [ ] Re-personalization applies specifics back
- [ ] User confirmation required for sensitive topics

**Success Metrics:**
- Personal data never reaches cloud AI (verified by logging)
- Planning quality comparable to direct cloud access
- User feels comfortable using cloud features

---

### Phase 7.4: Contextual Surfacing (Weeks 7-8)

**Goal:** SeleneChat recognizes related topics and surfaces connections

**Scope:**
- SeleneChat recognizes when current topic relates to past notes
- "This connects to..." prompts
- Pattern-based suggestions
- Thread continuation prompts

**Contextual Surfacing Behavior:**

| Trigger | Response |
|---------|----------|
| User mentions topic with related notes | "This connects to something you wrote about [concept] last week..." |
| User opens SeleneChat | "Threads to continue" section with pending items |
| User asks about needs_planning items | Shows flagged items with planning prompts |
| Concept appears frequently | "You've been thinking about [concept] a lot lately. Want to explore this?" |

**Implementation:**

1. **Topic Matching**
   - Compare user input against concept/theme index
   - Surface related notes when confidence > 0.7

2. **Thread Continuation**
   - Query `discussion_threads` with status='pending'
   - Display as conversation starters

3. **Pattern Recognition**
   - Use `detected_patterns` table for insights
   - "You tend to capture [topic] ideas when [context]"

**Testing Plan:**
- [ ] Related topics surface correctly
- [ ] Thread prompts appear when relevant
- [ ] Pattern insights are accurate
- [ ] Surfacing feels helpful, not intrusive

**Success Metrics:**
- Surfacing feels like a helpful assistant
- Users discover forgotten notes/ideas
- Planning sessions start from contextual prompts

---

## Database Schema Summary

**New Tables:**
- `task_metadata`: Links notes to Things tasks with ADHD enrichment
- `project_metadata`: Tracks Things projects with Selene intelligence

**Modified Tables:**
- `raw_notes`: Add tasks_extracted, tasks_extracted_at
- `processed_notes`: Add things_integration_status

**See:** [Things Integration Architecture](../architecture/things-integration.md) for complete schema

---

## Configuration Requirements

### MCP Server

**Installation:**
```bash
# Things MCP server will be installed via npx
# No manual installation needed, specified in Claude config
```

**Configuration File:**
`~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "things-mcp": {
      "command": "npx",
      "args": ["-y", "github:hildersantos/things-mcp"]
    }
  }
}
```

### Dependencies

- **Things 3** (macOS app): Must be installed
- **Node.js**: Required for npx
- **n8n Ollama node**: Already installed
- **SQLite**: Already configured

---

## Testing Strategy

### Unit Testing

**Task Extraction:**
- [ ] LLM prompt returns valid JSON
- [ ] Energy levels assigned correctly
- [ ] Time estimates reasonable (5-240 minutes)
- [ ] Overwhelm factor in valid range (1-10)

**Things MCP Integration:**
- [ ] Task creation successful
- [ ] Project creation successful
- [ ] Task status read accurate
- [ ] Search functionality works

**Database Operations:**
- [ ] task_metadata insert/update
- [ ] project_metadata insert/update
- [ ] Foreign key constraints enforced

### Integration Testing

**End-to-End Flows:**
1. **Note → Task Creation:**
   - Drafts note with action item
   - Verify task appears in Things inbox
   - Verify task_metadata entry created
   - Verify Things task ID stored

2. **Project Detection:**
   - Create 3 notes with same concept
   - Run project detection workflow
   - Verify Things project created
   - Verify tasks moved to project

3. **SeleneChat Display:**
   - Open note in SeleneChat
   - Verify related tasks load
   - Verify task status accurate
   - Test "Open in Things" button

4. **Status Sync:**
   - Complete task in Things
   - Wait for hourly sync
   - Verify completed_at updated
   - Verify pattern analysis ran

### User Acceptance Testing

**ADHD-Specific Scenarios:**

1. **Capture Flow:**
   - User records stream-of-consciousness voice note
   - Multiple tasks extracted automatically
   - Tasks appear in Things within 2 minutes
   - User confirms: "Didn't have to remember or organize"

2. **Energy Management:**
   - User creates note while high-energy
   - Task tagged appropriately
   - User later filters SeleneChat for low-energy tasks
   - Finds appropriate work for current state

3. **Time Visibility:**
   - User sees project with 8h total estimate
   - Realizes it's bigger than thought
   - Decides to postpone or break down
   - "This prevented over-commitment"

4. **Pattern Learning:**
   - After 2 weeks of use
   - System adjusts time estimates based on actual completion
   - Energy predictions improve
   - User notices: "Estimates getting more realistic"

---

## Success Metrics

### Phase 7.1 Success
- ✅ 80%+ task extraction accuracy
- ✅ Energy assignments validated by user
- ✅ Zero duplicate tasks
- ✅ <30 second workflow completion

### Phase 7.2 Success
- ✅ 90%+ project detection accuracy
- ✅ 85%+ task-to-project assignment accuracy
- ✅ No orphaned projects

### Phase 7.3 Success
- ✅ <200ms task loading in SeleneChat
- ✅ 95%+ task status accuracy
- ✅ User reports: "helpful"

### Phase 7.4 Success
- ✅ <5 minute sync latency
- ✅ Pattern insights for 50%+ tasks
- ✅ Improving estimate accuracy

### Overall Phase 7 Success
- ✅ Users report reduced mental load
- ✅ Tasks created without manual processing
- ✅ Energy-aware task selection working
- ✅ Planning fallacy reduced (realistic estimates)
- ✅ Pattern analysis providing actionable insights

---

## Phase 7.5+: Future Enhancements

**Goal:** Additional features after core Phase 7 is stable

**Potential additions:**
- Status sync from Things (track completions)
- Pattern analysis on task completion
- Project detection and grouping
- Web research integration

**When:** After Phases 7.1-7.4 are stable and used daily (Month 2+)

---

## Rollback Plan

**If integration fails:**

1. **Pause workflows:**
   - Disable workflow 07, 08, 09
   - No new tasks created

2. **Database rollback:**
   ```sql
   DROP TABLE IF EXISTS task_metadata;
   DROP TABLE IF EXISTS project_metadata;
   ALTER TABLE raw_notes DROP COLUMN tasks_extracted;
   ALTER TABLE raw_notes DROP COLUMN tasks_extracted_at;
   ALTER TABLE processed_notes DROP COLUMN things_integration_status;
   ```

3. **MCP cleanup:**
   - Remove things-mcp from Claude config
   - Restart Claude Desktop

**Data safety:**
- Things 3 remains source of truth
- No data loss (tasks stay in Things)
- Can re-sync if needed

---

## Future Enhancements (Phase 8+)

### Time Blocking (Phase 8.1)
- Calendar integration
- Structured vs. unstructured time detection
- Smart task scheduling suggestions

### Daily Rituals (Phase 8.2)
- Morning planning prompt
- Evening reflection
- Check-in reminders (3-4x daily)

### SeleneChat Task Management (Phase 8.3)
- Create tasks from SeleneChat
- Complete tasks in app
- Kanban view by energy
- Planning dashboard

### Emotional Regulation (Phase 8.4)
- Overwhelm detection alerts
- STOP & PIVOT technique prompts
- Task breakdown suggestions
- Reframe recommendations

---

## Related Documentation

- **[Planning Inbox Redesign](../plans/2026-01-02-planning-inbox-redesign.md)** - Current design (2026-01-02)
- [Task Extraction Planning Design](../plans/2025-12-30-task-extraction-planning-design.md) - Original Phase 7.1 design (superseded for routing)
- [SeleneChat Planning Integration Design](../plans/2025-12-31-phase-7.2-selenechat-planning-design.md) - Original Phase 7.2 design (being revised)
- [Metadata Definitions](../architecture/metadata-definitions.md) - Field specifications for classification
- [Things Integration Architecture](../architecture/things-integration.md) - Technical architecture
- [User Stories](../user-stories/things-integration-stories.md) - User scenarios and acceptance criteria
- [ADHD Features Integration](../planning/adhd-features-integration.md) - Deep dive into ADHD principles
- [Current Status](./02-CURRENT-STATUS.md) - Overall project status
- [Database Schema](./10-DATABASE-SCHEMA.md) - Complete database structure

---

## Notes

**Design Decisions:**

1. **User-Controlled Triage (NEW 2026-01-02):**
   - All notes park in SeleneChat Inbox
   - User confirms before any task is created
   - Prevents inbox overwhelm and AI misinterpretation
   - Classification is a hint, not a routing decision

2. **Things as Source of Truth:**
   - Prevents data duplication
   - Leverages Things' mature task management
   - Selene focuses on intelligence, not task storage

3. **Active/Parked Project Structure (NEW 2026-01-02):**
   - Limits active projects to 3-5 to force focus
   - Parked items not forgotten, just not in face
   - Context preserved when reopening parked projects

4. **Metadata-Only Storage:**
   - Minimal database footprint
   - Respects Things as manager
   - Enrichment lives in Selene, state in Things

**Open Questions (Updated):**

- [x] Should project creation require user approval initially? → YES, all user-initiated
- [ ] What overwhelm_factor threshold triggers intervention?
- [ ] How to handle recurring tasks in pattern analysis?
- [ ] Should SeleneChat sync tasks real-time or cached?

---

## Future Features (Identified 2026-01-02)

These features were identified during the planning inbox redesign brainstorming but are NOT part of initial implementation:

### Parking Lot Rot Detection
Surface parked items that haven't been touched in X days. "Still relevant?"

### AI Suggestions When Active Doesn't Appeal
"Nothing clicking today? Based on your energy, try 'Home Office Setup' - mostly low-energy research."

### Task Check-in Conversations
"You created 'Call dentist' 5 days ago but haven't done it. What's getting in the way?"
Helps identify emotional blockers and reframe tasks.

### Explicit Project Suggestion Correction
"Not this" button when AI suggests wrong project match.

### Auto-Park Suggestions
"You haven't touched this active project in 2 weeks - park it?"

---

**Phase Status:** 🚧 Phase 7.1 Complete | Phase 7.2 Design Revised
**Next Action:** Implement revised Phase 7.2 (Inbox + Active/Parked structure)
**Owner:** Chase Easterling
**Last Updated:** 2026-01-02