# Things Integration: Complete Planning Package

**Created:** 2025-11-24
**Status:** Ready for Implementation
**Purpose:** Integration plan for Selene + Things 3 + ADHD Task Management

---

## What Was Created

This planning session produced a comprehensive set of documents that integrate:
1. The ADHD Task Management specification ([ADHD_Principles.md](../.claude/ADHD_Principles.md))
2. The working Selene production system (note processing + Obsidian)
3. Things 3 task manager via MCP server

**All documents are ready for implementation.**

---

## Document Overview

### 1. Architecture Document
**File:** [`docs/architecture/things-integration.md`](./architecture/things-integration.md)

**What it contains:**
- Complete system architecture diagram
- MCP server selection rationale (hildersantos/things-mcp)
- Database schema for task_metadata and project_metadata tables
- n8n workflow specifications (07, 08, 09)
- SeleneChat integration patterns (SwiftUI code examples)
- Data flow examples (Note → Task → Completion)
- ADHD optimization principles mapped to implementation
- Security and privacy considerations
- Success metrics for each phase

**Use this for:** Understanding the complete technical architecture and design decisions.

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

### 3. Phase 7 Roadmap
**File:** [`docs/roadmap/16-PHASE-7-THINGS.md`](./roadmap/16-PHASE-7-THINGS.md)

**What it contains:**
- 4 sub-phases with detailed specifications:
  - **7.1:** Task Extraction Foundation (Weeks 1-2)
  - **7.2:** Project Detection (Weeks 3-4)
  - **7.3:** SeleneChat Display (Weeks 5-6)
  - **7.4:** Status Sync & Pattern Analysis (Weeks 7-8)
- Complete database schema with migration SQL
- n8n workflow node-by-node specifications
- Ollama prompts for task extraction and project detection
- SeleneChat SwiftUI code examples
- Testing strategy (unit, integration, UAT)
- Success metrics for each phase
- Rollback plan
- Future enhancements (Phase 8+)

**Use this for:** Implementation timeline and phase-by-phase execution plan.

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

### 5. Implementation Spec: Auto-Create Tasks
**File:** [`docs/plans/auto-create-tasks-from-notes.md`](./plans/auto-create-tasks-from-notes.md)

**What it contains:**
- **Step-by-step implementation guide** for Phase 7.1
- Prerequisites checklist
- Installation instructions (Things 3, MCP server)
- Database migration script with full SQL
- Ollama prompt engineering (complete prompt template)
- n8n workflow creation (9 nodes with full configuration)
- Testing procedures (unit tests, integration tests, UAT)
- Deployment checklist
- Monitoring and metrics
- Troubleshooting guide
- Example task extraction results

**Use this for:** Actual implementation - this is the "how to build it" document.

**Ready-to-use artifacts:**
- SQL migration: `007_task_metadata.sql`
- Ollama prompt template (copy-paste ready)
- n8n node configurations (JSON for each node)
- Test cases with expected outputs

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