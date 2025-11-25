# Selene Project Management System: Conversation Summary

**Date**: November 24, 2025  
**Purpose**: Design an ADHD-friendly project management layer that bridges Selene (note capture/processing) with Things (task execution)

---

## The Vision: Your Digital Executive Assistant

### What You Want to Build

A system that acts as a hyper-intelligent executive assistant who:
- Reads everything you write in Selene (your capture system)
- Automatically detects when you mention wanting to do something
- Transforms vague ideas into concrete, actionable projects
- Maintains connection between projects and your original motivation (the "WHY")
- Helps you choose what to work on based on current energy, time, and momentum
- Provides bidirectional sync between your notes and your task manager
- Never lets ideas disappear into the void

### The Core Problem This Solves

**ADHD Executive Function Gaps**:
- **Working memory**: Can't reliably hold multiple project ideas in mind
- **Object permanence**: "Out of sight, out of mind" - ideas disappear
- **Decision fatigue**: Too many options leads to paralysis
- **Motivation loss**: Forgetting WHY you wanted to do something
- **Time blindness**: Can't see how much time is available vs. committed
- **Overwhelm**: Everything feels equally urgent and important

---

## How Your ADHD Brain Will Experience This

### Morning: "What Should I Work On Today?"

**Your Experience**:
- Wake up, grab coffee
- Ask AI: "I have 2 hours and medium energy - what should I tackle?"
- Get 2-3 specific, matched recommendations with context about WHY you wanted each thing
- Each suggestion includes: project name, specific next action, time estimate, energy match, and motivation reminder

**Why This Works**:
- Zero decision fatigue
- Energy-matched to your current state
- Reminds you of your motivation
- Shows realistic next actions, not overwhelming project lists

### During the Day: Seamless Capture to Action

**Your Experience**:
- Have a passing thought while walking the dog: "I should create a better morning routine"
- Voice memo it into Selene
- **Done. No decisions needed.**
- A few days later, the AI flags it as a potential project
- Weekly review shows it with: title, extracted WHY, vision of done, complexity estimate
- One click to activate or defer

**Why This Works**:
- Object permanence: The thought doesn't disappear
- No mental load: You don't have to remember to do anything with it
- Connection to motivation: AI reminds you WHY you wanted this
- Reduces capture friction to absolute zero

### Project Development: From Vague to Concrete

**Your Experience**:
- Activate a project seed
- AI asks you to describe your vision: "What would done look like?"
- You spend 5 minutes describing the ideal end state
- AI transforms this into:
  - Clear project title
  - Your WHY statement
  - Concrete "done looks like" criteria
  - 3-5 specific first actions (bite-sized)
- Everything syncs to Things with full context

**Why This Works for ADHD**:
- Top-down thinking: Visualize end state first (natural ADHD pattern)
- Clear finish line: You know when you're "done"
- Bite-sized actions: No overwhelming big tasks
- Built-in experimentation: Acknowledges you'll adjust as you go

### Ongoing Connection: Notes Feed Projects

**Your Experience**:
- Two weeks later, journal about testing your morning routine
- Note says: "10-minute meditation is too long when I'm running late. Maybe I need short and long versions?"
- AI automatically:
  - Adds "Create 5-min and 15-min routine versions" to Things
  - Updates project notes with your timing insight
  - Tracks this as progress momentum
- **You never had to remember to update your project manually**

**Why This Is Magic**:
- System stays current with your evolving thinking
- Insights from random notes automatically enhance projects
- No manual maintenance burden
- Your real-world testing naturally improves the plan

### Weekly Review: "Show Me Everything"

**Your Experience**:
- Spend 15 minutes with your digital assistant
- See:
  - 3 new potential projects from this week's notes
  - Progress on active projects (completed, stalled)
  - Discovered connections between projects
  - Your energy patterns ("You work best Tuesday mornings")
  - WHY reminders for projects losing momentum

**Why This Works**:
- Everything is visible (no object permanence issues)
- Patterns emerge without effort
- Regular motivation maintenance
- No overwhelm: Only 3 new things to consider, not 20

### Daily Coaching: Match Task to Human

**The AI Learns**:
- You're most creative in mornings
- You get overwhelmed with more than 3-5 active projects
- You abandon projects when you forget the WHY
- You work better when you can see progress
- You need "play time" - creativity fuels motivation for structured work

**So When You Ask "What Should I Work On?"**:
The AI considers:
- Time available
- Your stated energy level
- Recent momentum on projects
- Your historical patterns (creative mornings)
- Project health (what's stalled)
- Your WHYs (motivation reminders)

**Why This Is Powerful**:
Like having someone who knows you deeply, tracks everything you can't hold in your head, and gently guides you toward what will feel satisfying and doable RIGHT NOW.

---

## System Architecture Overview

### The Bidirectional Flow

```
SELENE (Capture & Intelligence)
    ↓
    ↓ Automatic project detection
    ↓ WHY extraction
    ↓ Vision of done prompts
    ↓
PROJECT SEEDS (Pending Review)
    ↓
    ↓ Weekly review & activation
    ↓
THINGS (Active Projects & Tasks)
    ↓
    ↓ Tasks completed, progress made
    ↓
BACK TO SELENE (Notes about active projects)
    ↓
    ↓ Automatic enhancement of projects
    ↓ Scope updates, new tasks, insights
    ↓
Updated in THINGS automatically
```

### Key Components

**1. Selene (Already Built)**
- Captures all notes via Drafts integration
- Processes with Ollama LLM (concepts, themes, sentiment)
- Stores in SQLite database
- Exports to Obsidian
- n8n workflows for automation

**2. Project Intelligence Layer (To Be Built)**
- Workflow 07: Project Seed Detection
- Workflow 08: Project Activation & Things Sync
- Workflow 09: Bidirectional Sync
- Workflow 10: AI Daily Coach

**3. Things (Task Manager)**
- Available on all your devices
- Stores active projects and tasks
- Receives projects via URL schemes
- Maintains connection back to origin notes

**4. AI Coach Interface (To Be Built)**
- Daily energy check-ins
- Recommendation engine
- Pattern recognition
- Motivation maintenance

---

## What Makes This ADHD-Friendly

### Aligned with ADHD Design Principles

**1. Visual Over Mental**
- Everything externalized - nothing lives only in your head
- Projects always visible in Things
- Origin notes always accessible
- Big picture and details simultaneously available

**2. Reduce Decision Fatigue**
- No categorization required at capture
- Automatic project detection (AI decides what might be a project)
- AI recommends what to work on (eliminates daily decision paralysis)
- Maximum 3-5 active projects enforced

**3. Object Permanence**
- Every thought captured is tracked forever
- Projects linked back to origin notes
- Can't lose ideas or forget motivation
- Full audit trail of project evolution

**4. Realistic Over Idealistic**
- Vision of done prevents perfectionism traps
- Bite-sized next actions (not overwhelming multi-hour tasks)
- Energy matching (respects your actual state)
- Acknowledges projects evolve through experimentation

**5. Minimize Friction**
- Capture: One click from anywhere
- Organization: Happens automatically
- Activation: Simple review + one-click approve
- Sync: Completely automatic

**6. Emotional Regulation**
- Regular WHY reminders (motivation maintenance)
- Energy-matched recommendations (respects current state)
- Progress visibility (reduces anxiety)
- Stalled project alerts (gentle nudges, not guilt)

**7. Balance Is Essential**
- Max 3-5 active projects (prevents overwhelm)
- "Someday/maybe" vs "active now" clearly separated
- Future Ideas Board for long-term dreams
- System respects need for "play time" and creative projects

---

## Project Detection: Beyond Desire Language

### What the AI Looks For

**1. Direct Desire Language**
- "I want to...", "I should...", "I need to..."
- "I'd love to...", "I've been meaning to..."

**2. Problem/Frustration Signals**
- "I'm tired of...", "I hate that..."
- "This isn't working...", "I can't stand..."
- Pain points = projects in disguise

**3. Multi-Step Thinking**
- "First I'll... then I'll... and finally..."
- Sequential actions listed
- Conditional logic: "Once X is done, I can..."

**4. Question-Based Action**
- "How can I...?", "What if I...?"
- "Why don't I...?", "What's the best way to...?"
- Questions that imply research or action needed

**5. Time-Bound Statements**
- "By next week...", "Before the end of the month..."
- "This quarter I want to...", "Someday I'll..."
- Any deadline or time pressure

**6. Resource Mentions**
- "I need to buy...", "I should learn..."
- "I have to get...", "I need to find someone who..."
- Indicates procurement or learning projects

**7. Constraint/Dependency Language**
- "After I finish X...", "Once I have Y..."
- "Waiting for...", "Blocked by..."
- Shows project thinking with prerequisites

**8. Comparative/Evaluative**
- "X is better than Y", "I should switch from..."
- Decision-making in progress
- "Pros and cons of..."

**9. Meta-Planning Language**
- "I should make a plan for..."
- "I need to organize...", "Let me think through..."
- Self-directed planning statements

**10. Energy/Excitement Markers**
- "I'm so excited about...", "I can't wait to..."
- Positive emotion + future orientation
- High completion likelihood

**11. Recurring Pain Points**
- Same theme appearing across multiple notes
- Sentiment analysis showing consistent frustration
- Use existing sentiment tracking to detect patterns

---

## Current State: What You Have vs. Need

### ✅ What's Already Working (Selene Foundation)

**Capture Layer**:
- Drafts integration (brain-dump from anywhere)
- Zero friction capture
- All notes stored in SQLite
- Mobile and desktop accessible

**Intelligence Layer**:
- Ollama LLM processing (concepts, themes)
- Sentiment analysis (emotional state tracking)
- Pattern detection (themes over time)
- Connection network (note relationships)

**Data Foundation**:
- SQLite database with rich schema
- Event-driven n8n architecture
- Full text search and analysis
- Obsidian export working

### ❌ What You Need to Build

**Project Intelligence Layer**:
- Automatic project signal detection
- WHY statement extraction
- Vision of done prompts
- Connection between notes and actionable projects

**Project Management Bridge**:
- Things integration (URL schemes)
- Project activation workflow
- Task generation from projects
- Bidirectional sync logic

**AI Coaching Interface**:
- "What should I work on?" query system
- Energy/mood matching algorithm
- Momentum tracking
- Motivation reminders

**Enhanced Data Layer**:
- project_seeds table
- active_projects table
- project_note_links table
- project_task_additions table
- project_progress tracking

---

## The Roadmap: 4 Phases

### Phase 1: Project Detection Engine (Weeks 1-2)

**Goal**: Automatically spot potential projects in your existing Selene notes

**What Gets Built**:
- New n8n workflow that scans processed notes for project signals
- Enhanced Ollama prompts to detect 11 types of project indicators
- Database tables for storing "project seeds"
- Simple review interface (webhook-based or email digest)

**Success Metric**: 
After one week, you have 5-10 detected project seeds that actually feel like real projects you want to do.

**Why This First**: 
Prove the detection works before building everything else. Plus, you likely have months of notes with hidden projects waiting to be discovered.

**Week 1 Focus**: Enhanced detection prompts
- Add project signal detection to existing Workflow 02
- Test on last 100 notes
- Aim for 8-12 potential projects detected

**Week 2 Focus**: Storage and review
- Create project_seeds database table
- Build weekly email/dashboard showing detected seeds
- Basic approve/reject workflow

---

### Phase 2: Project Activation Workflow (Weeks 3-4)

**Goal**: Turn approved project seeds into actual Things projects with full context

**What Gets Built**:
- Project refinement interface (web form or Drafts action)
- "Vision of done" definition workflow
- WHY statement extraction and refinement prompts
- Things integration via URL schemes
- First version of project-to-note linking in database

**Success Metric**:
You activate 2-3 real projects from your seeds. They appear in Things with full context. You can see the connection back to origin notes.

**Why This Second**: 
Once you can detect projects, you need a way to make them actionable. This is where "vision of done" and "remember your why" get built.

**Key Features**:
- Guided refinement: AI asks clarifying questions
- WHY extraction: "Why do you want this?"
- Done criteria: "What will done look like?"
- Complexity estimation: Quick/Medium/Large
- Energy requirement: Low/Medium/High
- First 3-5 next actions automatically generated
- Things project creation with backlinks to Selene

---

### Phase 3: Bidirectional Intelligence (Weeks 5-6)

**Goal**: New notes automatically enhance existing projects

**What Gets Built**:
- Note-to-project matching system (AI detects references to active projects)
- Automatic task extraction from project-related notes
- Project scope and WHY updates from ongoing thoughts
- Progress momentum tracking (completion velocity)
- Project health monitoring (stalled warnings, forgotten WHYs)

**Success Metric**:
You write a note about an active project and see new tasks automatically appear in Things. Your project motivation gets updated with new insights.

**Why This Third**: 
This is where the system becomes truly intelligent - it feels like an executive assistant who remembers everything and connects dots you missed.

**Key Features**:
- AI scans new notes for mentions of active projects
- Extracts: new actions, scope changes, blockers, insights
- Updates Things automatically
- Maintains project_note_links table for full traceability
- Detects stalled projects (no activity in X days)
- Surfaces forgotten WHYs to reignite motivation

---

### Phase 4: AI Daily Coach (Weeks 7-8)

**Goal**: "What should I work on today?" becomes your daily superpower

**What Gets Built**:
- Daily energy check-in interface (quick webhook or form)
- AI coach recommendation engine
- Pattern recognition (your best times for different work types)
- Motivation reminders tied to original WHYs
- Overwhelm prevention (enforce max 3-5 active projects)
- Project momentum visualization

**Success Metric**:
You start most work sessions by asking the AI coach what to do. You consistently feel like you're working on the right thing for your current state.

**Why This Last**: 
This is the daily magic, but it needs all the data and connections from previous phases to work well.

**AI Coach Considers**:
- Time you have available
- Your stated energy level (low/medium/high)
- Recent momentum on each project
- Your historical patterns (creative mornings, etc.)
- Project health (what's stalled and needs attention)
- Your WHYs (motivation maintenance)
- Energy match (high-energy projects vs. low-energy projects)
- Variety needs (ADHD brains need novelty)

**Response Format**:
For each recommendation:
- Which project and why it's a good fit now
- Specific next action
- Duration estimate
- WHY reminder (your original motivation)
- Energy match explanation
- Momentum context

---

## Success Metrics by Phase

### Phase 1: Project Recognition
- "Holy shit, it actually found real projects in my notes"
- "These aren't just random tasks, they're things I genuinely want to do"
- "I can see my patterns - I think about organizing my office every 3 months"

### Phase 2: Activation Joy
- "I love seeing the full context in Things - I remember why I wanted this"
- "The vision of done helps me know when I'm actually finished"
- "I can trace this project back to the exact thought that started it"

### Phase 3: Invisible Intelligence
- "I mentioned my garden project in passing and new tasks just appeared"
- "The system updated my project motivation when I wrote about wanting peace"
- "I don't have to remember to connect related notes - it just happens"

### Phase 4: Daily Confidence
- "I never waste time wondering what to work on - I just ask the AI"
- "The recommendations actually match how I'm feeling"
- "I'm making progress on things I care about instead of just reacting"

---

## Why This System Won't Get Abandoned

### Unlike Every Other System You've Tried

**1. Zero Maintenance Burden**
- You never have to remember to update anything
- You never have to categorize or file anything
- AI does all the organizational thinking
- System stays current automatically

**2. Matches Your Brain**
- Visual project layouts (not overwhelming lists)
- Big picture AND details simultaneously
- Top-down project creation (vision first, steps after)
- Energy-aware recommendations
- Respects object permanence issues

**3. Motivation Preservation**
- Every project stays connected to its WHY
- Regular reminders of your original motivation
- Can see the exact note where you first wanted this
- Prevents the "why am I doing this again?" project abandonment

**4. Decision Elimination**
- No decisions at capture (just dump)
- No decisions at organization (AI does it)
- Minimal decisions at activation (review + click)
- AI decides what to work on (you just confirm)

**5. Realistic Design**
- Acknowledges you'll adjust plans as you go
- Prevents over-commitment (max 3-5 projects)
- Matches tasks to your actual energy state
- Under-schedules by design, not accident

**6. Friction Elimination**
- Capture: One voice memo
- Processing: Completely automatic
- Review: 15 minutes weekly
- Daily planning: One question to AI

**7. Progress Visibility**
- See what you've completed
- Track momentum on active projects
- Celebrate small wins
- Identify stalled projects before they die

---

## Technical Architecture

### New Database Tables Needed

**project_seeds** - Ideas that might become projects
- Links to source note
- Extracted title, WHY, complexity, energy
- Status: pending_review/approved/rejected/activated

**active_projects** - Approved projects in Things
- Links to seed and Things project ID
- Project title, WHY, vision of done
- Status, priority, energy level
- Last synced timestamp

**project_note_links** - Connections between notes and projects
- Links project to related notes
- Type: origin/reference/update/blocker/completion
- Extracted content from note

**project_task_additions** - Audit trail of tasks created
- Links to project and source note
- Task title, notes, Things task ID
- Timestamp

**project_progress** - Momentum tracking
- Tasks completed vs. total
- Last activity date
- Momentum score (0.0-1.0)
- Notes on progress

### New n8n Workflows

**Workflow 07: Project Seed Detection** (every 6 hours)
- Queries processed notes for project signals
- Sends to Ollama for project analysis
- Stores in project_seeds table
- Flags for user review

**Workflow 08: Project Activation** (webhook triggered)
- Receives user refinements
- Prompts for vision of done
- Generates first actions
- Creates in Things via URL scheme
- Stores in active_projects table

**Workflow 09: Bidirectional Sync** (every 2 hours)
- Queries new notes for project references
- Extracts relevant content
- Updates Things with new tasks
- Updates active_projects table
- Maintains project_note_links

**Workflow 10: AI Daily Coach** (on-demand webhook)
- Receives energy level check-in
- Analyzes active projects
- Considers patterns and momentum
- Generates 2-3 recommendations
- Returns formatted response

### Things Integration

**Using URL Schemes** (no API required):
- `things:///add-project` - Create new project
- `things:///add` - Add task to project
- Projects contain backlinks to Selene notes
- WHY statements in project notes
- Tags: "selene", "adhd-managed"

---

## Next Steps & Open Questions

### Before Starting Phase 1

**Questions to Answer**:
1. How many notes are currently in Selene? (Affects backlog processing)
2. How often do you write notes? (Daily? Few times per week?)
3. Do you currently use Things or starting fresh?
4. How many projects do you typically juggle? (Informs overwhelm threshold)
5. When would you realistically review project seeds? (Morning? Sunday planning?)
6. What time of day would you ask "What should I work on?"
7. What typically derails your project momentum? (Forgetting why? Too many options? Perfectionism?)

### Immediate Actions

1. Audit current Selene system (confirm what's working)
2. Test project detection prompts on sample notes
3. Define project seed review workflow (email? Dashboard? Drafts?)
4. Design project refinement interface
5. Map out Things URL scheme integration
6. Create database schema for new tables

---

## The Big Picture

This system transforms your ADHD brain's weakness (poor working memory, object permanence issues, decision fatigue) into strengths by:

1. **Externalizing everything** - Nothing lives only in your head
2. **Automatic organization** - AI does the cognitive work
3. **Motivation preservation** - WHY statements never get lost
4. **Energy matching** - Work with your brain, not against it
5. **Invisible maintenance** - System stays current automatically
6. **Decision elimination** - AI guides, you confirm
7. **Progress visibility** - See wins, identify stalls

**The Result**: 
You wake up knowing what to work on. You remember why you wanted to do it. You make progress on things that actually matter to you. You don't lose ideas in the void. You don't get overwhelmed by infinite options.

**The Promise**:
A digital prosthetic executive function that works WITH your ADHD brain, not against it.

---

## Key Insights from This Conversation

1. **The WHY is everything** - ADHD brains abandon projects when they forget the original motivation
2. **Vision of done matters** - Clear finish line prevents perfectionism traps and scope creep
3. **Energy matching is critical** - Right task for right state prevents burnout and frustration
4. **Automatic is better than manual** - Any required maintenance will be skipped eventually
5. **Bidirectional flow is the magic** - Notes enhance projects, projects stay connected to notes
6. **3-5 project maximum** - Overwhelm prevention must be enforced, not suggested
7. **Top-down thinking is ADHD-native** - Visualize end state first, then work backwards
8. **Object permanence issues are real** - If it's not visible, it doesn't exist
9. **Decision fatigue is the enemy** - Eliminate choices wherever possible
10. **Momentum tracking matters** - ADHD brains need to see progress to stay motivated

---

**Document Created**: November 24, 2025  
**Status**: Conceptual design complete, ready for Phase 1 implementation planning  
**Next Action**: Answer scoping questions and begin Phase 1 (Project Detection Engine)