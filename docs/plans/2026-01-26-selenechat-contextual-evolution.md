# SeleneChat Contextual Evolution

**Status:** Vision / Early Design
**Created:** 2026-01-26
**Author:** Chase Easterling

---

## Vision

Transform SeleneChat from a single-threaded chat with note retrieval into a **context-aware system that understands relationships** between projects, tasks, and notes. The chat should feel like talking to someone who knows your work context, not just searching a database.

Core insight: **The Today View works.** The card-based project view is the right mental model. Now extend that context awareness into the chat experience.

---

## Core Problems to Solve

1. **Mega-thread fatigue** - One chat thread for everything loses context and becomes overwhelming
2. **Isolated information** - Notes, tasks, and projects exist but aren't connected
3. **Citation opacity** - "Note 47" references are correct but not actionable
4. **Missing documentation layer** - No way to capture thinking/progress on active work
5. **Static tasks** - Tasks are items on a list, not living plans you refine

---

## Design Principles

1. **Context flows from projects** - Projects are the organizing unit; everything else relates to them
2. **Information should be clickable** - If the system references something, you should be able to see it
3. **Notes document the journey** - "Lab notes" capture thinking as you work, not just outcomes
4. **LLM as collaborator** - Use AI to discuss and refine plans, not just retrieve information
5. **Time-aware when needed** - Some tasks are recurring; the system should help track that

---

## Feature Areas

### 1. Project-Scoped Chats

**Problem:** One mega chat thread loses context. When you switch mental contexts (projects), the chat doesn't.

**Solution:** Each project/card in the Today View gets its own chat context.

- Clicking into a card from Today View starts a fresh chat scoped to that project
- Chat history persists per-project
- The LLM receives project context automatically (related tasks, notes, history)
- Option to start fresh or continue previous conversation

**Open questions:**
- How to handle cross-project topics?
- Global chat still available for general questions?

---

### 2. Clickable Note References

**Problem:** Chat cites "Note 47" but you can't see what that note says without leaving the chat.

**Solution:** Make note references clickable with inline preview.

- Note citations become links
- Click to expand inline (don't navigate away from chat)
- Show note content, creation date, any tags/concepts
- Option to open full note view

**The naming problem:**
- "Note 47" feels impersonal
- Full titles could be wordy for short notes
- Single-sentence notes don't have natural titles

**Possible approaches:**
- Use first N words as preview: `"Remember to check..." (Note 47)`
- Auto-generate short titles via LLM
- Show date + first words: `Jan 15: "Remember to check..."`
- Let it be - the inline preview solves the mystery

---

### 3. Connected Information Model

**Problem:** Projects, tasks, and notes exist in isolation. The chat doesn't know what's related to what.

**Solution:** Explicit relationships between entities.

```
Project
  ├── Tasks (actionable items for this project)
  ├── Notes (thoughts, research, lab notes about this project)
  └── Chat History (conversations about this project)
```

When chatting about a project, the LLM knows:
- What tasks exist and their status
- What notes you've written about it
- Previous conversations and decisions

**Data model implications:**
- Notes can be tagged to projects
- Tasks belong to projects
- Chat sessions are scoped to projects (or global)

---

### 4. Lab Notes

**Problem:** No way to document your thinking as you execute a project. Notes are general capture, not tied to active work.

**Solution:** "Lab notes" - notes explicitly tied to projects and tasks.

- When viewing a project, quick action to add a lab note
- Lab notes are timestamped progress/thinking documentation
- Can be tied to specific tasks ("notes on this task")
- Creates a trail of your work that the LLM can reference

**Use cases:**
- "Tried approach X, didn't work because Y"
- "Talked to Z, they said..."
- "Decision: going with option A because..."
- "Blocked on X, waiting for Y"

---

### 5. Interactive Task Refinement

**Problem:** Tasks are static items. No way to discuss and refine action plans with the LLM.

**Solution:** Task-aware chat that helps plan and refine.

- Chat can see task details and status
- Ask LLM to help break down a task
- Discuss approach, get suggestions
- LLM can propose task modifications (you approve)
- Refinement history becomes part of project context

**Example interaction:**
```
You: "Help me think through the API migration task"
LLM: "Looking at that task and your notes... You mentioned concerns
     about backwards compatibility. Here are three approaches..."
You: "Let's go with option 2"
LLM: "I can break that into subtasks: [list]. Want me to add these?"
```

---

### 6. Time-Based Tasks and Tracking

**Problem:** Some tasks are "do X at Y time" or "Y times per day" - recurring actions, not one-time items.

**Solution:** Support for recurring tasks with tracking.

- Task type: one-time vs recurring
- Recurring patterns: daily, X times per day, weekly, custom
- Completion tracking over time
- Integration with reminders/calendar

**Example:**
- "Take medication at 9am and 9pm" → recurring task, twice daily
- Track: did you do it? Streak? Patterns?
- Surface in Today View at appropriate times

**Open questions:**
- Calendar integration (Apple Calendar?)
- Reminder system (notifications?)
- How to track "did I do this?" - quick check-in UI?

---

## Architecture Implications

### Data Model Changes

```
projects
  - id, name, description, status, created_at

tasks
  - id, project_id (nullable), title, status
  - task_type: 'one-time' | 'recurring'
  - recurrence_pattern (for recurring)

notes (existing raw_notes, extended)
  - project_id (nullable) - for lab notes
  - task_id (nullable) - for task-specific notes
  - note_type: 'capture' | 'lab_note'

chat_sessions
  - id, project_id (nullable for global), created_at

chat_messages
  - id, session_id, role, content, created_at

task_completions (for recurring tasks)
  - id, task_id, completed_at
```

### SeleneChat App Changes

- Today View: Already works, becomes entry point to project chats
- Chat View: Needs project context, session management
- Note View: Needs inline expansion capability
- New: Project detail view with tasks, notes, chat
- New: Task detail view with refinement chat
- New: Quick lab note capture

---

## Implementation Phases (Rough)

**Phase A: Foundation**
- Data model for projects, project-task-note relationships
- Basic project detail view

**Phase B: Project-Scoped Chat**
- Chat sessions tied to projects
- Project context in LLM prompts
- Session persistence

**Phase C: Clickable References**
- Note links in chat
- Inline expansion UI
- Better note identification (first words, etc.)

**Phase D: Lab Notes**
- Quick capture tied to project/task
- Lab note type in data model
- Surface in project context

**Phase E: Task Refinement**
- Task-aware chat prompts
- LLM can propose task changes
- Subtask creation flow

**Phase F: Recurring Tasks**
- Recurring task model
- Completion tracking
- Calendar/reminder integration

---

## Open Questions

1. **Note naming** - What's the best way to identify notes that's not just "Note 47"?
2. **Cross-project chat** - How to handle topics that span projects?
3. **Calendar integration** - Apple Calendar? Reminders app? Custom?
4. **Notification system** - How to remind about recurring tasks?
5. **Migration** - How to handle existing notes without project associations?

---

## Success Criteria

- [ ] Can click into a project from Today View and have a scoped chat
- [ ] Chat knows about project's tasks and notes automatically
- [ ] Can click note references to see content inline
- [ ] Can add lab notes tied to active projects
- [ ] Can discuss and refine tasks with LLM assistance
- [ ] Recurring tasks track completion over time

---

## References

- Today View implementation: `SeleneChat/SeleneChat/Views/TodayView.swift`
- Current chat: `SeleneChat/SeleneChat/Views/ChatView.swift`
- Database schema: `data/selene.db`
- ADHD principles: `.claude/ADHD_Principles.md`

---

## Changelog

- **2026-01-26**: Initial vision captured from user feedback
