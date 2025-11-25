# Things Integration: Complete Planning Package

**Created:** 2025-11-24
**Updated:** 2025-11-25
**Status:** ✅ Phase 7.1 Design Complete - Ready for Implementation
**Purpose:** Integration plan for Selene + Things 3 + ADHD Task Management with Gatekeeping

---

## What Was Created

**UPDATED 2025-11-25:** Design revised based on brainstorming session to add **gatekeeping** - tasks are reviewed and approved before reaching Things (prevents slop).

This planning session produced a comprehensive set of documents that integrate:
1. The ADHD Task Management specification ([ADHD_Principles.md](../.claude/ADHD_Principles.md))
2. The working Selene production system (note processing + Obsidian)
3. Things 3 task manager via MCP server
4. **NEW: Conversational gatekeeping** in SeleneChat for task review/approval

**Key Change from Original Plan:**
- ❌ OLD: Auto-create tasks in Things (could create "slop")
- ✅ NEW: Extract → Review in SeleneChat → Approve → Then create in Things

**All documents updated and ready for implementation.**

---

## Document Overview

### 0. Complete Design Document (NEW - START HERE)
**File:** [`docs/plans/2025-11-25-phase-7-1-gatekeeping-design.md`](./plans/2025-11-25-phase-7-1-gatekeeping-design.md)

**What it contains:**
- **Complete Phase 7.1 specification with gatekeeping workflow**
- User flow (Capture → Review → Approve → Things)
- Database schema (extracted_tasks + projects tables)
- Workflow 07 specification (extract but DON'T auto-create)
- SeleneChat integration (TaskReviewView, approval buttons)
- Testing strategy (TDD approach, 45 automated tests)
- Migration plan (incremental rollout, rollback procedures)

**Use this for:** Implementation of Phase 7.1. This is the primary spec.

### 1. Architecture Document (UPDATED)
**File:** [`docs/architecture/things-integration.md`](./architecture/things-integration.md)

**What it contains:**
- System architecture (now includes gatekeeping layer)
- MCP server selection rationale (hildersantos/things-mcp)
- Database schema (updated: extracted_tasks not task_metadata)
- n8n workflow specifications (07: extract only, 08-09: future phases)
- SeleneChat integration patterns (review/approval UI)
- Data flow examples (Note → Extract → Review → Approve → Things)
- ADHD optimization principles
- Privacy considerations (local AI in 7.1, cloud AI in 7.5)
- Success metrics

**Note:** Some sections may reference old auto-creation approach - refer to design doc for latest.

**Use this for:** Understanding overall architecture and design rationale.

---

### 2. User Stories Document
**File:** [`docs/user-stories/things-integration-stories.md`](./user-stories/things-integration-stories.md)

**What it contains:**
- 15+ user stories organized by phase (7.1-7.4 + Future)
- Each story includes:
  - User perspective ("As an ADHD user...")
  - Acceptance criteria (testable requirements)
  - ADHD optimization explanation
  - UI mockups (ASCII art)
  - Technical notes
  - Priority level
- User acceptance testing scenarios
- ADHD-specific testing criteria

**Use this for:** Understanding user needs and validating that implementation meets requirements.

**Key Stories:**
- Story 1.1: Auto-extract tasks from voice notes
- Story 1.2: Energy level assignment
- Story 1.3: Time estimation
- Story 2.1: Auto-create projects from concept clusters
- Story 3.1: View related tasks in SeleneChat
- Story 4.1: Task completion tracking

---

### 3. Phase 7 Roadmap (UPDATED)
**File:** [`docs/roadmap/16-PHASE-7-THINGS.md`](./roadmap/16-PHASE-7-THINGS.md)

**What it contains:**
- **UPDATED Phase 7.1:** Task Extraction with Gatekeeping (NOT auto-creation)
- Phases 7.2-7.4: Project Detection, SeleneChat Display, Bidirectional Sync
- **NEW Phase 7.5:** Cloud AI Refinement (privacy-aware, opt-in)
- Complete database schema (extracted_tasks + projects tables)
- n8n workflow specifications (extract → pending_review, NO auto-create)
- Ollama prompts for task extraction with confidence filtering
- SeleneChat integration (TaskReviewView with approval buttons)
- Testing strategy (TDD, 45 automated tests)
- Success metrics (approval rate, daily review time, user trust)
- Rollback plan
- Future enhancements (Phase 8+: proactive intelligence, visual org, time visibility)

**Use this for:** Implementation timeline, understanding all phases of Things integration.

---

### 4. ADHD Features Integration Discussion
**File:** [`docs/planning/adhd-features-integration.md`](./planning/adhd-features-integration.md)

**What it contains:**
- Deep dive into each ADHD principle from the original spec
- Current state analysis (what Selene already does)
- Gap analysis (what's missing)
- Detailed feature designs for:
  - **Capture:** O.H.I.O. principle, quick capture modes
  - **Organize:** WTF Mind-Maps, Project Mind-Maps, visual organization
  - **Plan:** Monthly/Weekly/Daily/Moment views, time visibility
  - **Emotional Regulation:** Daily check-ins, evening ritual, STOP & PIVOT
  - **Procrastination:** Resistance type identification, reframe strategies
- Implementation roadmap (Phases 8-12)
- 18+ discussion questions for future sessions
- UI mockups and code examples

**Use this for:** Starting a new Claude session to design specific ADHD features in depth.

**Key Sections:**
- Time Visibility (Weekly View is critical for ADHD)
- STOP & PIVOT Technique (overwhelm intervention)
- Daily Thought Tracker (emotional regulation)
- Task Resistance Diagnostic (procrastination support)

---

### 5. Implementation Spec: Task Extraction with Gatekeeping (UPDATED)
**File:** [`docs/plans/2025-11-25-phase-7-1-gatekeeping-design.md`](./plans/2025-11-25-phase-7-1-gatekeeping-design.md)

**What it contains:**
- **Step-by-step implementation guide** for Phase 7.1 with gatekeeping
- Prerequisites checklist (Things 3, database backup)
- Database migration script (extracted_tasks + projects tables)
- Ollama prompt with confidence filtering
- n8n workflow specification (extract to pending_review, NO auto-create)
- SeleneChat integration (TaskReviewView, approval flow)
- Testing procedures (TDD approach, 45 tests total)
- Migration plan (incremental rollout, observation → partial → full)
- Monitoring and metrics (approval rate, review time)
- Rollback procedures (soft disable, hard rollback, restore backup)

**Use this for:** Actual implementation - this is the PRIMARY "how to build it" document.

**Ready-to-use artifacts:**
- SQL migration: `007_task_extraction_gatekeeping.sql`
- Ollama prompt template (with filtering rules)
- n8n workflow nodes (complete specification)
- SeleneChat Swift code (TaskReviewView, TaskReviewService)
- Test scripts (bash-based, TDD approach)

**NOTE:** Old file `auto-create-tasks-from-notes.md` describes auto-creation approach (outdated).

---

## Integration Strategy Summary

### The Three-Layer Architecture

```
┌─────────────────────────────────────────┐
│  CAPTURE: Drafts → Selene              │
│  • No organization required             │
│  • O.H.I.O. principle enforced         │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  ORGANIZE: Selene (Ollama + SQLite)    │
│  • Auto-extract concepts, themes        │
│  • Auto-extract tasks                   │
│  • Auto-detect projects                 │
│  • Energy & ADHD marker analysis        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  PLAN: Things 3 + SeleneChat           │
│  • Things = Task storage & scheduling   │
│  • SeleneChat = Planning interface      │
│  • Time visibility (future)             │
│  • Emotional regulation (future)        │
└─────────────────────────────────────────┘
```

### Key Design Decisions

**1. Things as Source of Truth**
- Task state (status, due dates) lives in Things, not Selene
- Selene stores only metadata and enrichment
- Clean separation prevents data duplication

**2. Selene as Intelligence Layer**
- Concept extraction → Projects
- Energy analysis → Task matching
- Pattern learning → Better estimates
- ADHD markers → Interventions

**3. Bi-Directional Flow**
- Selene creates tasks in Things (via MCP)
- Selene reads completion status (for pattern learning)
- User manages tasks in Things (mature, polished UI)
- User sees enriched context in SeleneChat

**4. MCP-Based Integration**
- hildersantos/things-mcp (TypeScript, npx-based)
- Secure AppleScript integration
- Rich API (create, update, read, search)
- Local-only (no cloud dependencies)

**5. ADHD-Optimized Throughout**
- Energy-based task matching
- Time estimates with buffer (planning fallacy correction)
- Overwhelm factor tracking
- Visual organization (future: mind-maps, kanban)
- Emotional regulation features (future: check-ins, STOP & PIVOT)

---

## Implementation Timeline

### Phase 7.1: Task Extraction Foundation
**Duration:** Weeks 1-2
**Status:** Ready to Start

**Deliverables:**
- ✅ Database schema (task_metadata table)
- ✅ n8n Workflow 07 (task extraction + MCP integration)
- ✅ Ollama prompt (task extraction with ADHD enrichment)
- ✅ Testing suite (unit + integration + UAT)

**Success Criteria:**
- 80%+ task extraction accuracy
- Energy assignments validated by user
- Zero duplicate tasks
- <30 second workflow completion

**First Action:** Install Things 3 and configure MCP server (Step 1 in implementation spec)

---

### Phase 7.2: Project Detection
**Duration:** Weeks 3-4
**Status:** Planning Complete

**Deliverables:**
- Database schema (project_metadata table)
- n8n Workflow 08 (project detection + auto-creation)
- Ollama prompt (project identification)
- Task-to-project assignment logic

**Success Criteria:**
- 90%+ project detection accuracy
- 85%+ task-to-project assignment accuracy
- No orphaned projects

---

### Phase 7.3: SeleneChat Display
**Duration:** Weeks 5-6
**Status:** Planning Complete

**Deliverables:**
- ThingsMCPService.swift (MCP client for SeleneChat)
- RelatedTasksSection.swift (UI component)
- Database query optimization
- "Open in Things" deep linking

**Success Criteria:**
- Tasks load in <200ms
- Task status accuracy >95%
- User feedback: "helpful"

---

### Phase 7.4: Status Sync & Pattern Analysis
**Duration:** Weeks 7-8
**Status:** Planning Complete

**Deliverables:**
- n8n Workflow 09 (hourly status sync)
- Pattern analysis logic (energy correlation, time accuracy)
- Completion tracking
- Insight generation

**Success Criteria:**
- Sync latency <5 minutes
- Pattern insights for 50%+ completed tasks
- Time estimate accuracy improves over 2 weeks

---

## Next Steps

### Immediate (This Week)

1. **Install Prerequisites:**
   - [ ] Install Things 3 from Mac App Store
   - [ ] Configure MCP server in Claude Desktop config
   - [ ] Test MCP connection with simple task creation

2. **Prepare Database:**
   - [ ] Review migration script (007_task_metadata.sql)
   - [ ] Apply migration to test database first
   - [ ] Verify schema with `PRAGMA table_info(task_metadata);`

3. **Test Ollama Prompt:**
   - [ ] Run prompt template with sample notes
   - [ ] Validate JSON output format
   - [ ] Adjust prompt based on results

### Short-Term (Next 2 Weeks)

4. **Build Workflow 07:**
   - [ ] Create workflow in n8n
   - [ ] Configure all 9 nodes
   - [ ] Test with sample data
   - [ ] Connect to workflow 05

5. **Test End-to-End:**
   - [ ] Send test note from Drafts
   - [ ] Verify task appears in Things
   - [ ] Check task_metadata in database
   - [ ] Validate enrichment data (energy, time, overwhelm)

6. **Deploy to Production:**
   - [ ] Monitor first 10 notes
   - [ ] Collect user feedback
   - [ ] Adjust prompt/thresholds as needed

### Medium-Term (Weeks 3-4)

7. **Implement Phase 7.2:**
   - [ ] Build project detection workflow
   - [ ] Test with real note clusters
   - [ ] Validate project names and assignments

### Long-Term Planning

8. **Design Phase 8 Features:**
   - Option A: Time Visibility (calendar integration, weekly view)
   - Option B: Emotional Regulation (check-ins, STOP & PIVOT)
   - Option C: Visual Organization (mind-maps, kanban)

   **Recommendation:** Start with Time Visibility (Phase 8) - it's foundational for other features and has highest ADHD impact (addresses time blindness).

9. **Start New Session for Deep Dive:**
   - Use [`docs/planning/adhd-features-integration.md`](./planning/adhd-features-integration.md)
   - Pick one section to design in detail
   - Create implementation specs for chosen features

---

## How to Use These Documents

### For Implementation Work
**Start with:** Implementation Spec ([`auto-create-tasks-from-notes.md`](./plans/auto-create-tasks-from-notes.md))
- Follow steps 1-7 in order
- Reference architecture doc for context
- Use user stories for validation

### For Understanding the System
**Start with:** Architecture Document ([`things-integration.md`](./architecture/things-integration.md))
- Read system overview and data flow
- Understand design decisions
- See how pieces fit together

### For Planning Next Features
**Start with:** ADHD Features Discussion ([`adhd-features-integration.md`](./planning/adhd-features-integration.md))
- Pick a section (Time Visibility, Emotional Regulation, etc.)
- Review current gaps
- Design specific features
- Create implementation specs

### For Validating Work
**Start with:** User Stories ([`things-integration-stories.md`](./user-stories/things-integration-stories.md))
- Review acceptance criteria
- Run test scenarios
- Collect user feedback
- Measure success metrics

---

## Questions & Decisions Needed

### Before Starting Implementation

1. **MCP Server Setup:**
   - [ ] Is Things 3 already installed?
   - [ ] Is Claude Desktop already configured with MCP?
   - [ ] Should we test MCP connection first?

2. **Database Migration:**
   - [ ] Should we apply to production DB or create test DB first?
   - [ ] Do we need backup before migration?

3. **Ollama Prompt:**
   - [ ] Should we tune prompt on test data first?
   - [ ] What's acceptable task extraction accuracy (80%? 90%?)?

### For Future Phases

4. **Phase 7.2 Timing:**
   - [ ] Start immediately after 7.1 or wait for feedback?
   - [ ] Should project creation require user approval initially?

5. **SeleneChat Integration:**
   - [ ] Build for macOS first, iOS later?
   - [ ] Should tasks be read-only or allow completion from SeleneChat?

6. **Phase 8 Direction:**
   - [ ] Time Visibility (calendar integration)?
   - [ ] Emotional Regulation (check-ins, STOP & PIVOT)?
   - [ ] Visual Organization (mind-maps, kanban)?

---

## Related Files

### Documentation Created Today
- [`docs/architecture/things-integration.md`](./architecture/things-integration.md) - System architecture
- [`docs/user-stories/things-integration-stories.md`](./user-stories/things-integration-stories.md) - User scenarios
- [`docs/roadmap/16-PHASE-7-THINGS.md`](./roadmap/16-PHASE-7-THINGS.md) - Implementation roadmap
- [`docs/planning/adhd-features-integration.md`](./planning/adhd-features-integration.md) - ADHD feature deep dive
- [`docs/plans/auto-create-tasks-from-notes.md`](./plans/auto-create-tasks-from-notes.md) - Implementation spec

### Existing Related Documentation
- [`/.claude/ADHD_Principles.md`](../.claude/ADHD_Principles.md) - Original ADHD task management spec
- [`docs/roadmap/00-INDEX.md`](./roadmap/00-INDEX.md) - Roadmap index (needs updating)
- [`docs/roadmap/02-CURRENT-STATUS.md`](./roadmap/02-CURRENT-STATUS.md) - Project status (needs updating)
- [`docs/architecture/overview.md`](./architecture/overview.md) - Current Selene architecture
- [`database/schema.sql`](../database/schema.sql) - Current database schema

### Files to Create During Implementation
- `database/migrations/007_task_metadata.sql` - Database migration
- `workflows/07-task-extraction/` - n8n workflow files
- `workflows/07-task-extraction/task-extraction-prompt.txt` - Ollama prompt template
- `SeleneChat/Sources/Services/ThingsMCPService.swift` - MCP client (Phase 7.3)
- `SeleneChat/Sources/Views/RelatedTasksSection.swift` - UI component (Phase 7.3)

---

## Success Indicators

**You'll know Phase 7.1 is successful when:**
- ✅ You capture a voice note with tasks
- ✅ Tasks appear in Things inbox within 2 minutes
- ✅ Task titles are clear and actionable
- ✅ Energy levels make sense to you
- ✅ Time estimates feel realistic
- ✅ You DON'T have to manually process notes anymore
- ✅ You trust the system to extract what's important

**You'll know the ADHD integration is working when:**
- ✅ Your working memory feels lighter (system remembers for you)
- ✅ You can find tasks matching your current energy
- ✅ You're not over-scheduling anymore (realistic estimates)
- ✅ Overwhelm is caught early (before paralysis sets in)
- ✅ Tasks feel organized without you organizing them
- ✅ You complete more tasks (less friction between capture and action)

---

## Final Thoughts

This integration brings together:
- **Selene's strength:** Intelligent note processing and ADHD-aware analysis
- **Things' strength:** Polished task management and scheduling
- **ADHD Principles:** Executive function support, energy management, emotional regulation

The result is a system that:
1. **Reduces cognitive load** (auto-extraction, auto-organization)
2. **Accommodates ADHD** (energy-aware, time-visible, overwhelm-preventive)
3. **Learns from patterns** (better estimates, personalized insights)
4. **Stays out of the way** (works in background, surfaces when helpful)

**You have everything you need to start building.**

The first milestone is small but impactful: **auto-create tasks from notes**. Once that's working, everything else builds on top of it.

Ready to begin? Start with Step 1 in [`auto-create-tasks-from-notes.md`](./plans/auto-create-tasks-from-notes.md).

---

**Document Status:** ✅ Complete
**Next Action:** Install Things 3 and configure MCP server
**Owner:** Chase Easterling
**Created:** 2025-11-24