# Thinking Partner Upgrade: Interactive Planning + Cloud AI

**Created:** 2026-02-15
**Status:** Ready
**Goal:** Make thread conversations interactive and planning-capable instead of generic summaries
**Builds on:** `phase-7.3-cloud-ai-integration.md` (sanitization architecture)

---

## Problem Statement

When a user opens a thread and asks "help me identify the next step and make a plan," the thinking partner:

1. **Summarizes** the thread context back instead of helping think through it
2. **Doesn't ask questions** — gives a one-shot generic answer instead of interactive dialogue
3. **Doesn't know it can create Things tasks** — action markers are a formatting instruction, not a presented capability
4. **Can't do complex reasoning** — mistral:7b hits its ceiling on planning, research, and multi-step analysis
5. **Word limits are too restrictive** — 200/150-word caps force superficial responses

**Desired behavior:** Interactive back-and-forth that asks clarifying questions, identifies gaps, proposes concrete steps, and creates actionable tasks — like talking to a smart collaborator.

---

## Solution: Two-Phase Upgrade

### Phase 1: Prompt Rewrite (Local LLM)

Rewrite system prompts to coach interactive planning behavior. No infrastructure changes, just better instructions.

### Phase 2: Cloud LLM + File Workspace

Route planning queries to Claude API with sanitization. Add persistent file workspace where the AI can write plans and reference them later.

---

## Phase 1: Prompt Rewrite

### Changes to ThreadWorkspacePromptBuilder

**1. Replace system identity**

Current:
```
Respond naturally to whatever the user asks. Use the thread context
and notes above to give informed, specific answers.
```

New:
```
You are an interactive thinking partner. Your job is to help the user
make progress on this thread — not summarize it back to them.

CAPABILITIES:
- You can create tasks in Things (the user's task manager) by using
  action markers when you've collaboratively identified concrete steps
- You have full context of the user's notes, thread history, and
  existing tasks

BEHAVIOR:
- When the user asks for planning help: Ask 1-2 clarifying questions
  first, then break the problem into concrete steps
- When the user asks "what's next": Analyze thread state, propose
  2-3 possible directions with trade-offs, ask which resonates
- When you identify actionable steps: Suggest creating them as tasks
- Default: Be a collaborator, not a summarizer. Ask before assuming.
```

**2. Remove word limits**

Replace "Keep your response under 200 words" with:
```
Be concise but thorough. Prefer asking a good question over giving
a generic answer. Never summarize the thread back to the user unless
they specifically ask for a summary.
```

**3. Expand planning detection**

Current `isWhatsNextQuery` only catches 9 patterns. Expand to detect broader planning intent:
- "help me", "make a plan", "break this down", "how should I approach"
- "what are my options", "figure out", "work through", "think through"
- "prioritize", "decide between", "next move"

When detected, use a planning-specific prompt that explicitly coaches multi-turn dialogue.

**4. Rewrite "What's Next" prompt**

Current: Recommends ONE task in 100 words.

New: Analyze thread state → identify 2-3 possible directions with trade-offs → ask which resonates → then break down into tasks.

**5. Things awareness in system prompt**

Move action markers from a formatting footnote into the system identity under CAPABILITIES. The model should understand it has a tool, not just a format to use.

### Files Changed (Phase 1)

- `Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift` — All prompt methods rewritten
- No infrastructure changes, no new files

### Acceptance Criteria (Phase 1)

- [ ] When user asks "help me make a plan," Selene asks a clarifying question first (not a summary)
- [ ] When user asks "what's next," Selene proposes 2-3 options with trade-offs
- [ ] Action markers are described as a capability in the system prompt
- [ ] No response has a hardcoded word limit under 500
- [ ] Planning-intent detection covers at least 20 query patterns

---

## Phase 2: Cloud LLM + File Workspace

### 2A: Sanitization Layer

Use the local LLM to produce topic-level summaries of thread context before sending to Claude. Personal details stay local.

**What gets sent to Claude:**
```
Topic: Dog training
Key concepts: positive reinforcement, leash reactivity, desensitization
Current state: Researching techniques, no structured plan yet
Open tasks: 3 (research trainers, practice engagement, buy training treats)
```

**What stays local:**
```
"I'm so frustrated with Max pulling on walks near the school..."
"Called Dr. Smith about the anxiety medication adjustment..."
```

**Implementation:**
- New `ContentSanitizerService` (builds on Phase 7.3 design)
- Local LLM produces topic summary via dedicated sanitization prompt
- Wire up `PrivacyRouter.routeQuery()` to use existing keyword detection
- Sanitization levels: Strict (default), Balanced, Permissive (per Phase 7.3)

### 2B: Claude API Client

- New `ClaudeService` implementing `LLMProvider` protocol
- HTTP client to Claude Messages API
- System prompt tells Claude it's a planning partner with:
  - Topic context (sanitized)
  - Workspace file contents
  - Conversation history (sanitized)
  - Ability to suggest tasks and write workspace files
- Multi-turn conversation support
- API key stored in macOS Keychain

### 2C: File Workspace

Claude creates persistent files that it (and the user) can reference across sessions.

**Directory structure:**
```
~/selene-data/workspaces/
  {thread-slug}/          # Thread-scoped files
    plan.md
    research-notes.md
    outline.md
  _general/               # Cross-thread scratchpad
    weekly-priorities.md
    research/
```

**Action markers (consistent with existing task pattern):**
```
[FILE_WRITE: plan.md | SCOPE: thread]
# Dog Training Plan
## Week 1: Foundation
- Practice engagement exercises indoors
...
[/FILE_WRITE]

[FILE_READ: plan.md | SCOPE: thread]
```

- `SCOPE: thread` → `~/selene-data/workspaces/{current-thread}/`
- `SCOPE: general` → `~/selene-data/workspaces/_general/`

**New services:**
- `FileWorkspaceExtractor` — Parse FILE_WRITE/FILE_READ markers from responses
- `FileWorkspaceService` — Read/write workspace files, list directory contents

**Context injection:** When starting a thread conversation, include contents of existing workspace files in the system prompt. If Claude wrote a plan last session, it sees it next time.

**UI:** Thread Workspace gets a "Files" section showing workspace documents. User can view, edit, or delete.

### 2D: Two-Tier Conversation Flow

```
User: "Help me figure out next steps for dog training"
    ↓
PrivacyRouter.routeQuery() → .external (planning query, non-sensitive topic)
    ↓
ContentSanitizerService: Local LLM extracts topic summary
    ↓
ClaudeService: Send sanitized context + workspace files + query
    ↓
Claude: Asks clarifying questions → Multi-turn dialogue → Produces plan
    ↓
Response contains:
  [FILE_WRITE: plan.md | SCOPE: thread] ... [/FILE_WRITE]
  [ACTION: Practice engagement daily | ENERGY: low | TIMEFRAME: this-week]
    ↓
SeleneChat: Writes plan.md + shows task creation banner
```

### Files Changed (Phase 2)

**New files:**
- `Sources/SeleneChat/Services/ClaudeService.swift` — Claude API client
- `Sources/SeleneChat/Services/ContentSanitizerService.swift` — Sanitization
- `Sources/SeleneChat/Services/FileWorkspaceService.swift` — File I/O
- `Sources/SeleneShared/Services/FileWorkspaceExtractor.swift` — Marker parsing

**Modified files:**
- `Sources/SeleneShared/Services/PrivacyRouter.swift` — Wire up routeQuery()
- `Sources/SeleneChat/ViewModels/ThreadWorkspaceChatViewModel.swift` — Route to cloud, handle file markers
- `Sources/SeleneChat/Views/ThreadWorkspaceView.swift` — Files section in UI
- `Sources/SeleneChat/Views/ThreadWorkspaceChatContent.swift` — File write confirmation
- `Sources/SeleneChat/App/SeleneChatApp.swift` — Inject new services
- `Sources/SeleneChat/Views/SettingsView.swift` — API key input, privacy level

### Acceptance Criteria (Phase 2)

- [ ] Planning queries route to Claude API when cloud is enabled
- [ ] Personal names, locations, health info are stripped before cloud requests
- [ ] Topic-level concepts and thread structure are preserved in sanitized context
- [ ] Claude can write files to thread workspace via FILE_WRITE markers
- [ ] Workspace files persist across sessions and are loaded into context
- [ ] User can view, edit, and delete workspace files in Thread Workspace UI
- [ ] API key stored in macOS Keychain (not in config files)
- [ ] Graceful fallback to local LLM when cloud is unavailable
- [ ] LLM tier indicator shows which model generated each response
- [ ] Settings UI allows choosing sanitization level (strict/balanced/permissive)

---

## ADHD Check

- **Reduces friction?** Yes — interactive planning means less mental overhead deciding next steps
- **Makes things visible?** Yes — workspace files externalize plans and research
- **Externalizes cognition?** Yes — the core purpose. AI does the reasoning/structuring, user validates
- **Reduces overwhelm?** Yes — clarifying questions narrow scope before producing plans

---

## Scope Check

- **Phase 1:** ~1 day (prompt rewrite only, no infrastructure)
- **Phase 2:** ~1 week (new services, UI changes, API integration, testing)
- **Total:** Fits within the < 1 week guideline per phase

---

## Investigation Needed

- **Double-response bug:** User reported receiving two responses (quick generic, then slightly more tailored). Need to reproduce and investigate — may be SwiftUI re-render or race condition in view model.

---

## Related

- `2026-01-26-phase-7.3-cloud-ai-integration.md` — Sanitization architecture (this design builds on it)
- `2026-01-26-phase-7.3-implementation-plan.md` — Original implementation tasks
- `2026-01-11-things-checklist-integration-design.md` — Benefits from cloud AI quality
- `2026-02-05-selene-thinking-partner-design.md` — Original thinking partner design
