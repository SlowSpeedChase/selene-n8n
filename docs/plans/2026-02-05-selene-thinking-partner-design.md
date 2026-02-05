# Selene Thinking Partner

**Date:** 2026-02-05
**Status:** Vision
**Author:** Chase + Claude

---

## Problem

You capture thoughts throughout the day. The system organizes them into threads. But you still have to remember to check, manually connect dots, and figure out what to do. The cognitive load is still on you.

SeleneChat today is **reactive** - you ask, it answers. But a thinking partner should be **proactive** and maintain **continuity**.

---

## Solution

Transform SeleneChat from a query tool into a thinking partner that:

1. **Briefs you** when you open the app - surfaces what's active without asking
2. **Synthesizes** across threads when you ask "what should I focus on?"
3. **Dives deep** into specific threads, identifying tensions and suggesting actions
4. **Dialogues** with you - remembers what you just said, builds on it, helps think through to action

---

## ADHD Value

| Feature | Cognitive Benefit |
|---------|-------------------|
| Morning briefing | Reduces "where do I start?" paralysis |
| Cross-thread synthesis | Externalizes prioritization |
| Thread deep-dive | Turns fuzzy thinking into concrete steps |
| Conversation memory | Holds context so you don't have to |

---

## User Experience

### Opening the App (Morning Briefing)

```
┌─────────────────────────────────────────────────┐
│  Good morning. Here's where your thinking is:   │
│                                                 │
│  🔥 Event-Driven Architecture (11 notes)        │
│     Momentum: high | Last: yesterday            │
│     "You're circling around testing strategies  │
│     but haven't committed to an approach yet."  │
│                                                 │
│  📝 Project Journey (3 notes)                   │
│     Momentum: moderate | Last: 3 days ago       │
│     "Early exploration. No clear direction."    │
│                                                 │
│  💡 Suggested focus: Event-Driven Architecture  │
│     has momentum. Want to dig into it?          │
│                                                 │
│  [Yes, let's dig in]  [Show me something else]  │
└─────────────────────────────────────────────────┘
```

### Cross-Thread Synthesis

**User:** what should I focus on this week?

**Selene:** Looking across your threads...

Your Event-Driven Architecture thread has the most momentum - you've added 4 notes in the past week. The tension I see: you're weighing testing approaches but keep circling without deciding.

Project Journey is quieter but has a note from Tuesday about "wanting to document the why behind decisions." That connects to your architecture thinking - maybe the action is to write down your testing decision and reasoning?

Suggested focus:
1. Decide on testing approach for event-driven work
2. Document the decision (feeds Project Journey too)

Want me to help you think through the testing decision?

### Thread Deep-Dive with Dialogue

**User:** yes, help me think through the testing decision

**Selene:** From your notes, you've mentioned:
- Unit tests feel insufficient for event flows [note from Jan 8]
- Integration tests are slow but catch real bugs [note from Jan 6]
- You're curious about contract testing [note from Jan 9]

The tension: you want confidence without slow feedback loops.

Questions to clarify your thinking:
- What's breaking in production that tests should catch?
- How fast does "fast enough" need to be?

**User:** honestly the main thing breaking is events getting out of sync

**Selene:** That points toward contract testing or event schema validation - catching the interface, not the implementation.

Want me to turn this into an action? Something like:
"Spike: Set up contract tests for 2 event types (2 hours)"

**User:** yes, that's good

**Selene:** Added to your action list. Anything else on this thread or should we look at something else?

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      SeleneChat App                          │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ BriefingView │  │   ChatView   │  │ ThreadView   │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                 │                 │                │
│         └────────────┬────┴────────────────┘                │
│                      ▼                                       │
│              ┌───────────────┐                               │
│              │ ChatViewModel │ ◄── Conversation Memory       │
│              └───────┬───────┘                               │
│                      │                                       │
│         ┌────────────┼────────────┐                         │
│         ▼            ▼            ▼                         │
│  ┌─────────────┐ ┌────────┐ ┌──────────────┐               │
│  │ContextBuilder│ │ Ollama │ │ ActionService│               │
│  └──────┬──────┘ └────────┘ └──────────────┘               │
│         │                                                    │
│         ▼                                                    │
│  ┌─────────────────────────────────────────┐                │
│  │           DatabaseService                │                │
│  │  (threads, notes, associations)          │                │
│  └─────────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### New Components

| Component | Responsibility |
|-----------|----------------|
| **ConversationMemory** | Holds current conversation turns. Persists across app lifecycle. Provides context for each LLM call. |
| **ContextBuilder** | Assembles the right data for each query type: threads, notes, recent activity, prior conversation. Keeps prompts focused. |
| **BriefingGenerator** | On app open, pulls active threads + momentum + recent notes. Generates briefing via Ollama. |
| **ActionService** | Extracts concrete actions from dialogue. Optionally sends to Things 3. |

### Key Design Decisions

1. **Conversation memory is session-scoped** - Resets when you close the app. Keeps it simple. (Future: persist across sessions)

2. **Context window management** - ContextBuilder summarizes older turns to stay within Ollama's limits. Recent turns verbatim, older turns compressed.

3. **Prompt specialization** - Different prompts for briefing vs. synthesis vs. deep-dive. Each optimized for its purpose.

4. **No pre-computation** - Everything generated on-demand. Keeps architecture simple. Revisit if latency becomes a problem.

---

## Prompts

### Briefing Prompt (on app open)

```
System: You are Selene, a thinking partner for someone with ADHD.
Your job is to help them see where their thinking is and what
deserves attention. Be concise, warm, and actionable.

Context:
- Active threads with momentum scores
- Most recent note per thread (last 7 days)
- Thread summaries and "why" statements

Task: Generate a morning briefing that:
1. Summarizes what's active (2-3 threads max)
2. Notes any tensions or unresolved questions you see
3. Suggests one thread to focus on and why
4. Ends with a question that invites engagement

Keep it under 150 words. No fluff.
```

### Cross-Thread Synthesis Prompt

```
System: You are Selene. The user wants help prioritizing across
their threads of thinking. Look for momentum, tensions, and
connections between threads.

Context:
- All active threads with summaries, note counts, momentum
- Recent notes from each thread (last 14 days)
- Conversation history (if any)

Task: Help them decide what to focus on by:
1. Identifying which thread has momentum (recent activity)
2. Noting any tensions or stuck points
3. Finding connections between threads (if any)
4. Suggesting 1-2 concrete focus areas
5. Offering to go deeper on one

Be direct. Avoid "it depends." Make a recommendation.
```

### Thread Deep-Dive Prompt

```
System: You are Selene. The user wants to explore a specific
thread of thinking. Help them understand what they've been
thinking, where the tensions are, and what actions might emerge.

Context:
- Thread summary and "why"
- All notes in this thread (chronological)
- Conversation history from this session

Task:
1. Synthesize the key ideas in this thread
2. Identify tensions, contradictions, or unresolved questions
3. Ask clarifying questions to help them think
4. When ready, propose concrete next actions

This is a dialogue. Don't dump everything at once. Respond to
what they say. Build toward action incrementally.
```

---

## Data Flow

### Morning Briefing Flow

```
1. App opens
   │
2. BriefingGenerator.generate()
   │
3. ContextBuilder.buildBriefingContext()
   ├── DatabaseService.getActiveThreads(limit: 5)
   ├── DatabaseService.getRecentNotes(days: 7, perThread: 2)
   └── Returns: { threads: [...], recentNotes: [...] }
   │
4. Format context + briefing prompt
   │
5. OllamaService.generate(prompt)
   │
6. Parse response, display in BriefingView
   │
7. User taps "Yes, let's dig in"
   │
8. ConversationMemory.addTurn(briefing, userResponse)
   │
9. Switch to ChatView with thread context loaded
```

---

## Implementation Phases

### Phase 1: Conversation Memory (Foundation) ✅ COMPLETE

**Components:**
- `SessionContext` model - stores turns, provides formatted history
- Token-aware truncation - keeps recent turns verbatim
- Summary generation for older turns (simple heuristic)
- Integration with `ChatViewModel`
- Toggle for enabling/disabling history

**Acceptance Criteria:**
- [x] Can have multi-turn conversation where Selene remembers prior messages
- [x] Context stays within token limits (compress after ~10 turns)
- [x] Memory clears on new session (not app restart)

---

### Phase 2: Context Builder ✅ COMPLETE

**Components:**
- `ThinkingPartnerQueryType` enum - briefing, synthesis, deepDive with token budgets
- `ThinkingPartnerContextBuilder` service - assembles thread-focused context
- `buildBriefingContext()` - threads + momentum + recent notes
- `buildSynthesisContext()` - cross-thread comparison with note titles
- `buildDeepDiveContext()` - full thread with chronological notes

**Acceptance Criteria:**
- [x] Briefing context includes threads + momentum + recent notes
- [x] Synthesis context includes cross-thread data
- [x] Deep-dive context includes full thread history
- [x] Never exceeds context window (token budget enforcement)

---

### Phase 3: Morning Briefing ✅ COMPLETE

Proactive surfacing on app open.

**Components:**
- `BriefingView` - displays generated briefing
- `BriefingGenerator` - assembles context, calls Ollama
- Quick action buttons - "dig in", "show something else"
- Transition to chat with context preserved

**Acceptance Criteria:**
- [x] Opening app shows briefing (not empty chat)
- [x] Briefing loads in <5 seconds (depends on Ollama)
- [x] Tapping "dig in" starts conversation with thread context
- [x] Can dismiss briefing and go to regular chat

---

### Phase 4: Thread Deep-Dive

Dialogue flow for exploring a specific thread.

**Components:**
- Enhanced thread prompts - tension identification, questions
- Action extraction - recognize when user agrees to action
- `ActionService` - capture actions, optionally send to Things 3
- Conversation flow - Selene asks questions, builds to action

**Acceptance Criteria:**
- [ ] Can have back-and-forth about a thread
- [ ] Selene identifies tensions from notes
- [ ] Selene proposes concrete actions
- [ ] Actions can be captured (even if just displayed)

---

### Phase 5: Cross-Thread Synthesis

Looking across all threads to help prioritize.

**Components:**
- Synthesis prompt - connections, momentum, recommendations
- "What should I focus on?" detection in QueryAnalyzer
- Cross-thread context assembly
- Priority recommendations with reasoning

**Acceptance Criteria:**
- [ ] Asking "what should I focus on?" triggers synthesis
- [ ] Response considers all active threads
- [ ] Makes concrete recommendation (not wishy-washy)
- [ ] Can transition to deep-dive on recommended thread

---

## Phase Dependencies

```
Phase 1: Conversation Memory
    │
    ▼
Phase 2: Context Builder
    │
    ├──────────┬──────────┐
    ▼          ▼          ▼
Phase 3    Phase 4    Phase 5
Briefing   Deep-Dive  Synthesis
```

Phases 3-5 can be built in parallel once 1-2 are complete.

---

## Scope Check

| Phase | Estimate | Risk |
|-------|----------|------|
| 1. Conversation Memory | 2-3 days | Low - clear scope |
| 2. Context Builder | 2-3 days | Medium - token management |
| 3. Morning Briefing | 2-3 days | Low - mostly UI |
| 4. Thread Deep-Dive | 3-4 days | Medium - prompt tuning |
| 5. Cross-Thread Synthesis | 1-2 days | Low - builds on existing |

**Total:** ~2 weeks focused work

---

## ADHD Check

- [x] **Reduces friction?** Yes - proactive briefing eliminates "where do I start?"
- [x] **Makes thinking visible?** Yes - surfaces threads, tensions, momentum
- [x] **Externalizes cognition?** Yes - Selene holds conversation context
- [x] **Leads to action?** Yes - dialogue builds toward concrete next steps

---

## Open Questions

1. Should conversation memory persist across sessions? (Deferred to future)
2. Where do captured actions go? (Things 3? Database? Both?)
3. How to handle Ollama being slow/unavailable? (Show cached briefing?)

---

## Success Criteria

The feature is working when:

1. You open SeleneChat and immediately see what's active in your thinking
2. You can ask "what should I focus on?" and get a real recommendation
3. You can have a back-and-forth conversation that builds to action
4. Selene remembers what you said earlier in the conversation
5. You close the app feeling like you have a clear next step

---

## Related Documents

- `docs/plans/2026-01-04-selene-thread-system-design.md` - Thread system foundation
- `docs/plans/2026-02-04-conversation-memory-design.md` - Prior memory exploration
- `.claude/ADHD_Principles.md` - Design principles
