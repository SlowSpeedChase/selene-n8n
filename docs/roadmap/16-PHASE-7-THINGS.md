# Phase 7: Things Integration

**Status:** 📋 READY FOR IMPLEMENTATION (Phase 7.1 Design Complete)
**Started:** 2025-11-24
**Design Updated:** 2025-11-25
**Goal:** Integrate Selene with Things 3 via conversational gatekeeping - YOU decide what's real work vs noise before tasks reach Things

---

## Overview

Phase 7 brings Selene's note processing intelligence into task management via **conversational gatekeeping**. Selene extracts potential tasks using local AI, but YOU decide what's real work before anything reaches Things. This prevents "task slop" while maintaining ADHD-optimized enrichment.

**Key Innovation:**
- **Gatekeeping:** Tasks staged for review before creation in Things (prevents clutter)
- **Conversational approval:** Review tasks one-at-a-time in SeleneChat
- **Three-bucket system:** Approved → Things, Someday → queryable later, Archived → hidden
- **Local AI first:** Phase 7.1 uses only local Ollama (private), cloud AI added in Phase 7.5+

---

## Architecture

### System Integration

```
┌──────────────────────────────────────────────────────────────┐
│                    EXISTING SELENE PIPELINE                  │
│  Drafts → n8n → SQLite → Ollama → Obsidian                 │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ NEW: After sentiment analysis
                         ▼
             ┌───────────────────────┐
             │  Workflow 07:         │
             │  Task Extraction      │
             │  (Ollama LLM)         │
             └──────────┬────────────┘
                        │
         ┌──────────────┴──────────────┐
         │                             │
         ▼                             ▼
┌─────────────────┐          ┌──────────────────┐
│  Things MCP     │          │  Database:       │
│  Create Task    │          │  task_metadata   │
│  (AppleScript)  │◀────────▶│  (enrichment)    │
└─────────────────┘          └──────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│       Things 3 App                  │
│  • Tasks in Inbox                   │
│  • Auto-organized into Projects     │
│  • Tagged with energy levels        │
└─────────────────────────────────────┘
         │
         │ Display in
         ▼
┌─────────────────────────────────────┐
│       SeleneChat                    │
│  • Show related tasks per note      │
│  • Energy-filtered task views       │
│  • Project dashboards               │
└─────────────────────────────────────┘
```

### Data Flow

1. **Note Capture** (existing): Drafts → n8n → SQLite
2. **Processing** (existing): Ollama extracts concepts, themes, energy, sentiment
3. **Task Extraction** (NEW): Ollama identifies action items with ADHD enrichment
4. **Things Creation** (NEW): MCP creates tasks in Things inbox
5. **Metadata Storage** (NEW): Selene stores task relationships and enrichment
6. **Project Detection** (NEW): Daily workflow groups tasks into projects
7. **Status Sync** (NEW): Hourly workflow reads completion status from Things
8. **Pattern Analysis** (NEW): Learn from completion patterns to improve predictions

---

## Sub-Phases

### Phase 7.1: Task Extraction with Gatekeeping (Weeks 1-2)

**Goal:** Extract tasks for user review - only approved tasks reach Things

**🎯 CRITICAL CHANGE:** Tasks are NOT auto-created in Things. They go to a review queue where YOU decide what's real.

**Design Document:** See `docs/plans/2025-11-25-phase-7-1-gatekeeping-design.md` for complete specification.

**Database Changes:**

```sql
-- New table: extracted_tasks (NOT task_metadata)
-- Key difference: Tasks exist here BEFORE Things, not after
CREATE TABLE extracted_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL,

    -- Task content (stored here, not just metadata)
    task_text TEXT NOT NULL,

    -- ADHD enrichment
    energy_required TEXT CHECK(energy_required IN ('high', 'medium', 'low')),
    estimated_minutes INTEGER CHECK(estimated_minutes IN (5,15,30,60,120,240)),
    overwhelm_factor INTEGER CHECK(overwhelm_factor BETWEEN 1 AND 10),
    task_type TEXT CHECK(task_type IN ('action','decision','research','communication','learning','planning')),
    context_tags TEXT,
    related_concepts TEXT,
    related_themes TEXT,

    -- GATEKEEPING: Review workflow status
    review_status TEXT DEFAULT 'pending_review'
        CHECK(review_status IN ('pending_review','approved','someday','archived')),
    review_notes TEXT,

    -- Things integration (NULL until approved)
    things_task_id TEXT UNIQUE,
    synced_to_things_at DATETIME,

    -- Project linkage
    project_id INTEGER,

    -- Timestamps
    extracted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    reviewed_at DATETIME,
    completed_at DATETIME,

    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL
);

-- New table: projects (for "It's a project" button)
CREATE TABLE projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_name TEXT NOT NULL,
    project_description TEXT,
    source_note_id INTEGER,
    status TEXT DEFAULT 'someday'
        CHECK(status IN ('someday','active','completed','archived')),
    things_project_id TEXT UNIQUE,
    synced_to_things_at DATETIME,
    estimated_total_hours INTEGER,
    energy_type TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    activated_at DATETIME,
    completed_at DATETIME,
    FOREIGN KEY (source_note_id) REFERENCES raw_notes(id) ON DELETE SET NULL
);

-- Extend existing tables
ALTER TABLE raw_notes ADD COLUMN tasks_extracted BOOLEAN DEFAULT 0;
ALTER TABLE raw_notes ADD COLUMN tasks_extracted_at DATETIME;

ALTER TABLE processed_notes ADD COLUMN task_extraction_status TEXT
    CHECK(task_extraction_status IN ('pending','extracted','no_tasks','error'))
    DEFAULT 'pending';
```

**New Workflow: 07-task-extraction**

Location: `/workflows/07-task-extraction/`

**Trigger:** Schedule (every 2 minutes) - Phase 7.1 simple approach, event-driven in Phase 7.2

**Critical Behavior:** ❌ DOES NOT create tasks in Things automatically!

**Nodes:**
1. **Schedule Trigger**: Every 2 minutes
2. **Query Pending Notes**: WHERE task_extraction_status='pending'
3. **Ollama Task Extraction**: LLM analyzes note for actionable tasks
   - Prompt: Extract ONLY clear action items (filters vague thoughts)
   - Output: JSON array with confidence scores
   - Filter: Only keep tasks with confidence >= 0.7
4. **Check if Tasks Found**: Parse JSON, filter low-confidence
5. **Loop Each Task**: For each extracted task
   - **Insert to extracted_tasks**: Store with review_status='pending_review'
   - **NO Things creation** - that happens in SeleneChat after approval
6. **Update Note Status**: Set task_extraction_status = 'extracted' or 'no_tasks'

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
Analyze this note and extract actionable tasks.

Note content: {content}
Energy level: {energy_level}
Concepts: {concepts}
Themes: {themes}
Emotional tone: {emotional_tone}

For each task, provide:
1. task_text: Clear, actionable description (start with verb)
2. energy_required: high/medium/low (based on complexity and note energy)
3. estimated_minutes: 5, 15, 30, 60, 120, or 240
4. task_type: action/decision/research/communication
5. context_tags: Relevant contexts (e.g., work, personal, urgent)
6. overwhelm_factor: 1-10 (how overwhelming this task might feel)

Return JSON array. If no actionable tasks, return empty array.

Example:
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

**SeleneChat Integration (NEW):**

User workflow:
1. Open SeleneChat
2. Ask: "What did I capture today?"
3. SeleneChat shows TaskReviewView
4. Review each task one-at-a-time:
   - Shows: task_text, energy, time, overwhelm, source note
   - Options: [✓ Approve] [⏰ Someday] [✗ Archive] [💬 It's a Project]
5. When [✓ Approve] clicked:
   - Create task in Things via MCP/URL scheme
   - Update extracted_tasks: review_status='approved', things_task_id populated
6. When [⏰ Someday] clicked:
   - Update extracted_tasks: review_status='someday'
   - Task stays in database, NOT in Things
7. When [✗ Archive] clicked:
   - Update extracted_tasks: review_status='archived'
   - Task hidden, never goes to Things
8. When [💬 It's a Project] clicked:
   - Create project shell in projects table with status='someday'
   - Link task to project
   - Project activation happens in Phase 7.2

**Testing Plan:**
- [ ] Database migration creates tables correctly (7 tests, TDD approach)
- [ ] Workflow extracts tasks and stores with pending_review (6 tests)
- [ ] SeleneChat displays pending tasks (UI test)
- [ ] Approval flow creates task in Things and updates database (integration test)
- [ ] Someday flow keeps task out of Things (integration test)
- [ ] Archive flow hides task (integration test)
- [ ] Project creation flow works (integration test)
- [ ] E2E: Drafts → Extract → Review → Things (1 test)
- [ ] UAT: 5 real-world scenarios

**Success Metrics:**
- 70%+ approval rate (proves filtering is working, not too noisy)
- <5% false negatives (missed real tasks)
- Daily review takes <5 minutes
- Things inbox stays clean
- User trusts the system and uses it daily

---

### Phase 7.2: Project Detection (Weeks 3-4)

**Goal:** Auto-group related tasks into Things projects

**Database Changes:**

```sql
CREATE TABLE project_metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    things_project_id TEXT NOT NULL UNIQUE,
    primary_concept TEXT,
    related_themes TEXT, -- JSON array
    project_energy_profile TEXT, -- 'high-energy', 'mixed', 'low-energy'
    estimated_total_time INTEGER, -- Sum of task minutes
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    synced_at TEXT,
    notes_count INTEGER DEFAULT 0,
    tasks_count INTEGER DEFAULT 0
);

CREATE INDEX idx_project_metadata_things_id ON project_metadata(things_project_id);
CREATE INDEX idx_project_metadata_concept ON project_metadata(primary_concept);
```

**New Workflow: 08-project-detection**

Location: `/workflows/08-project-detection/`

**Trigger:** Scheduled daily (8am) OR manual webhook

**Nodes:**
1. **Scheduled Trigger**: Daily at 8am
2. **Database Query**: Get processed_notes grouped by primary concept
   - Find concepts with 3+ notes
   - Filter: created in last 30 days
3. **Loop Each Concept Cluster**:
   - **Ollama Analysis**: "Is this a cohesive project?"
   - **If Yes**:
     - **Things MCP**: Create project
     - **Database Insert**: project_metadata
     - **Query Related Tasks**: Find tasks with matching concept
     - **Things MCP**: Move tasks to project
     - **Update Metadata**: Set things_project_id for tasks
4. **Update Counts**: project_metadata.tasks_count, notes_count

**Ollama Prompt (Project Detection):**

```
Analyze these notes and determine if they represent a cohesive project.

Concept: {concept_name}
Notes: {note_titles_and_snippets}
Themes: {shared_themes}
Time span: {first_note_date} to {last_note_date}

Questions:
1. Do these notes describe a single, cohesive project or goal?
2. Is there a clear outcome or deliverable?
3. Are the tasks related enough to group together?

If YES, provide:
- project_name: Clear, concise name (3-5 words)
- project_description: One-sentence summary
- confidence: 1-10 (how confident this is a real project)

If NO, provide:
- reason: Why these notes don't form a project

Return JSON:
{
  "is_project": true/false,
  "project_name": "Website Redesign",
  "project_description": "Redesign company website with modern UI",
  "confidence": 8,
  "reason": null
}
```

**Testing Plan:**
- [ ] Test with 3 notes about same project → project created
- [ ] Test with 3 unrelated notes → no project created
- [ ] Verify Things project appears in correct area
- [ ] Verify tasks moved to project successfully
- [ ] Test energy profile calculation (high/mixed/low)
- [ ] Test time total calculation

**Success Metrics:**
- 90%+ of auto-created projects validated by user
- Task-to-project assignment >85% accuracy
- No orphaned projects (0 tasks)

---

### Phase 7.3: SeleneChat Display (Weeks 5-6)

**Goal:** Show related tasks in SeleneChat

**SeleneChat Changes:**

**New Service: `ThingsMCPService.swift`**

```swift
class ThingsMCPService {
    static func getTask(id: String) async throws -> ThingsTask {
        // Call MCP server (or Things URL scheme for iOS)
        // Parse response
    }

    static func getTasks(for metadata: [TaskMetadata]) async throws -> [ThingsTask] {
        // Batch fetch tasks from Things
    }
}
```

**New View: `RelatedTasksSection.swift`**

```swift
struct RelatedTasksSection: View {
    let tasks: [ThingsTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Tasks (\(tasks.count))")
                .font(.headline)

            ForEach(tasks) { task in
                TaskRow(task: task)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct TaskRow: View {
    let task: ThingsTask

    var body: some View {
        HStack {
            Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.completed ? .green : .gray)

            VStack(alignment: .leading) {
                Text(task.title)
                    .strikethrough(task.completed)

                if let energy = task.metadata?.energy_required {
                    Text(energyLabel(energy))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Open") {
                NSWorkspace.shared.open(URL(string: "things:///show?id=\(task.id)")!)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
```

**Modify: `NoteDetailView.swift`**

```swift
struct NoteDetailView: View {
    @State var relatedTasks: [ThingsTask] = []

    var body: some View {
        ScrollView {
            NoteContentView(note: note)

            Divider()

            if !relatedTasks.isEmpty {
                RelatedTasksSection(tasks: relatedTasks)
            }
        }
        .task {
            await loadRelatedTasks()
        }
    }

    func loadRelatedTasks() async {
        let metadata = await DatabaseService.getTaskMetadata(for: note.id)
        relatedTasks = try await ThingsMCPService.getTasks(for: metadata)
    }
}
```

**Testing Plan:**
- [ ] View note with 0 tasks → no section shown
- [ ] View note with 1 task → task displayed correctly
- [ ] View note with 3 tasks → all tasks visible
- [ ] Verify task status (completed/incomplete) accurate
- [ ] Test "Open in Things" button → opens correct task
- [ ] Test performance: tasks load in <200ms

**Success Metrics:**
- Related tasks load in <200ms
- Task status accuracy >95%
- User feedback: "helpful" rating

---

### Phase 7.4: Status Sync & Pattern Analysis (Weeks 7-8)

**Goal:** Track completion and learn from patterns

**New Workflow: 09-status-sync**

Location: `/workflows/09-status-sync/`

**Trigger:** Scheduled hourly OR on-demand

**Nodes:**
1. **Scheduled Trigger**: Every hour
2. **Database Query**: Get all things_task_id from task_metadata
   - Filter: synced_at < 1 hour ago OR completed_at IS NULL
3. **Loop Each Task**:
   - **Things MCP**: Get task status
   - **If Completed**:
     - Update task_metadata.completed_at
     - Trigger pattern analysis
   - Update task_metadata.synced_at
4. **Pattern Analysis** (if completed):
   - Compare energy_required vs. note.energy_level at completion
   - Compare estimated_minutes vs. actual duration
   - Store insights in detected_patterns table

**Pattern Analysis Logic:**

```javascript
// In n8n function node
const task = $input.item.json;
const completionTime = new Date(task.completed_at) - new Date(task.created_at);
const estimatedTime = task.estimated_minutes * 60000; // ms

const patterns = {
  task_id: task.id,
  pattern_type: 'task_completion',

  // Energy accuracy
  energy_assigned: task.energy_required,
  energy_at_creation: task.note_energy_level,
  energy_match: task.energy_required === task.note_energy_level,

  // Time accuracy
  estimated_ms: estimatedTime,
  actual_ms: completionTime,
  time_accuracy_pct: (estimatedTime / completionTime) * 100,

  // Learning
  task_type: task.task_type,
  context_tags: task.context_tags,

  detected_at: new Date().toISOString()
};

// Insert into detected_patterns table
return patterns;
```

**Testing Plan:**
- [ ] Complete task in Things → synced within 5 minutes
- [ ] Verify completed_at timestamp accurate
- [ ] Verify pattern analysis triggered
- [ ] Test energy correlation calculation
- [ ] Test time accuracy calculation

**Success Metrics:**
- Sync latency <5 minutes
- Pattern insights for 50%+ completed tasks
- Time estimation improves over 2 weeks

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

## Phase 7.5: Cloud AI Refinement (Future)

**Goal:** Add cloud AI for task refinement and web research (opt-in, privacy-aware)

**When:** After Phases 7.1-7.4 are stable and used daily (Month 2+)

**Why Later:** Prove the gatekeeping workflow with local AI first, then enhance with cloud capabilities.

**What This Adds:**

Phase 7.1-7.4 use **only local Ollama** for privacy. Phase 7.5 adds **cloud AI as an optional enhancement**.

See the complete design document for Phase 7.5 details including:
- Privacy boundaries and filters
- Conversational task refinement (Option B)
- Web research for "how to do X"
- User controls and opt-in requirements
- Testing plan and success metrics

**File:** `docs/plans/2025-11-25-phase-7-1-gatekeeping-design.md` (Section: Phase 7.5)

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

- [Things Integration Architecture](../architecture/things-integration.md) - Complete technical architecture
- [User Stories](../user-stories/things-integration-stories.md) - User scenarios and acceptance criteria
- [ADHD Features Integration](../planning/adhd-features-integration.md) - Deep dive into ADHD principles
- [First Implementation Spec](../plans/auto-create-tasks-from-notes.md) - Detailed Phase 7.1 implementation
- [Current Status](./02-CURRENT-STATUS.md) - Overall project status
- [Database Schema](./10-DATABASE-SCHEMA.md) - Complete database structure

---

## Notes

**Design Decisions:**

1. **Things as Source of Truth:**
   - Prevents data duplication
   - Leverages Things' mature task management
   - Selene focuses on intelligence, not task storage

2. **MCP over URL Schemes:**
   - Bi-directional communication
   - Richer API access
   - More secure (AppleScript vs. URL parsing)

3. **Event-Driven Workflows:**
   - Reduces latency (no 30-second polling)
   - Lower resource usage
   - Immediate task creation after note processing

4. **Metadata-Only Storage:**
   - Minimal database footprint
   - Respects Things as manager
   - Enrichment lives in Selene, state in Things

**Open Questions:**

- [ ] Should project creation require user approval initially?
- [ ] What overwhelm_factor threshold triggers intervention?
- [ ] How to handle recurring tasks in pattern analysis?
- [ ] Should SeleneChat sync tasks real-time or cached?

---

**Phase Status:** 📋 PLANNING
**Next Action:** Review and approve architecture, then begin Phase 7.1 implementation
**Owner:** Chase Easterling
**Last Updated:** 2025-11-24