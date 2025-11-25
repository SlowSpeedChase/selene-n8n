# Things Integration User Stories

**Status:** Planning
**Created:** 2025-11-24
**Related:** [Things Integration Architecture](../architecture/things-integration.md), [Phase 7 Roadmap](../roadmap/08-PHASE-7-THINGS.md)

---

## Overview

This document captures user stories for the Things 3 integration with Selene. Stories are organized by implementation phase and follow the format:

```
As a [user type],
I want to [action],
So that [benefit].
```

Each story includes:
- **Acceptance Criteria**: Testable requirements
- **ADHD Optimization**: How this helps ADHD executive function
- **Technical Notes**: Implementation considerations
- **Priority**: Phase assignment

---

## Phase 7.1: Task Extraction Foundation

### Story 1.1: Auto-Extract Tasks from Voice Notes

**As an** ADHD user who captures ideas via voice notes,
**I want** tasks automatically extracted and created in Things,
**So that** I don't have to remember or manually process my capture dump.

**Acceptance Criteria:**
- ✅ When I send a voice note from Drafts that contains action items
- ✅ Selene processes the note and identifies actionable tasks
- ✅ Tasks appear in my Things inbox within 2 minutes
- ✅ Task titles are clear and action-oriented (verb-first)
- ✅ Original note content is linked in task notes field

**ADHD Optimization:**
- **Externalizes working memory**: No need to remember what needs doing
- **Reduces decision fatigue**: No "should I create a task?" decisions
- **Captures hyperfocus**: Record ideas without breaking flow

**Technical Notes:**
- LLM prompt must extract verb-first task descriptions
- Handle multiple tasks per note
- Link back to raw_note_id in task_metadata table
- Store Things task ID for bi-directional tracking

**Priority:** 🔥 Phase 7.1 - Critical

---

### Story 1.2: Energy Level Assignment

**As an** ADHD user with variable energy throughout the day,
**I want** tasks tagged with required energy level (high/medium/low),
**So that** I can match tasks to my current energy state.

**Acceptance Criteria:**
- ✅ Every auto-created task has an energy_required field
- ✅ Energy assignment is based on task complexity and note's energy_level
- ✅ Energy is visible in Things task notes ("Energy: high")
- ✅ SeleneChat displays energy with emoji indicators (⚡🔋🪫)

**ADHD Optimization:**
- **Accommodates energy fluctuations**: Work with your brain, not against it
- **Prevents overwhelm**: Don't attempt high-energy tasks when depleted
- **Enables strategic planning**: Schedule tasks for optimal energy times

**Example Scenarios:**
- Note: "I'm excited to redesign the website!" (energy_level: high)
  → Task: "Create website redesign mockups" (energy_required: high)

- Note: "Ugh, I need to organize my files" (energy_level: low)
  → Task: "Sort downloads folder" (energy_required: low)

**Technical Notes:**
- Derive from processed_notes.energy_level
- LLM considers task complexity (creative > routine, learning > executing)
- Store in task_metadata.energy_required
- Display in SeleneChat with visual indicators

**Priority:** 🔥 Phase 7.1 - Critical

---

### Story 1.3: Time Estimation

**As an** ADHD user with time blindness,
**I want** realistic time estimates for each task,
**So that** I can plan my day without over-committing.

**Acceptance Criteria:**
- ✅ Every task includes estimated_minutes (5, 15, 30, 60, 120, 240)
- ✅ Estimates are based on task type and past completion patterns
- ✅ Visible in Things notes ("Est: 30 min")
- ✅ Over time, estimates improve based on actual completion time

**ADHD Optimization:**
- **Makes time visible**: Combat time blindness with concrete numbers
- **Prevents over-scheduling**: See total time commitment before committing
- **Learns from patterns**: System gets smarter as you complete tasks

**Example Scenarios:**
- Task: "Write blog post" → 120 minutes (creative, high-energy)
- Task: "Reply to email" → 5 minutes (routine, low-energy)
- Task: "Research new tool" → 30 minutes (learning, medium-energy)

**Technical Notes:**
- LLM provides initial estimates based on task type
- Store in task_metadata.estimated_minutes
- Phase 7.4: Compare estimated vs. actual (completion_time - created_at)
- Adjust future estimates based on user's patterns

**Priority:** 🔥 Phase 7.1 - Critical

---

### Story 1.4: Overwhelm Factor Tracking

**As an** ADHD user who experiences task paralysis,
**I want** tasks tagged with an overwhelm factor (1-10),
**So that** I can identify and break down overwhelming tasks.

**Acceptance Criteria:**
- ✅ Each task has overwhelm_factor between 1-10
- ✅ Factor considers task complexity, vagueness, and emotional weight
- ✅ Tasks with overwhelm > 7 are flagged for review
- ✅ High overwhelm tasks trigger "break it down" suggestions

**ADHD Optimization:**
- **Identifies blockers**: Spot tasks that will cause procrastination
- **Prompts intervention**: Suggests breaking down before you get stuck
- **Emotional awareness**: Acknowledges that tasks have emotional cost

**Example Scenarios:**
- Task: "Clean desk" (overwhelm: 3) - Clear, concrete action
- Task: "Plan project" (overwhelm: 8) - Vague, many decisions, high stakes
- Task: "Call dentist" (overwhelm: 6) - Simple but emotionally difficult

**Technical Notes:**
- LLM analyzes task clarity, scope, and emotional tone
- Store in task_metadata.overwhelm_factor
- Phase 7.4: Trigger intervention workflow for overwhelm > 7
- Learn from user: if tasks stay incomplete long-term, increase overwhelm_factor

**Priority:** 🟡 Phase 7.1 - Important

---

### Story 1.5: No Duplicate Task Creation

**As a** user who sometimes manually creates tasks,
**I want** Selene to detect existing similar tasks in Things,
**So that** I don't end up with duplicate entries.

**Acceptance Criteria:**
- ✅ Before creating task, Selene searches Things for similar titles (fuzzy match)
- ✅ If 80%+ match found, skip creation and link to existing task
- ✅ User is notified: "Linked to existing task: [title]"
- ✅ task_metadata stores existing things_task_id

**ADHD Optimization:**
- **Reduces clutter**: Less noise in task manager
- **Prevents confusion**: Clear which task to work on
- **Respects manual capture**: Doesn't interfere with user's workflow

**Technical Notes:**
- Use Things MCP search before creating
- Fuzzy string matching (Levenshtein distance < 20%)
- If found: just create task_metadata entry, don't create new task
- Log skipped duplicates for user review

**Priority:** 🟡 Phase 7.1 - Important

---

## Phase 7.2: Project Detection

### Story 2.1: Auto-Create Projects from Concept Clusters

**As an** ADHD user with multiple ongoing interests,
**I want** related notes and tasks automatically grouped into Things projects,
**So that** I don't have to manually organize my growing task list.

**Acceptance Criteria:**
- ✅ When 3+ notes share a primary concept, system suggests project creation
- ✅ Project name is derived from concept + LLM interpretation
- ✅ Related tasks are automatically moved to the project in Things
- ✅ User can review and rename before final creation (future: approval workflow)

**ADHD Optimization:**
- **Automatic organization**: No decision fatigue about categorization
- **Object permanence**: Related items stay visible together
- **Visual hierarchy**: See "big picture" without manual mind-mapping

**Example Scenarios:**
- Concept: "web-design" (5 notes) → Project: "Website Redesign"
- Concept: "book-writing" (8 notes) → Project: "Write Technical Book"
- Concept: "home-improvement" (4 notes) → Project: "Kitchen Renovation"

**Technical Notes:**
- Daily workflow 08 runs clustering analysis
- LLM prompt: "Given these notes, is this a cohesive project?"
- Create Things project via MCP
- Move tasks by updating things_project_id in task_metadata
- Store in project_metadata table

**Priority:** 🔥 Phase 7.2 - Critical

---

### Story 2.2: Project Energy Profile

**As an** ADHD user with limited high-energy time,
**I want** to see the overall energy profile of each project,
**So that** I can assess if a project fits my current capacity.

**Acceptance Criteria:**
- ✅ Each project has energy profile: "high-energy", "mixed", or "low-energy"
- ✅ Profile calculated from all tasks' energy_required values
- ✅ Visible in project_metadata and SeleneChat
- ✅ Helps with project selection: "Can I sustain this project now?"

**ADHD Optimization:**
- **Strategic project selection**: Don't start high-energy projects during burnout
- **Realistic planning**: See total energy commitment upfront
- **Balance management**: Mix high/low energy projects

**Example Scenarios:**
- Project: "Learn Piano" (10 tasks, 8 high-energy, 2 medium) → "high-energy"
- Project: "Organize Photos" (15 tasks, 12 low-energy, 3 medium) → "low-energy"
- Project: "Launch Product" (20 tasks, mixed) → "mixed"

**Technical Notes:**
- Calculate from task_metadata.energy_required distribution
- Store in project_metadata.project_energy_profile
- Recalculate when tasks added/completed
- Display in SeleneChat with visual indicator

**Priority:** 🟢 Phase 7.2 - Nice-to-have

---

### Story 2.3: Project Time Estimation

**As an** ADHD user who underestimates project scope (planning fallacy),
**I want** to see total estimated time for project completion,
**So that** I can make realistic commitments.

**Acceptance Criteria:**
- ✅ Project shows sum of all task estimated_minutes
- ✅ Displayed as "Est. total: 6h 30m"
- ✅ Visible in Things project notes and SeleneChat
- ✅ Updates as tasks are added/completed

**ADHD Optimization:**
- **Combats planning fallacy**: See real scope, not optimistic guess
- **Prevents over-commitment**: "Oh, this is a 20-hour project, not 2 hours"
- **Progress tracking**: See time remaining decrease

**Example Scenarios:**
- Project: "Write Blog Post" (3 tasks: research 30m, draft 120m, edit 30m) → "3h total"
- Project: "Home Office Setup" (12 tasks totaling 540m) → "9h total"

**Technical Notes:**
- Sum task_metadata.estimated_minutes where things_project_id matches
- Store in project_metadata.estimated_total_time
- Recalculate on task add/complete via workflow 08
- Display in SeleneChat and Things notes

**Priority:** 🟡 Phase 7.2 - Important

---

## Phase 7.3: SeleneChat Display

### Story 3.1: View Related Tasks in Note Detail

**As a** SeleneChat user reviewing my notes,
**I want** to see tasks created from each note,
**So that** I can track what actions came from my thoughts.

**Acceptance Criteria:**
- ✅ Note detail view includes "Related Tasks" section
- ✅ Shows task title, status (complete/incomplete), and energy level
- ✅ Real-time status from Things (not stale cache)
- ✅ "Open in Things" button for each task

**ADHD Optimization:**
- **Object permanence**: See tasks in context of original thought
- **Bi-directional navigation**: Note → Task → Note
- **Visual reinforcement**: Completed tasks provide dopamine feedback

**UI Mockup:**
```
┌─────────────────────────────────────────┐
│ Note: "Excited about website redesign"  │
│ Nov 15, 2025 • 🎨 creative              │
│                                          │
│ [Note content here...]                   │
│                                          │
├─────────────────────────────────────────┤
│ Related Tasks (2)                        │
│ ○ Create design mockups      ⚡ High     │
│   [Open in Things]                       │
│ ○ Research competitor sites  🔋 Medium   │
│   [Open in Things]                       │
└─────────────────────────────────────────┘
```

**Technical Notes:**
- Query task_metadata by raw_note_id
- Fetch current status from Things MCP (async)
- Cache for 5 minutes to reduce API calls
- Deep link: `things:///show?id={things_task_id}`

**Priority:** 🔥 Phase 7.3 - Critical

---

### Story 3.2: Filter Tasks by Energy Level

**As an** ADHD user with variable energy,
**I want** to filter all my tasks by energy level,
**So that** I can quickly find tasks matching my current state.

**Acceptance Criteria:**
- ✅ SeleneChat has "Tasks" tab with energy filters
- ✅ Filter buttons: ⚡ High / 🔋 Medium / 🪫 Low / All
- ✅ Shows task count for each energy level
- ✅ Clicking filter shows matching tasks across all notes

**ADHD Optimization:**
- **Energy-aware planning**: "I'm low-energy, show me easy tasks"
- **Quick decision-making**: No scrolling through irrelevant tasks
- **Visual scanning**: Emoji indicators enable fast pattern recognition

**UI Mockup:**
```
┌─────────────────────────────────────────┐
│ Tasks                                    │
│ ┌──────────────────────────────────────┐│
│ │ ⚡ High (5) 🔋 Medium (12) 🪫 Low (8) ││
│ └──────────────────────────────────────┘│
│                                          │
│ 🪫 Low Energy Tasks (8)                  │
│ ○ Sort email inbox          Est: 15m    │
│ ○ File expense receipts     Est: 10m    │
│ ○ Update task tags          Est: 5m     │
│ ...                                      │
└─────────────────────────────────────────┘
```

**Technical Notes:**
- New TasksView in SeleneChat
- Query task_metadata grouped by energy_required
- Join with Things MCP for current status
- Filter incomplete tasks only (or toggle for completed)

**Priority:** 🟡 Phase 7.3 - Important

---

### Story 3.3: Project View with Task List

**As a** user working on a specific project,
**I want** to see all project notes and tasks in one view,
**So that** I have full context without switching between apps.

**Acceptance Criteria:**
- ✅ SeleneChat shows Projects list (from project_metadata)
- ✅ Clicking project shows: notes, tasks, energy profile, time estimate
- ✅ Tasks grouped by status (incomplete / completed)
- ✅ Can navigate to source notes

**ADHD Optimization:**
- **Unified context**: Everything related in one place
- **Visual project mind-map**: See structure without building it manually
- **Progress visibility**: Completed tasks provide motivation

**UI Mockup:**
```
┌─────────────────────────────────────────┐
│ Project: Website Redesign               │
│ 🔋 Mixed Energy • Est: 8h 30m           │
│                                          │
│ Tasks (3 incomplete, 2 completed)       │
│ ○ Create design mockups      ⚡ Est: 2h  │
│ ○ Research competitors       🔋 Est: 30m │
│ ○ Set up dev environment     🪫 Est: 1h  │
│ ✓ Gather requirements        🔋 Est: 1h  │
│ ✓ Create project folder      🪫 Est: 5m  │
│                                          │
│ Related Notes (5)                        │
│ • Excited about website redesign         │
│ • Competitor analysis notes              │
│ ...                                      │
└─────────────────────────────────────────┘
```

**Technical Notes:**
- New ProjectView in SeleneChat
- Query project_metadata for project list
- Join task_metadata + Things MCP for tasks
- Join raw_notes via note_project_links (future table)

**Priority:** 🟢 Phase 7.3 - Nice-to-have

---

## Phase 7.4: Status Sync & Pattern Analysis

### Story 4.1: Task Completion Tracking

**As a** user completing tasks in Things,
**I want** Selene to detect completion automatically,
**So that** my progress is reflected across both systems.

**Acceptance Criteria:**
- ✅ Hourly sync checks task status via Things MCP
- ✅ When task completed in Things, completed_at timestamp stored in task_metadata
- ✅ SeleneChat shows checkmark on completed tasks
- ✅ Completed tasks remain visible but grayed out

**ADHD Optimization:**
- **Dopamine feedback**: See completed tasks accumulate
- **Progress visibility**: Visual proof of accomplishment
- **Pattern analysis foundation**: Data for learning optimal strategies

**Technical Notes:**
- Workflow 09 runs hourly
- Query Things MCP get-todo for each things_task_id
- Update task_metadata.completed_at if status changed
- Trigger pattern analysis workflow

**Priority:** 🔥 Phase 7.4 - Critical

---

### Story 4.2: Energy Accuracy Analysis

**As an** ADHD user whose energy fluctuates unpredictably,
**I want** Selene to learn which energy assignments are accurate,
**So that** future task estimates match reality.

**Acceptance Criteria:**
- ✅ System compares estimated energy vs. actual completion patterns
- ✅ If high-energy tasks consistently completed during low-energy note times, adjust
- ✅ Confidence score increases over time as data accumulates
- ✅ Insights visible: "You complete 'writing' tasks best in afternoons"

**ADHD Optimization:**
- **Personalized learning**: System adapts to YOUR energy patterns, not generic advice
- **Removes guesswork**: Data-driven energy predictions
- **Validates experience**: "I'm not lazy, I'm just low-energy right now"

**Example Scenarios:**
- Pattern: High-energy tasks created at 2pm consistently completed → "Afternoons are your high-energy time"
- Pattern: "Email" tasks tagged high-energy but completed quickly → Adjust future emails to medium
- Pattern: "Writing" tasks take 2x estimated time → Increase time estimates

**Technical Notes:**
- Compare task_metadata.energy_required vs. raw_notes.energy_level at completion
- Store patterns in detected_patterns table
- Use for future LLM prompts: "User typically completes X type tasks in Y energy state"
- Display insights in SeleneChat dashboard (future)

**Priority:** 🟡 Phase 7.4 - Important

---

### Story 4.3: Time Estimation Calibration

**As an** ADHD user with time blindness and planning fallacy,
**I want** Selene to learn my actual completion times,
**So that** estimates become realistic, not optimistic.

**Acceptance Criteria:**
- ✅ System calculates actual completion time (completed_at - created_at)
- ✅ Compares to estimated_minutes
- ✅ Adjusts future estimates for similar task types
- ✅ Shows calibration progress: "Estimates now 85% accurate"

**ADHD Optimization:**
- **Combats planning fallacy**: Stop underestimating task duration
- **Realistic scheduling**: Don't commit to 8 hours of work in 4 hours
- **Self-awareness**: "Writing takes me longer than I think"

**Example Scenarios:**
- Task: "Write blog post" (Est: 60m, Actual: 120m) → Future blog posts: 120m
- Task: "Email reply" (Est: 15m, Actual: 5m) → Future emails: 5-10m
- Task: "Research tool" (Est: 30m, Actual: 90m) → Future research: 60-90m

**Technical Notes:**
- Calculate: (completed_at - created_at) in minutes
- Group by task_type and context_tags
- Store rolling average in detected_patterns
- Apply to LLM prompt: "User's 'writing' tasks average 90 minutes"

**Priority:** 🟡 Phase 7.4 - Important

---

### Story 4.4: Overwhelm Early Warning

**As an** ADHD user prone to burnout,
**I want** Selene to detect when I'm accumulating too many high-overwhelm tasks,
**So that** I can course-correct before hitting a wall.

**Acceptance Criteria:**
- ✅ System tracks average overwhelm_factor over time
- ✅ If average rises above threshold (e.g., 6.5), trigger alert
- ✅ Notification: "You have 5 high-overwhelm tasks. Consider breaking them down."
- ✅ Suggests tasks to postpone or simplify

**ADHD Optimization:**
- **Prevents burnout**: Catch overwhelm before it becomes paralysis
- **Proactive intervention**: Address problem while still manageable
- **Self-compassion**: System validates that tasks ARE overwhelming, not "just me"

**Example Scenarios:**
- Scenario: 5 tasks with overwhelm > 7 created in past 3 days
  → Alert: "High overwhelm detected. Let's review these tasks."

- Scenario: Task "Plan conference" (overwhelm: 9) incomplete for 2 weeks
  → Suggestion: "This task seems stuck. Break it into smaller steps?"

**Technical Notes:**
- Daily pattern detection workflow
- Calculate: avg(overwhelm_factor) for incomplete tasks
- Check: tasks with overwhelm > 7 AND created_at > 2 weeks ago
- Trigger: STOP & PIVOT workflow (future ADHD feature)
- Display in SeleneChat as gentle notification

**Priority:** 🟢 Phase 7.4 - Nice-to-have

---

## Future Stories (Post-Phase 7)

### Story F.1: Time Blocking Assistant

**As an** ADHD user who needs structured time,
**I want** Selene to suggest when to work on tasks based on my calendar,
**So that** I can plan realistically without over-scheduling.

**ADHD Optimization:** Makes time visible, prevents over-commitment

**Priority:** 🔵 Future (Phase 8)

---

### Story F.2: Daily Planning Ritual

**As an** ADHD user who needs daily reset,
**I want** a morning planning prompt that shows today's tasks + energy forecast,
**So that** I start the day with clarity and realistic expectations.

**ADHD Optimization:** Reduces morning decision fatigue, provides structure

**Priority:** 🔵 Future (Phase 8)

---

### Story F.3: Evening Reflection

**As an** ADHD user who needs closure,
**I want** an evening prompt to review completed tasks and set tomorrow's intention,
**So that** I can celebrate wins and plan without anxiety.

**ADHD Optimization:** Dopamine from acknowledgment, reduces rumination

**Priority:** 🔵 Future (Phase 8)

---

### Story F.4: "What Should I Work On Now?"

**As an** ADHD user struggling to choose next task,
**I want** a "moment view" that suggests the optimal task for right now,
**So that** I can start working without analysis paralysis.

**ADHD Optimization:** Eliminates decision fatigue, provides clear next action

**Priority:** 🔵 Future (Phase 8)

---

### Story F.5: Hyperfocus Capture Mode

**As an** ADHD user in hyperfocus,
**I want** quick task capture without leaving current app,
**So that** I don't break flow but still capture ideas.

**ADHD Optimization:** Respects hyperfocus, captures without interruption

**Priority:** 🔵 Future (Phase 9)

---

## Validation & Testing

### User Acceptance Criteria

**For Phase 7.1 Success:**
- [ ] 5 test notes with action items → all tasks created correctly
- [ ] Energy levels match user's intuition 80%+ of time
- [ ] Time estimates within 50% of actual (phase 1, will improve)
- [ ] Zero duplicate tasks created
- [ ] User reports: "This saves me mental load"

**For Phase 7.2 Success:**
- [ ] 3+ notes with shared concept → project auto-created
- [ ] Project name makes sense to user (90%+ approval)
- [ ] Tasks correctly assigned to projects
- [ ] Energy profile calculation is accurate
- [ ] User reports: "My tasks feel more organized"

**For Phase 7.3 Success:**
- [ ] Related tasks visible in note detail view
- [ ] Task status accurate and up-to-date
- [ ] "Open in Things" deep linking works
- [ ] UI loads in <200ms
- [ ] User reports: "I can see my tasks in context"

**For Phase 7.4 Success:**
- [ ] Task completion detected within 5 minutes
- [ ] Pattern insights are actionable and accurate
- [ ] Time estimates improve over 2 weeks of use
- [ ] Overwhelm alerts are helpful, not annoying
- [ ] User reports: "The system understands my patterns"

### ADHD-Specific Testing

**Executive Function Support:**
- [ ] Can user capture thoughts without deciding if they're tasks?
- [ ] Does auto-extraction reduce cognitive load?
- [ ] Is manual organization still needed?

**Energy Management:**
- [ ] Do energy levels help with task selection?
- [ ] Can user easily find appropriate tasks for current state?
- [ ] Does pattern analysis improve energy predictions?

**Time Visibility:**
- [ ] Do time estimates help with planning?
- [ ] Can user see total project time commitment?
- [ ] Does learning improve estimate accuracy?

**Emotional Regulation:**
- [ ] Does overwhelm factor help identify stuck tasks?
- [ ] Are early warnings helpful or anxiety-inducing?
- [ ] Does system provide compassionate framing?

---

## Related Documentation

- [Things Integration Architecture](../architecture/things-integration.md)
- [Phase 7 Roadmap](../roadmap/08-PHASE-7-THINGS.md)
- [ADHD Principles](../../.claude/ADHD_Principles.md)
- [First Implementation Spec](../plans/auto-create-tasks-from-notes.md)

---

**Document Status:** ✅ Ready for Review
**Next Step:** Prioritize stories for Phase 7.1 implementation
**Owner:** Chase Easterling
**Last Updated:** 2025-11-24