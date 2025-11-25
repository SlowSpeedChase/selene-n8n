# ADHD Features Integration Discussion

**Status:** Planning / Discussion Document
**Created:** 2025-11-24
**Purpose:** Deep dive into ADHD Principles integration with Selene + Things
**Use:** Start new Claude session with this document for focused ADHD feature planning

---

## Document Purpose

This document bridges the gap between:
1. The comprehensive ADHD Task Management specification ([ADHD_Principles.md](../../.claude/ADHD_Principles.md))
2. The working Selene production system (note processing + Obsidian export)
3. The planned Things integration (Phase 7)

**How to use this document:**
- Start a new Claude Code session
- Reference this document + ADHD_Principles.md
- Work through each section systematically
- Design specific implementations for each ADHD principle
- Create detailed specs for features not covered in Phase 7

---

## Overview: ADHD Principles Framework

The original ADHD spec defines a **3-step process**:

### 1. CAPTURE (The Dumpster)
- Single collection point for all thoughts
- O.H.I.O. Principle: Only Hold It Once
- No organization at capture stage
- Reduces decision fatigue

### 2. ORGANIZE (Mind-Maps)
- WTF Mind-Map: What needs to be done
- Project Mind-Map: How to accomplish tasks
- Visual/spatial interface (not list-based)
- Shows hierarchy and priorities

### 3. PLAN (Making Time Visible)
- Monthly View: Calendar with deadlines
- Weekly View: Structured vs. unstructured time
- Daily View: Hour-by-hour breakdown
- Moment View: Current focus tracker/bookmark

---

## Current State Analysis

### What Selene Already Does (ADHD-Aligned)

**✅ Capture:**
- Drafts app provides frictionless voice/text capture
- Webhook ingestion = instant processing (no manual "save" decisions)
- Stream-of-consciousness notes accepted without structure
- **ADHD Win:** Perfect "dumpster" - capture without organizing

**✅ Automatic Organization:**
- Concepts and themes extracted automatically (no manual tagging)
- Multiple Obsidian paths (By-Concept, By-Theme, By-Energy, Timeline)
- Visual indicators (emoji) for quick scanning
- **ADHD Win:** Externalizes categorization decisions

**✅ Energy Awareness:**
- Energy level tracked (high ⚡ / medium 🔋 / low 🪫)
- ADHD markers detected (overwhelm 🧠, hyperfocus 🎯, exec-dysfunction ⚠️)
- Sentiment and emotional tone captured
- **ADHD Win:** Makes invisible internal states visible

**✅ Object Permanence:**
- All notes stored in searchable database
- Multiple views in Obsidian prevent "out of sight, out of mind"
- Concept hub pages aggregate related notes
- **ADHD Win:** Nothing gets lost

### What's Missing (Gaps)

**❌ Task Management:**
- Action items extracted but not stored structurally
- No tracking of task completion
- No prioritization or energy-based task selection
- **Gap:** Can't act on insights

**❌ Project Hierarchy:**
- Notes clustered by concept, but not organized into projects
- No "Project Mind-Maps" with center → branches structure
- Can't see "big picture" of multi-note projects
- **Gap:** Missing visual project structure

**❌ Time Visibility:**
- Timestamps exist but no calendar/time-blocking views
- Can't see structured vs. unstructured time
- No time estimates for tasks
- **Gap:** Time blindness not addressed

**❌ Planning Views:**
- No monthly/weekly/daily/moment views
- No "what should I work on now?" guidance
- No capacity planning (total time vs. available time)
- **Gap:** Requires external planning still

**❌ Emotional Regulation Features:**
- Sentiment tracked but no proactive interventions
- No daily check-ins or prompts
- No STOP & PIVOT technique integration
- No evening ritual or mindfulness support
- **Gap:** Detection without intervention

**❌ Procrastination Management:**
- No tracking of task resistance or "stuck" indicators
- No reframe suggestions
- No overwhelm → action breakdown
- **Gap:** Can detect overwhelm but doesn't help

---

## Integration Strategy: Selene + Things + ADHD Principles

### Architecture Vision

```
┌─────────────────────────────────────────────────────────┐
│                  CAPTURE LAYER                          │
│  Drafts (Voice/Text) → Selene → "The Dumpster"        │
│  • No decisions required                                │
│  • Instant ingestion                                    │
│  • O.H.I.O. Principle enforced                         │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│               ORGANIZE LAYER                            │
│  Selene (Ollama) → Automatic Intelligence              │
│  • Concepts & Themes (WTF Mind-Map structure)          │
│  • Energy & ADHD Markers                                │
│  • Task Extraction                                      │
│  • Project Detection (Project Mind-Maps)               │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│              PLAN LAYER (Things + SeleneChat)           │
│  Things 3 → Task Management                             │
│  • Inbox (captured tasks)                               │
│  • Projects (mind-map structure)                        │
│  • Today / This Evening / Upcoming                      │
│  • Areas for life domains                               │
│                                                          │
│  SeleneChat → Planning Interface                        │
│  • Monthly View: Projects + deadlines                   │
│  • Weekly View: Structured vs. unstructured time        │
│  • Daily View: Hour-by-hour with energy forecast        │
│  • Moment View: "What should I work on now?"           │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│           EMOTIONAL REGULATION LAYER                    │
│  • Daily check-ins (3-4x per day)                       │
│  • Overwhelm detection → STOP & PIVOT                   │
│  • Evening ritual (gratitude + intention)               │
│  • RSD support and reframe suggestions                  │
└─────────────────────────────────────────────────────────┘
```

---

## Feature Mapping: ADHD Spec → Implementation

### Section 1: The Capture System

#### ADHD Principle: "The Dumpster"

**From Spec:**
> Single collection point. Voice notes, text notes, random thoughts—all go into ONE place. No organizing at this stage. Brain dump only.

**Current Implementation:**
- ✅ Drafts app = single entry point
- ✅ No organization required at capture
- ✅ Voice and text both supported

**Phase 7 Enhancement:**
- ✅ Tasks auto-extracted = truly "only hold it once"
- ✅ User doesn't even decide if something is a task

**Future Enhancement Needed:**
- 📋 **SeleneChat Quick Capture**: Capture directly from SeleneChat app
- 📋 **Apple Shortcuts Integration**: "Hey Siri, add to dumpster"
- 📋 **Notification-Based Capture**: Timed prompts for check-ins

**Discussion Questions:**
1. Should SeleneChat have a quick-capture text field always visible?
2. Should there be audio recording in SeleneChat (iOS/macOS mic access)?
3. How to handle captures during hyperfocus without breaking flow?
4. Should there be a "panic dump" mode for overwhelming moments?

---

#### ADHD Principle: O.H.I.O. (Only Hold It Once)

**From Spec:**
> Process items once when you interact with them, rather than revisiting repeatedly.

**Current Implementation:**
- ✅ Notes auto-processed on arrival (no re-processing needed)
- ✅ Concepts/themes extracted once

**Phase 7 Enhancement:**
- ✅ Tasks created automatically = no "I'll make a task later" backlog

**Gap:**
- ❌ Daily review of tasks might violate O.H.I.O. if not careful
- ❌ Need "process once, reference many" pattern

**Future Enhancement Needed:**
- 📋 **Task Triage Workflow**: First time task appears, user makes all decisions (priority, when, project)
- 📋 **Smart Defaults**: System suggests decisions so user can one-tap accept
- 📋 **"Never Show Again" Option**: For tasks that don't need doing

**Discussion Questions:**
1. How to balance O.H.I.O. with task review/planning rituals?
2. Should initial task extraction include a one-time "approval" step?
3. How to handle tasks that need more context before scheduling?

---

### Section 2: The Organize System

#### ADHD Principle: WTF Mind-Map (What needs to be done)

**From Spec:**
> Central node: Your focus area or life domain
> Branches: Categories of tasks
> Sub-branches: Specific tasks
> Visual, spatial, shows hierarchy

**Current Implementation:**
- ⚠️ **Partial**: Concept hub pages in Obsidian show task clustering
- ⚠️ **Partial**: By-Concept organization creates implicit hierarchy

**Phase 7 Enhancement:**
- ✅ Projects in Things can have checklist items (sub-tasks)
- ✅ Areas in Things map to life domains
- ⚠️ **Limited**: Things is list-based, not visual mind-map

**Gap:**
- ❌ No visual mind-map interface
- ❌ Can't see spatial relationships
- ❌ Hierarchy exists but not visualized

**Future Enhancement Needed:**
- 📋 **SeleneChat Mind-Map View**: Generate visual mind-maps from project structure
- 📋 **Mermaid Diagram Generation**: Export Things projects as mermaid diagrams
- 📋 **Interactive Graph**: Click nodes to navigate, expand/collapse branches
- 📋 **Export to Obsidian Canvas**: Create .canvas files for manual editing

**Visual Mockup Needed:**
```
                    [Web Development]
                           |
        ┌─────────────────┼─────────────────┐
        │                 │                 │
    [Client Work]    [Learning]        [Tools Setup]
        │                 │                 │
    • Build site      • React course    • Configure IDE
    • Design review   • CSS practice    • Install packages
    • Client call     • Tutorial        • Set up repo
```

**Discussion Questions:**
1. Should mind-maps be auto-generated or manual?
2. How to handle tasks that belong to multiple branches?
3. Should Obsidian Canvas integration be primary view?
4. What's the update frequency (real-time vs. daily regeneration)?

---

#### ADHD Principle: Project Mind-Maps (How to accomplish)

**From Spec:**
> One mind-map per active project
> Shows all steps, dependencies, progress
> Visual structure prevents overwhelm

**Current Implementation:**
- ❌ **Missing**: No project-specific mind-maps exist

**Phase 7 Enhancement:**
- ✅ Things projects group related tasks
- ✅ Checklists provide sub-task structure
- ⚠️ **Limited**: Still list-based, not visual

**Gap:**
- ❌ No visualization of project structure
- ❌ Can't see dependencies or flow
- ❌ No progress visualization beyond checkmarks

**Future Enhancement Needed:**
- 📋 **Project Canvas Generation**:
  ```
  Project: Website Redesign
      ↓
  [Research] → [Design] → [Development] → [Launch]
      |            |            |              |
  3 tasks      5 tasks      8 tasks        2 tasks
  ✓✓✓          ✓✓○○○        ○○○○○○○○       ○○
  ```

- 📋 **Dependency Tracking**: Mark which tasks block others
- 📋 **Progress Rings**: Circular progress indicators (ADHD-friendly)
- 📋 **Time Visualization**: Show estimated time per branch

**Discussion Questions:**
1. How to represent dependencies in Things (which doesn't support them natively)?
2. Should Selene store dependency metadata even if Things doesn't?
3. How to visualize "stuck" tasks (no progress in X days)?
4. Should there be a "simplified" vs. "detailed" project view toggle?

---

#### ADHD Principle: Visual Over Lists

**From Spec:**
> ADHD brains process visual/spatial information better than linear lists.
> Use colors, shapes, positions instead of text-only lists.

**Current Implementation:**
- ✅ **Good**: Obsidian uses emoji indicators (⚡🔋🪫🧠🎯)
- ✅ **Good**: Multiple organization paths prevent single-list fatigue

**Phase 7 Enhancement:**
- ⚠️ **Regression**: Things is list-based
- ⚠️ Things tags can use emoji but lists are still linear

**Gap:**
- ❌ SeleneChat currently list-based
- ❌ No spatial task representation
- ❌ No color coding beyond emoji

**Future Enhancement Needed:**
- 📋 **SeleneChat Kanban View**:
  ```
  ┌────────────┬────────────┬────────────┬────────────┐
  │  Inbox     │  Today     │  Later     │  Completed │
  │            │            │            │            │
  │  [Task A]  │  [Task B]  │  [Task E]  │  [Task X]  │
  │   ⚡ 2h    │   🔋 30m   │   🪫 15m   │   ✓       │
  │            │            │            │            │
  │  [Task C]  │  [Task D]  │            │  [Task Y]  │
  │   🔋 1h    │   ⚡ 3h    │            │   ✓       │
  └────────────┴────────────┴────────────┴────────────┘
  ```

- 📋 **Energy-Based Color Coding**:
  - High-energy tasks: Red/orange background
  - Medium-energy: Yellow background
  - Low-energy: Green/blue background

- 📋 **Size-Based Visual Weight**:
  - Longer tasks = physically larger cards
  - Makes time commitment visible at a glance

**Discussion Questions:**
1. Should SeleneChat replace Things as primary interface, or complement it?
2. How to sync visual changes (drag-and-drop) back to Things?
3. Should there be a "list view" toggle for users who prefer lists?
4. How to make kanban work on iOS (small screen)?

---

### Section 3: The Planning System

#### ADHD Principle: Making Time Visible

**From Spec:**
> Time blindness is a core ADHD challenge. Make abstract time concrete and visible.

**Current Implementation:**
- ❌ **Missing**: No calendar integration
- ❌ **Missing**: No time visibility features

**Phase 7 Enhancement:**
- ✅ Task time estimates stored (estimated_minutes)
- ✅ Project total time calculated

**Gap:**
- ❌ Can't see time on calendar
- ❌ Can't visualize structured vs. unstructured time
- ❌ No "how much time do I have?" view

**Future Enhancement Needed:**

**Monthly View:**
```
November 2025
┌────┬────┬────┬────┬────┬────┬────┐
│ M  │ T  │ W  │ T  │ F  │ S  │ S  │
├────┼────┼────┼────┼────┼────┼────┤
│    │    │    │    │ 1  │ 2  │ 3  │
│    │    │    │    │    │🔴  │    │
├────┼────┼────┼────┼────┼────┼────┤
│ 4  │ 5  │ 6  │ 7  │ 8  │ 9  │10  │
│    │    │    │🔴  │    │    │    │
│    │    │    │DEADLINE│    │    │
└────┴────┴────┴────┴────┴────┴────┘

🔴 = Deadline
○ = Tasks scheduled
● = Tasks completed
```

**Weekly View (Critical for ADHD):**
```
Week of Nov 24-30

Monday 11/24                      Total: 4h available / 6h tasks ⚠️
├─ 9-11am:  [Meeting]  [STRUCTURED TIME - blocked]
├─ 11am-12pm: ⚡ UNSTRUCTURED (1h available)
│   Suggested: "Write blog post" (Est: 1h, High energy)
├─ 12-1pm:  [Lunch]
├─ 1-3pm:   ⚡ UNSTRUCTURED (2h available)
│   Suggested: "Client proposal" (Est: 2h, High energy)
├─ 3-4pm:   [Team sync]  [STRUCTURED TIME - blocked]
└─ 4-6pm:   🔋 UNSTRUCTURED (2h available, energy fading)
    Suggested: "Email responses" (Est: 30m, Medium energy)

Over-scheduled by 2 hours - suggest moving tasks to Tuesday
```

**Daily View:**
```
Today: Monday Nov 24
Current time: 2:45pm
Energy forecast: 🔋 Medium (declining)

Right Now (2:45pm):
└─ You're in unstructured time until 3pm (15min left)
   → Quick win: "Organize downloads" (Est: 10m, Low energy)

Next:
├─ 3:00pm: Team sync (1h structured)
└─ 4:00pm: Free until end of day
   → Good time for: "Email responses" (30m, matches energy)
```

**Moment View (What should I work on NOW?):**
```
Current Focus Bookmark

Time: 2:45pm
Energy: 🔋 Medium
Available time: 15 minutes until next meeting

RECOMMENDED TASK:
┌──────────────────────────────────────┐
│  Organize downloads folder           │
│  Est: 10 minutes                     │
│  Energy: 🪫 Low (good match!)        │
│  Project: Digital Declutter          │
│                                       │
│  [Start Task]  [Skip]  [Not Now]    │
└──────────────────────────────────────┘

Why this task?
• Fits in available time (10m < 15m)
• Matches or below your current energy
• Low overwhelm factor (3/10)
• Part of active project
```

**Discussion Questions:**
1. Should Selene read macOS Calendar for structured time, or manual entry?
2. How to handle unexpected interruptions (meeting goes long)?
3. Should energy forecast be based on historical patterns or manual input?
4. What happens when user ignores "moment view" suggestions repeatedly?
5. How to balance automation with user agency (don't be overbearing)?

---

#### ADHD Principle: Structured vs. Unstructured Time

**From Spec:**
> ADHD brains need to know:
> - What time is COMMITTED (meetings, appointments)
> - What time is AVAILABLE for task work
> Critical to prevent over-scheduling and planning fallacy

**Current Implementation:**
- ❌ **Missing**: No structured time tracking
- ❌ **Missing**: No calendar integration

**Phase 7 Enhancement:**
- ⚠️ Tasks created but not scheduled to specific times

**Gap:**
- ❌ Can't see capacity vs. commitments
- ❌ Can't detect over-scheduling
- ❌ Can't automatically suggest task scheduling

**Future Enhancement Needed:**

**Calendar Integration:**
- 📋 **Read macOS Calendar**: Import events as "structured time"
- 📋 **Things Calendar Events**: Import deadlines and scheduled tasks
- 📋 **Time Block Calculation**:
  ```sql
  -- Calculate unstructured time for a day
  SELECT
    date,
    (24 * 60) - SUM(event_duration_minutes) as unstructured_minutes
  FROM calendar_events
  WHERE date = ?
  GROUP BY date
  ```

**Over-Scheduling Detection:**
```javascript
// Detect planning fallacy
const totalTaskTime = tasks.reduce((sum, t) => sum + t.estimated_minutes, 0);
const availableTime = unstructuredMinutes;

if (totalTaskTime > availableTime * 0.8) {
  alert({
    type: 'over_scheduled',
    message: `You have ${totalTaskTime}min of tasks but only ${availableTime}min available.`,
    suggestion: 'Move some tasks to tomorrow or reduce scope.'
  });
}
```

**Smart Scheduling Suggestions:**
- 📋 **Energy-Time Matching**: Suggest high-energy tasks for morning if that's user's pattern
- 📋 **Buffer Time**: Auto-add 25% buffer to estimates (ADHD planning fallacy correction)
- 📋 **Break Reminders**: Suggest breaks between task blocks

**Discussion Questions:**
1. What's the threshold for "over-scheduled" alert (80%, 100%, 120%)?
2. Should buffer time be configurable or learned from patterns?
3. How to handle days with no structured time (risk of drift)?
4. Should there be a "realistic" vs. "optimistic" time mode toggle?

---

### Section 4: Emotional Regulation Features

#### ADHD Principle: Daily Thought Tracker

**From Spec:**
> Check in 3-4 times per day:
> - How am I feeling?
> - What's my energy level?
> - Any overwhelm signals?
> Helps catch emotional dysregulation early.

**Current Implementation:**
- ⚠️ **Partial**: Sentiment captured with notes
- ❌ **Missing**: No proactive prompts
- ❌ **Missing**: No dedicated check-in flow

**Phase 7 Enhancement:**
- ❌ **Not included**: No check-in features planned

**Gap:**
- ❌ No scheduled prompts
- ❌ No emotional tracking separate from notes
- ❌ No trend visualization

**Future Enhancement Needed:**

**Daily Check-In Workflow (new n8n workflow):**
```
Trigger: Scheduled at configurable times (e.g., 9am, 1pm, 4pm, 8pm)
│
├─ Send notification to macOS
│  "How are you feeling right now?"
│
├─ User opens SeleneChat check-in interface
│
├─ Quick form:
│  • Emotion picker (happy/calm/anxious/overwhelmed/frustrated)
│  • Energy slider (1-10)
│  • Optional note (voice or text)
│
├─ Store in daily_checkins table
│
└─ If overwhelm detected:
    └─ Trigger STOP & PIVOT workflow
```

**Database Schema:**
```sql
CREATE TABLE daily_checkins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    checkin_time TEXT NOT NULL,
    scheduled_time TEXT, -- When prompt was sent
    response_latency INTEGER, -- Minutes to respond (track avoidance)

    -- Emotional state
    emotions TEXT, -- JSON array: ["anxious", "motivated"]
    energy_level INTEGER CHECK(energy_level BETWEEN 1 AND 10),
    overwhelm_level INTEGER CHECK(overwhelm_level BETWEEN 1 AND 10),

    -- Optional context
    thoughts TEXT, -- Free-form note
    location TEXT, -- Home/office/other (for pattern analysis)

    -- Intervention applied
    reframe_applied TEXT, -- "STOP_PIVOT", "deep_breathing", etc.
    reframe_helpful BOOLEAN, -- User feedback

    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

**SeleneChat Check-In UI:**
```
┌────────────────────────────────────┐
│  Check-In (1:00pm)                 │
├────────────────────────────────────┤
│  How are you feeling?              │
│  [ ] 😊 Happy    [ ] 😌 Calm      │
│  [x] 😰 Anxious  [ ] 😤 Frustrated│
│  [ ] 🤯 Overwhelmed                │
│                                     │
│  Energy Level:                     │
│  ●●●●●○○○○○ (5/10)                 │
│                                     │
│  Overwhelm Level:                  │
│  ●●●●●●●○○○ (7/10)                 │
│                                     │
│  [Optional] What's on your mind?   │
│  [Voice note] [Text]               │
│                                     │
│  [Submit]                          │
└────────────────────────────────────┘

→ If overwhelm > 6: Show STOP & PIVOT prompt
```

**Discussion Questions:**
1. Should check-ins be push notifications or gentle in-app badges?
2. What if user consistently ignores check-ins? (Reduce frequency? Change time?)
3. Should there be a "snooze" option? (Risk of avoidance)
4. How to visualize check-in trends (daily graph, weekly average)?
5. Should check-ins pause during detected hyperfocus?

---

#### ADHD Principle: Evening Mindfulness Ritual

**From Spec:**
> End-of-day practice:
> 1. Gratitude: What went well today? (3 things)
> 2. Intention: What's important tomorrow? (1-3 things)
> Helps with closure, reduces anxiety, sets next-day priorities

**Current Implementation:**
- ❌ **Missing**: No evening ritual

**Future Enhancement Needed:**

**Evening Ritual Workflow:**
```
Trigger: Scheduled at configurable time (default: 8pm)
│
├─ Check: Has today's ritual been completed?
│  └─ If yes: Skip
│
├─ Send gentle reminder notification
│
├─ SeleneChat Evening Ritual View:
│
│  ┌──────────────────────────────────────┐
│  │  Evening Reflection 🌙               │
│  ├──────────────────────────────────────┤
│  │  Today you completed 5 tasks:        │
│  │  ✓ Write blog post                   │
│  │  ✓ Client meeting                    │
│  │  ✓ Email responses (12)              │
│  │  ✓ File receipts                     │
│  │  ✓ Review notes                      │
│  │                                       │
│  │  What went well today? (3 things)    │
│  │  1. [                            ]  │
│  │  2. [                            ]  │
│  │  3. [                            ]  │
│  │                                       │
│  │  What's important tomorrow?          │
│  │  (We suggest based on deadlines)     │
│  │  [x] Finish proposal (due Wed)       │
│  │  [x] Morning planning session        │
│  │  [ ] Team sync prep                  │
│  │                                       │
│  │  [Save & Rest]                       │
│  └──────────────────────────────────────┘
│
└─ Store in evening_rituals table
   Link to tomorrow's planning
```

**Database Schema:**
```sql
CREATE TABLE evening_rituals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ritual_date DATE NOT NULL,

    -- Gratitude
    gratitude_items TEXT, -- JSON array of 3 things

    -- Tomorrow's intentions
    intentions TEXT, -- JSON array of 1-3 task IDs or free text

    -- Auto-generated summary
    tasks_completed_count INTEGER,
    tasks_completed_ids TEXT, -- JSON array

    -- Completion tracking
    completed_at TEXT,
    skipped BOOLEAN DEFAULT 0,

    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

**Discussion Questions:**
1. Should ritual be optional or required (block other features until done)?
2. What if user completes ritual in the morning instead of evening?
3. Should gratitude items be saved to a long-term "wins" journal?
4. How to handle days with zero completed tasks (self-compassion needed)?
5. Should ritual include review of incomplete tasks (might trigger guilt)?

---

#### ADHD Principle: STOP & PIVOT Technique

**From Spec:**
> When overwhelm detected:
> S - Stop what you're doing
> T - Take 3 deep breaths
> O - Observe your thoughts without judgment
> P - Pivot to a different task, take a break, or simplify

**Current Implementation:**
- ⚠️ **Detection exists**: Overwhelm detected in sentiment analysis
- ❌ **No intervention**: System doesn't respond to detection

**Future Enhancement Needed:**

**Overwhelm Detection Triggers:**
1. Sentiment analysis shows overwhelm ADHD marker
2. Check-in reports overwhelm_level > 6
3. Task with overwhelm_factor > 7 reopened 3+ times
4. User creates >5 tasks in <10 minutes (panic planning)
5. Task incomplete for >14 days with high overwhelm_factor

**STOP & PIVOT Workflow:**
```
When overwhelm detected:
│
├─ Immediate pause notification:
│  "⚠️ Overwhelm detected. Let's STOP & PIVOT."
│
├─ SeleneChat STOP & PIVOT Interface:
│
│  ┌────────────────────────────────────┐
│  │  STOP & PIVOT 🛑                   │
│  ├────────────────────────────────────┤
│  │  It looks like you're feeling      │
│  │  overwhelmed. That's okay. Let's   │
│  │  take a moment.                    │
│  │                                     │
│  │  STOP ✋                            │
│  │  • Close other apps                │
│  │  • Step away from desk (optional)  │
│  │                                     │
│  │  TAKE 3 DEEP BREATHS 🫁            │
│  │  [Start guided breathing]          │
│  │  ○ ○ ○                             │
│  │                                     │
│  │  OBSERVE 👁️                        │
│  │  What's making this overwhelming?  │
│  │  [ ] Too many tasks                │
│  │  [ ] Task too big/vague            │
│  │  [ ] Don't know where to start     │
│  │  [ ] Afraid of failure             │
│  │  [ ] Other: [             ]       │
│  │                                     │
│  │  PIVOT 🔄                          │
│  │  Options:                          │
│  │  • [Break down task into steps]    │
│  │  • [Switch to easier task]         │
│  │  • [Take a 10-minute break]        │
│  │  • [Ask for help/delegate]         │
│  │                                     │
│  │  [Continue]                        │
│  └────────────────────────────────────┘
│
├─ If "Break down task":
│  └─ Show task decomposition helper
│     (LLM suggests 3-5 smaller subtasks)
│
├─ If "Switch to easier task":
│  └─ Show tasks with overwhelm_factor < 4
│     AND energy_required <= current_energy
│
└─ Log intervention in daily_checkins
   Track if helpful for pattern learning
```

**Guided Breathing Animation:**
```
Inhale (4 seconds):  ○ → ◐ → ◑ → ◕ → ●
Hold (4 seconds):    ● ● ● ●
Exhale (4 seconds):  ● → ◕ → ◑ → ◐ → ○
Repeat 3 times
```

**Task Breakdown Helper:**
```
Original task: "Plan conference talk"
Overwhelm factor: 9/10

The system suggests breaking this into:
1. Brainstorm 3 talk topics (15 min, overwhelm: 3)
2. Pick one topic (5 min, overwhelm: 2)
3. Outline main points (30 min, overwhelm: 5)
4. Find 2-3 examples (20 min, overwhelm: 4)
5. Create title slide (10 min, overwhelm: 3)

[Create these 5 tasks] [Edit] [Cancel]
```

**Discussion Questions:**
1. Should STOP & PIVOT be dismissible or required?
2. How many times to offer before reducing frequency (avoid annoyance)?
3. Should breathing exercise be audio-guided or visual only?
4. How to track "helpful" vs. "annoying" to calibrate sensitivity?
5. Should there be different intervention styles based on overwhelm type?

---

### Section 5: Procrastination Management

#### ADHD Principle: Identifying Resistance Types

**From Spec:**
> Not all procrastination is the same. Identify WHY you're avoiding:
> 1. Boring/tedious (need dopamine boost)
> 2. Overwhelming (need to break down)
> 3. Perfectionism (need to lower stakes)
> 4. Unclear (need more definition)
> 5. Emotionally difficult (need support/reframe)

**Current Implementation:**
- ❌ **Missing**: No procrastination tracking

**Future Enhancement Needed:**

**"Task Stuck" Detection:**
```sql
-- Identify stuck tasks
SELECT
  tm.things_task_id,
  tm.task_type,
  tm.energy_required,
  tm.overwhelm_factor,
  (julianday('now') - julianday(tm.created_at)) as days_stuck,
  tm.estimated_minutes,
  rn.content as source_note
FROM task_metadata tm
JOIN raw_notes rn ON tm.raw_note_id = rn.id
WHERE tm.completed_at IS NULL
  AND (julianday('now') - julianday(tm.created_at)) > 7 -- Stuck for >7 days
ORDER BY days_stuck DESC;
```

**"Help, I'm Stuck" Workflow:**
```
Trigger: User clicks "I'm stuck on this task" OR System detects task stuck >7 days
│
├─ Show diagnostic questions:
│
│  ┌────────────────────────────────────┐
│  │  Task Resistance Diagnostic 🔍     │
│  ├────────────────────────────────────┤
│  │  Task: "Write project documentation"│
│  │  Stuck for: 12 days                │
│  │                                     │
│  │  What's making this hard?           │
│  │  (Select all that apply)            │
│  │                                     │
│  │  [x] It's boring/tedious           │
│  │  [ ] It feels overwhelming          │
│  │  [x] I want it to be perfect       │
│  │  [ ] I don't know how to start     │
│  │  [ ] I'm afraid of the outcome     │
│  │  [ ] It's emotionally difficult    │
│  │                                     │
│  │  [Next]                            │
│  └────────────────────────────────────┘
│
├─ Based on selections, show reframes:
│
│  For "Boring/tedious":
│  ┌────────────────────────────────────┐
│  │  Dopamine Boost Strategies 🎮      │
│  │                                     │
│  │  • Body double: Work alongside     │
│  │    someone (video call, coffee shop)│
│  │                                     │
│  │  • Gamify: Set 15-min timer, see   │
│  │    how much you can get done       │
│  │                                     │
│  │  • Reward: Promise yourself [x]    │
│  │    after 30 minutes of work        │
│  │                                     │
│  │  • Background stimulation: Music,  │
│  │    podcast, or ADHD focus sounds   │
│  │                                     │
│  │  [Try one] [Not helpful]           │
│  └────────────────────────────────────┘
│
│  For "Perfectionism":
│  ┌────────────────────────────────────┐
│  │  Lower the Stakes 📉               │
│  │                                     │
│  │  Reframe this task:                │
│  │  OLD: "Write project documentation"│
│  │  NEW: "Create rough draft of docs" │
│  │                                     │
│  │  Remember: Done is better than     │
│  │  perfect. You can always revise.   │
│  │                                     │
│  │  Set a timer for 25 minutes and    │
│  │  write ANYTHING. No editing.       │
│  │                                     │
│  │  [Update task] [Skip]              │
│  └────────────────────────────────────┘
│
└─ Log intervention and track effectiveness
```

**Reframe Suggestions Database:**
```sql
CREATE TABLE reframe_strategies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    resistance_type TEXT NOT NULL,
    reframe_type TEXT NOT NULL,
    suggestion_text TEXT NOT NULL,
    success_rate REAL DEFAULT 0.5 -- Learn which work for user
);

-- Example entries:
INSERT INTO reframe_strategies VALUES
  (1, 'boring', 'gamify', 'Set a 15-minute timer and race against the clock', 0.7),
  (2, 'boring', 'body_double', 'Work alongside someone on video call', 0.6),
  (3, 'perfectionism', 'lower_stakes', 'Rename task to "rough draft" instead of "final"', 0.8),
  (4, 'perfectionism', 'time_box', 'Spend exactly 25 minutes, then stop - no editing', 0.75);
```

**Discussion Questions:**
1. Should "stuck" threshold be configurable (7 days? 14 days?)?
2. How to avoid nagging if user genuinely doesn't want to do task?
3. Should there be a "mark as not important" option (delete from Things)?
4. How to track which reframe strategies actually work for the user?
5. Should system proactively suggest strategies before task gets stuck?

---

## Implementation Roadmap

### Phase 7: Things Integration (Weeks 1-8)
**Status:** Planning
- ✅ Auto-task extraction
- ✅ Project detection
- ✅ SeleneChat task display
- ✅ Status sync and basic patterns

### Phase 8: Time Visibility (Weeks 9-12)
**Status:** Future
- 📋 Calendar integration (macOS Calendar)
- 📋 Structured vs. unstructured time calculation
- 📋 Weekly view implementation
- 📋 Over-scheduling detection

### Phase 9: Planning Views (Weeks 13-16)
**Status:** Future
- 📋 Monthly view (deadlines)
- 📋 Daily view (hour-by-hour)
- 📋 Moment view ("what now?")
- 📋 Energy forecast

### Phase 10: Emotional Regulation (Weeks 17-20)
**Status:** Future
- 📋 Daily check-ins (3-4x per day)
- 📋 Evening ritual
- 📋 STOP & PIVOT workflow
- 📋 Overwhelm interventions

### Phase 11: Procrastination Support (Weeks 21-24)
**Status:** Future
- 📋 Stuck task detection
- 📋 Resistance type diagnostic
- 📋 Reframe strategies
- 📋 Effectiveness tracking

### Phase 12: Visual Organization (Weeks 25-28)
**Status:** Future
- 📋 Mind-map generation (WTF + Project)
- 📋 Kanban view
- 📋 Progress visualizations
- 📋 Obsidian Canvas export

---

## Discussion Questions for Next Session

### Architecture & Integration
1. Should SeleneChat become primary interface, or keep Things primary?
2. How much sync latency is acceptable (real-time, 5min, hourly)?
3. Should ADHD features be opt-in or default-on?
4. How to handle iOS vs. macOS feature parity?

### User Experience
5. How to balance automation vs. user control?
6. What's the line between helpful prompts and nagging?
7. Should there be different "ADHD support levels" (light/medium/heavy)?
8. How to make features discoverable without overwhelming?

### Data & Privacy
9. Should emotional check-in data be exportable/deletable?
10. How long to retain pattern data (forever, 1 year, 3 months)?
11. Should ADHD markers be visible to user or hidden intelligence?

### Feature Prioritization
12. Which ADHD features provide highest ROI (effort vs. impact)?
13. What should Phase 8 focus on (time visibility, emotional regulation, or visual organization)?
14. Should we build on SeleneChat or create separate ADHD companion app?

### Learning & Adaptation
15. How to calibrate overwhelm detection sensitivity?
16. Should system learn per-user patterns or use population averages?
17. How to handle outlier days (vacation, illness, hyperfocus marathons)?
18. What metrics define "success" for ADHD features?

---

## Success Metrics for ADHD Integration

### Quantitative Metrics
- **Task completion rate** increases (baseline vs. after integration)
- **Task creation to completion time** decreases
- **Overwhelm incidents** decrease over time
- **Check-in completion rate** >60%
- **Evening ritual completion rate** >40%
- **Time estimation accuracy** improves (planning fallacy reduction)
- **Over-scheduling incidents** decrease

### Qualitative Metrics
- User reports: "I feel less overwhelmed"
- User reports: "I'm completing more tasks"
- User reports: "I understand my patterns better"
- User reports: "I trust the system to remember for me"
- User reports: "The interventions are helpful, not annoying"

### ADHD-Specific Metrics
- **Working memory externalization**: Can user recall tasks without system? (Should be NO)
- **Decision fatigue**: User creates tasks without hesitation
- **Time visibility**: User can estimate available time accurately
- **Emotional regulation**: Early intervention prevents overwhelm escalation
- **Object permanence**: No "I forgot I had that task" incidents

---

## Next Steps

**To continue this discussion in a new session:**

1. **Read this document** along with [ADHD_Principles.md](../../.claude/ADHD_Principles.md)
2. **Choose a focus area** (time visibility, emotional regulation, visual organization)
3. **Design specific features** with detailed specs
4. **Create implementation plans** for chosen features
5. **Prototype in SeleneChat** or create proof-of-concept

**Recommended starting point:**
- **Phase 8: Time Visibility** (calendar integration + weekly view)
  - Foundational for planning features
  - High impact for ADHD users (addresses time blindness)
  - Builds on Phase 7 task infrastructure

---

**Document Status:** ✅ Ready for Discussion
**Purpose:** Deep dive planning for ADHD feature integration
**Next Action:** Review and select Phase 8 focus area
**Owner:** Chase Easterling
**Last Updated:** 2025-11-24