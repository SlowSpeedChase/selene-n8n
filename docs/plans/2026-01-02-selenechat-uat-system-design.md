# SeleneChat UAT System Design

**Created:** 2026-01-02
**Status:** Ready for Implementation
**Purpose:** Structured user acceptance testing for SeleneChat features

---

## Problem

When a SeleneChat feature is complete, manual UI verification is needed before sign-off. Currently there's no structure - it's easy to miss things during testing, and state/binding bugs slip through despite passing service tests.

## Solution

An interactive UAT system where Claude guides the tester through structured checklists, records results, and generates sign-off documentation.

---

## Design

### Flow

```
┌─────────────────────────────────────────────────────────┐
│ User: "Ready to UAT the Planning tab"                   │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Claude: Loads PlanningView UAT checklist                │
│         Asks: "First, let's check empty state.          │
│         Open Planning tab with no threads.              │
│         Do you see the empty state message?"            │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ User: "Yes" / "No, it shows a spinner"                  │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Claude: Records result, moves to next check             │
│         "Good. Next: Create a new thread.               │
│         Does it appear in the list immediately?"        │
└─────────────────────────────────────────────────────────┘
                          ↓
              ... continues through checklist ...
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Claude: Generates sign-off summary:                     │
│         - What was tested                               │
│         - Pass/fail for each item                       │
│         - Any issues found                              │
│         - Commits to Tests/UAT/sessions/                │
└─────────────────────────────────────────────────────────┘
```

### File Structure

```
SeleneChat/
└── Tests/
    └── UAT/
        ├── README.md                    # How UAT works
        ├── checklists/
        │   ├── ChatView.yaml            # Structured checklist
        │   ├── PlanningView.yaml
        │   ├── SearchView.yaml
        │   └── SettingsView.yaml
        └── sessions/
            └── 2026-01-02-planning-view.md  # Completed sign-offs
```

### Checklist Categories

Each view's checklist covers four categories:

**1. State Scenarios**
- Empty state (no data)
- Loading state (fetching data)
- Error state (something failed)
- Populated state (normal use)
- Edge cases (long text, many items, etc.)

**2. User Interactions**
- Primary action (send message, create thread, etc.)
- Secondary actions (delete, edit, cancel)
- Keyboard shortcuts if any
- Focus behavior (where does cursor go)

**3. Data Binding**
- Add item → appears in list
- Update item → UI reflects change
- Delete item → removed from UI
- External change → UI refreshes

**4. Visual Checks**
- Layout looks correct
- Text is readable (not clipped)
- Indicators show right state (badges, icons)
- Responsive to window resize

### Checklist Format (YAML)

```yaml
# PlanningView.yaml
view: PlanningView
description: Planning tab for guided task breakdown conversations

states:
  - name: Empty state
    prompt: "Open Planning tab with no threads. Do you see 'No planning threads yet' message?"

  - name: Loading state
    prompt: "Refresh the view. Do you see a loading indicator briefly?"

  - name: Error state
    prompt: "Disconnect Ollama and try to send a message. Do you see an error message?"

  - name: Populated state
    prompt: "With existing threads, does the list display correctly?"

interactions:
  - name: Create thread
    prompt: "Click 'New Thread'. Does a new thread appear in the list?"

  - name: Send message
    prompt: "Type a message and send. Does it appear in the conversation?"

  - name: Toggle AI provider
    prompt: "Open settings and toggle AI provider. Does the badge update?"

bindings:
  - name: Message list updates
    prompt: "Send another message. Does it append without full refresh?"

  - name: Thread list refreshes
    prompt: "Create a second thread. Does the list update immediately?"

visual:
  - name: AI provider badge
    prompt: "Check header. Is the AI provider badge (Local/Cloud) visible?"

  - name: Message styling
    prompt: "Do user and AI messages have distinct styling?"
```

### Sign-off Document Format

```markdown
# UAT Session: PlanningView

**Date:** 2026-01-02
**Tester:** Chase Easterling
**Feature/PR:** Phase 7.2d - AI Provider Toggle
**Result:** ✅ PASSED (12/12 checks)

---

## States

| Check | Result | Notes |
|-------|--------|-------|
| Empty state message | ✅ Pass | |
| Loading indicator | ✅ Pass | |
| Error state | ✅ Pass | Tested by disconnecting Ollama |
| Populated state | ✅ Pass | |

## Interactions

| Check | Result | Notes |
|-------|--------|-------|
| Create thread | ✅ Pass | |
| Send message | ✅ Pass | |
| Toggle AI provider | ✅ Pass | |
| Delete thread | ✅ Pass | |

## Bindings

| Check | Result | Notes |
|-------|--------|-------|
| Message list updates | ✅ Pass | |
| Thread list refreshes | ✅ Pass | |

## Visual

| Check | Result | Notes |
|-------|--------|-------|
| AI provider badge | ✅ Pass | |
| Message styling differs by provider | ✅ Pass | |

---

**Sign-off:** UAT complete. Ready for merge.
```

### Skill Definition

```yaml
name: uat-selenechat
description: Guide interactive UAT session for SeleneChat views

triggers:
  - /uat <view>
  - "UAT the <view>"
  - "let's test <view>"

behavior:
  1. Load checklist from SeleneChat/Tests/UAT/checklists/<view>.yaml
  2. Walk through each item one at a time
  3. Wait for user confirmation (yes/no/issue description)
  4. Track results
  5. Generate session markdown
  6. Commit to SeleneChat/Tests/UAT/sessions/
```

---

## Implementation Tasks

1. Create `SeleneChat/Tests/UAT/` directory structure
2. Create `README.md` explaining UAT process
3. Create checklist YAML files for each view:
   - `ChatView.yaml`
   - `PlanningView.yaml`
   - `SearchView.yaml`
   - `SettingsView.yaml`
4. Create `_template.yaml` for new features
5. Create `uat-selenechat` skill
6. Create empty `sessions/` directory with `.gitkeep`

---

## Benefits

- **Structured:** Know exactly what to check for each view
- **Guided:** Claude walks through each item conversationally
- **Documented:** Permanent record of what was tested
- **Targeted:** Focus on the specific view/feature being tested
- **ADHD-friendly:** No mental overhead remembering what to test
