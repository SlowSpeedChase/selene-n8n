# Things Integration Architecture

**Status:** Planning
**Created:** 2025-11-24
**Author:** Chase Easterling + Claude
**Related:** [Phase 7 Roadmap](../roadmap/08-PHASE-7-THINGS.md), [ADHD Principles](../../.claude/ADHD_Principles.md)

---

## Executive Summary

This document defines the architecture for integrating Selene with the Things 3 task management app via Model Context Protocol (MCP). The integration follows a **bi-directional data flow** where Selene automatically creates tasks and projects in Things based on note analysis, while Things remains the **source of truth** for task state and scheduling.

### Key Principles

1. **Things as Source of Truth**: Task state (status, due dates, completion) lives in Things, not Selene database
2. **Selene as Intelligence Layer**: Concept extraction, energy analysis, and ADHD-optimized enrichment
3. **Bi-directional Flow**: Selene creates tasks → Things manages them → Selene reads status for pattern analysis
4. **MCP-Based Integration**: Use Model Context Protocol server for clean, secure Things app access
5. **Metadata Enrichment Only**: Selene stores task relationships and enrichments, not task data itself

---

## System Architecture

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DATA CAPTURE LAYER                           │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                      ┌──────────▼──────────┐
                      │   Drafts App        │
                      │   (Voice/Text)      │
                      └──────────┬──────────┘
                                 │ webhook
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      SELENE PROCESSING LAYER                        │
├─────────────────────────────────────────────────────────────────────┤
│  ┌────────────┐    ┌────────────┐    ┌─────────────┐              │
│  │ n8n Flow 1 │───▶│ n8n Flow 2 │───▶│ n8n Flow 5  │              │
│  │ Ingestion  │    │ LLM        │    │ Sentiment   │              │
│  │            │    │ Processing │    │ Analysis    │              │
│  └────────────┘    └────────────┘    └─────────────┘              │
│         │                 │                  │                      │
│         ▼                 ▼                  ▼                      │
│  ┌──────────────────────────────────────────────────┐              │
│  │         SQLite Database (selene.db)              │              │
│  │  • raw_notes: Original content                   │              │
│  │  • processed_notes: Concepts, themes, energy     │              │
│  │  • sentiment_history: ADHD markers, overwhelm    │              │
│  └──────────────────────────────────────────────────┘              │
│         │                                                           │
│         ▼                                                           │
│  ┌────────────┐           ┌─────────────────────┐                 │
│  │ n8n Flow 7 │          │  NEW: task_metadata  │                 │
│  │ Task       │──────────▶│  (enrichment only)   │                 │
│  │ Extraction │          │  • things_task_id     │                 │
│  └────────────┘          │  • raw_note_id        │                 │
│         │                │  • energy_required    │                 │
│         │                │  • related_concepts   │                 │
│         │                └─────────────────────┘                   │
└─────────┼───────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      MCP INTEGRATION LAYER                          │
├─────────────────────────────────────────────────────────────────────┤
│                   ┌───────────────────────┐                         │
│                   │   Things MCP Server   │                         │
│                   │  (hildersantos/       │                         │
│                   │   things-mcp)         │                         │
│                   └───────────┬───────────┘                         │
│                               │ AppleScript                         │
└───────────────────────────────┼─────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      TASK MANAGEMENT LAYER                          │
├─────────────────────────────────────────────────────────────────────┤
│                   ┌───────────────────────┐                         │
│                   │    Things 3 App       │                         │
│                   │  • Tasks (inbox)      │                         │
│                   │  • Projects           │                         │
│                   │  • Areas              │                         │
│                   │  • Tags               │                         │
│                   │  • Schedule           │                         │
│                   └───────────┬───────────┘                         │
└───────────────────────────────┼─────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   SeleneChat App      │
                    │ • View related tasks  │
                    │ • Task status display │
                    │ • Energy insights     │
                    └───────────────────────┘
```

---

## Component Details

### 1. MCP Server Selection

**Chosen: hildersantos/things-mcp**

**Rationale:**
- ✅ **Bi-directional support**: Create, update, complete, and read tasks
- ✅ **Security**: Uses secure AppleScript integration (no URL scheme limitations)
- ✅ **Active maintenance**: Recent commits, responsive maintainer
- ✅ **Simple setup**: `npx github:hildersantos/things-mcp` - no compilation needed
- ✅ **Rich feature set**: Access all lists (inbox, today, upcoming, anytime, someday)
- ✅ **Project support**: Create and manage Things projects
- ✅ **Search capabilities**: Query tasks by various criteria

**Alternative considered: hald/things-mcp (Python)**
- More features but requires `uv` package manager
- TypeScript option better fits n8n workflow ecosystem (Node.js based)

**Installation Configuration:**

```json
// ~/Library/Application Support/Claude/claude_desktop_config.json
{
  "mcpServers": {
    "MCP_DOCKER": {
      "command": "docker",
      "args": ["mcp", "gateway", "run"]
    },
    "things-mcp": {
      "command": "npx",
      "args": ["-y", "github:hildersantos/things-mcp"]
    }
  }
}
```

### 2. Database Schema Extensions

**New Table: `task_metadata`**

```sql
CREATE TABLE task_metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Link to source note
    raw_note_id INTEGER NOT NULL,

    -- Things integration
    things_task_id TEXT NOT NULL UNIQUE, -- Things UUID
    things_project_id TEXT, -- If assigned to project

    -- ADHD-optimized enrichment (from Selene analysis)
    energy_required TEXT CHECK(energy_required IN ('high', 'medium', 'low')),
    estimated_minutes INTEGER, -- Derived from LLM analysis
    related_concepts TEXT, -- JSON array of concept IDs
    related_themes TEXT, -- JSON array of theme names
    overwhelm_factor INTEGER CHECK(overwhelm_factor BETWEEN 1 AND 10),

    -- Task metadata extracted by LLM
    task_type TEXT, -- 'action', 'decision', 'research', 'communication'
    context_tags TEXT, -- JSON array: ['work', 'personal', 'urgent']

    -- Timestamps
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    synced_at TEXT, -- Last time we read status from Things
    completed_at TEXT, -- When task was completed (from Things)

    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id) ON DELETE CASCADE
);

CREATE INDEX idx_task_metadata_note ON task_metadata(raw_note_id);
CREATE INDEX idx_task_metadata_things_id ON task_metadata(things_task_id);
CREATE INDEX idx_task_metadata_energy ON task_metadata(energy_required);
```

**New Table: `project_metadata`**

```sql
CREATE TABLE project_metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Things integration
    things_project_id TEXT NOT NULL UNIQUE,

    -- Selene organization
    primary_concept TEXT, -- Main concept this project relates to
    related_themes TEXT, -- JSON array

    -- ADHD optimization
    project_energy_profile TEXT, -- 'high-energy', 'mixed', 'low-energy'
    estimated_total_time INTEGER, -- Sum of all tasks (minutes)

    -- Timestamps
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    synced_at TEXT,

    -- Project metadata from Selene
    notes_count INTEGER DEFAULT 0, -- How many notes mention this project
    tasks_count INTEGER DEFAULT 0 -- How many tasks in this project
);

CREATE INDEX idx_project_metadata_things_id ON project_metadata(things_project_id);
CREATE INDEX idx_project_metadata_concept ON project_metadata(primary_concept);
```

**Modifications to Existing Tables:**

```sql
-- Add column to track if note has generated tasks
ALTER TABLE raw_notes ADD COLUMN tasks_extracted BOOLEAN DEFAULT 0;
ALTER TABLE raw_notes ADD COLUMN tasks_extracted_at TEXT;

-- Add column to track Things integration status
ALTER TABLE processed_notes ADD COLUMN things_integration_status TEXT
    CHECK(things_integration_status IN ('pending', 'tasks_created', 'no_tasks', 'error'))
    DEFAULT 'pending';
```

### 3. n8n Workflow Integration

**New Workflow: 07-task-extraction**

```
Trigger: Database event (new processed_note)
│
├─ Read processed_note data
│  └─ Get: concepts, themes, energy_level, content
│
├─ LLM Analysis (Ollama)
│  └─ Prompt: "Extract actionable tasks from this note..."
│  └─ Output: JSON with task list + metadata
│
├─ For each extracted task:
│  │
│  ├─ Things MCP: Create Task
│  │  └─ Input: task_text, notes=note_content
│  │  └─ Output: things_task_id
│  │
│  └─ Database: Insert task_metadata
│     └─ Store: things_task_id, raw_note_id, enrichment data
│
└─ Update processed_notes.things_integration_status
```

**Enhanced LLM Prompt for Task Extraction:**

```
Analyze this note and extract actionable tasks.

Note content: {content}
Energy level: {energy_level}
Concepts: {concepts}
Themes: {themes}

For each task, provide:
1. task_text: Clear, actionable description (verb-first)
2. energy_required: high/medium/low (based on note's energy and complexity)
3. estimated_minutes: Time estimate (5, 15, 30, 60, 120)
4. task_type: action/decision/research/communication
5. context_tags: Relevant contexts from note
6. overwhelm_factor: 1-10 (how overwhelming this task feels)

Return JSON array:
[
  {
    "task_text": "Write project proposal draft",
    "energy_required": "high",
    "estimated_minutes": 60,
    "task_type": "action",
    "context_tags": ["work", "writing"],
    "overwhelm_factor": 6
  }
]
```

**New Workflow: 08-project-detection**

```
Trigger: Daily schedule (8am) OR Manual webhook
│
├─ Query: Get recent processed_notes grouped by concepts
│  └─ Find: Notes with shared primary concepts
│
├─ For each concept cluster (3+ notes):
│  │
│  ├─ LLM Analysis: "Is this a project?"
│  │  └─ Consider: theme consistency, time span, task count
│  │  └─ Output: project_name, description, should_create
│  │
│  ├─ If should_create:
│  │  │
│  │  ├─ Things MCP: Create Project
│  │  │  └─ Input: project_name, notes=description
│  │  │  └─ Output: things_project_id
│  │  │
│  │  ├─ Database: Insert project_metadata
│  │  │
│  │  └─ Things MCP: Move related tasks to project
│  │     └─ Query task_metadata for related tasks
│  │     └─ Update each task's project
│  │
│  └─ Update project_metadata.tasks_count
│
└─ Log: Projects created/updated
```

**New Workflow: 09-status-sync**

```
Trigger: Hourly schedule OR On-demand webhook
│
├─ Query: Get all things_task_id from task_metadata
│  └─ Filter: Where synced_at < 1 hour ago OR completed_at IS NULL
│
├─ For each task_id:
│  │
│  ├─ Things MCP: Get Task Status
│  │  └─ Read: status (completed/canceled), completion_date
│  │
│  ├─ If status changed:
│  │  └─ Update task_metadata:
│  │     • synced_at = NOW
│  │     • completed_at = completion_date (if completed)
│  │
│  └─ If completed:
│     └─ Trigger: Pattern analysis workflow
│        └─ Analyze: energy_required vs completion_time
│        └─ Analyze: overwhelm_factor vs actual difficulty
│
└─ Update project_metadata.tasks_count for affected projects
```

### 4. Things MCP API Usage

**Key Operations:**

**Create Task in Inbox:**
```json
{
  "tool": "create-todo",
  "arguments": {
    "title": "Write project proposal draft",
    "notes": "Extracted from Selene note ID: 123\nEnergy: high\nEstimated: 60 min",
    "tags": ["work", "writing"],
    "when": "anytime"
  }
}
```

**Create Project:**
```json
{
  "tool": "create-project",
  "arguments": {
    "title": "Website Redesign",
    "notes": "Auto-created by Selene from concept: 'web-design'\nRelated themes: planning, creative, technical",
    "area": "Work"
  }
}
```

**Move Task to Project:**
```json
{
  "tool": "update-todo",
  "arguments": {
    "id": "{things_task_id}",
    "project": "{things_project_id}"
  }
}
```

**Read Task Status:**
```json
{
  "tool": "get-todo",
  "arguments": {
    "id": "{things_task_id}"
  }
}
```

**Search Tasks by Tag:**
```json
{
  "tool": "search-todos",
  "arguments": {
    "query": "tag:work status:incomplete"
  }
}
```

### 5. SeleneChat Integration (Phase 1: Display Only)

**New Feature: Related Tasks View**

When viewing a note in SeleneChat, display related Things tasks below the note content.

**Swift Implementation Pattern:**

```swift
struct NoteDetailView: View {
    @State var note: Note
    @State var relatedTasks: [ThingsTask] = []
    @State var isLoadingTasks = false

    var body: some View {
        ScrollView {
            // Existing note content...
            NoteContentView(note: note)

            Divider()
                .padding(.vertical)

            if isLoadingTasks {
                ProgressView("Loading tasks...")
            } else if !relatedTasks.isEmpty {
                RelatedTasksSection(tasks: relatedTasks)
            }
        }
        .onAppear {
            loadRelatedTasks()
        }
    }

    func loadRelatedTasks() {
        isLoadingTasks = true
        Task {
            let metadata = await DatabaseService.getTaskMetadata(for: note.id)
            relatedTasks = await ThingsMCPService.getTasks(for: metadata)
            isLoadingTasks = false
        }
    }
}
```

**Database Service Extension:**

```swift
extension DatabaseService {
    func getTaskMetadata(for noteId: Int) async -> [TaskMetadata] {
        let query = """
        SELECT
            tm.*,
            pn.energy_level,
            pn.concepts,
            pn.themes
        FROM task_metadata tm
        JOIN processed_notes pn ON tm.raw_note_id = pn.raw_note_id
        WHERE tm.raw_note_id = ?
        AND tm.completed_at IS NULL
        ORDER BY tm.created_at DESC
        """

        // Execute query and return results
        return try await db.prepare(query).map { row in
            TaskMetadata(
                id: row[0],
                things_task_id: row[1],
                energy_required: row[2],
                estimated_minutes: row[3],
                related_concepts: JSON.parse(row[4]),
                overwhelm_factor: row[5]
            )
        }
    }
}
```

---

## ADHD Optimization Principles

### 1. Externalize Working Memory

**Problem:** ADHD brains struggle to hold task details in working memory

**Solution:**
- Auto-extract tasks from stream-of-consciousness notes
- Store context with task (energy, concepts, overwhelm factor)
- Visual energy indicators in SeleneChat

### 2. Reduce Decision Fatigue

**Problem:** Too many decisions about task organization cause paralysis

**Solution:**
- Auto-assign tasks to projects based on concepts
- Auto-suggest energy requirements
- Auto-estimate time based on similar past tasks

### 3. Make Time Visible

**Problem:** Time blindness makes planning impossible

**Solution:**
- Store estimated_minutes for every task
- Aggregate project time estimates
- (Future) Visual time blocking in SeleneChat

### 4. Accommodate Energy Fluctuations

**Problem:** Fixed schedules ignore variable ADHD energy levels

**Solution:**
- Track energy at task creation and completion
- Pattern analysis: which energy levels work when
- Task suggestions based on current energy state

### 5. Combat Object Permanence Issues

**Problem:** Out of sight = out of mind for ADHD

**Solution:**
- Show related tasks when viewing notes
- Tasks stay visible in both Selene and Things
- Multiple access points (notes → tasks, tasks → notes)

---

## Implementation Priority

### Phase 7.1: Task Extraction Foundation (Weeks 1-2)

**Goal:** Auto-create tasks in Things from notes

**Deliverables:**
1. Database schema (task_metadata table)
2. n8n Workflow 07: Task extraction + Things MCP creation
3. LLM prompt engineering for task extraction
4. Basic error handling and logging

**Success Metrics:**
- 80%+ of notes with action items → tasks created
- Task energy assignments match user validation
- Zero duplicate tasks created

### Phase 7.2: Project Detection (Weeks 3-4)

**Goal:** Auto-group related tasks into Things projects

**Deliverables:**
1. Database schema (project_metadata table)
2. n8n Workflow 08: Project detection + creation
3. LLM prompt for project identification
4. Task reassignment to projects

**Success Metrics:**
- 90%+ of auto-created projects validated by user
- Task-to-project assignment accuracy >85%
- No orphaned projects (0 tasks)

### Phase 7.3: SeleneChat Display (Weeks 5-6)

**Goal:** Show related tasks when viewing notes

**Deliverables:**
1. ThingsMCPService integration in SeleneChat
2. RelatedTasksSection UI component
3. Database query optimization
4. "Open in Things" deep linking

**Success Metrics:**
- Related tasks load in <200ms
- Task status accuracy >95%
- User satisfaction: "helpful" feedback

### Phase 7.4: Status Sync & Patterns (Weeks 7-8)

**Goal:** Track task completion and analyze patterns

**Deliverables:**
1. n8n Workflow 09: Status sync
2. Pattern analysis triggers
3. Energy correlation analysis
4. Completion time tracking

**Success Metrics:**
- Sync latency <5 minutes
- Pattern insights generated for 50%+ of completed tasks
- Energy prediction accuracy improves over time

---

## Related Documentation

- [Phase 7 Roadmap: Things Integration](../roadmap/08-PHASE-7-THINGS.md)
- [User Stories: Things Integration](../user-stories/things-integration-stories.md)
- [ADHD Principles (Design Spec)](../../.claude/ADHD_Principles.md)
- [First Implementation: Auto-Task Creation](../plans/auto-create-tasks-from-notes.md)
- [ADHD Features Integration Discussion](../planning/adhd-features-integration.md)
- [Current Selene Architecture](./overview.md)
- [Database Schema](../../database/schema.sql)

---

**Document Status:** ✅ Ready for Review
**Next Step:** Create user stories and implementation spec
**Owner:** Chase Easterling
**Last Updated:** 2025-11-24