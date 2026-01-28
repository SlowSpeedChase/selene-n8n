# Selene Design Philosophy

> **Status:** Living document
> **Started:** 2026-01-27
> **Purpose:** Define what Selene is and why it exists

---

## The Core Purpose

Selene is a **librarian for my mind**.

Not a note-taking app. Not a todo list. Not a second brain in the productivity-guru sense.

A librarian. An archivist. Someone who:
- **Captures** what I throw at them without judgment
- **Maps** how my thoughts connect
- **Researches** what I've written before
- **Surfaces** relevant things at the right times

---

## The Three Jobs

### 1. Capture

Random snippets of text. Half-formed thoughts. Links. Quotes. Fragments.

The capture layer must be:
- **Zero friction** — one tap from wherever I am (Drafts app)
- **No formatting required** — dump it in, worry about structure later
- **Always available** — phone, desktop, anywhere

I don't want to think about where something goes when I capture it. That's the librarian's job.

### 2. Map

Take the raw captures and build a map of my thinking:
- What topics keep coming up?
- What connects to what?
- What threads am I pulling on over time?
- What have I forgotten that's relevant now?

This is where the AI lives:
- Concept extraction (what is this about?)
- Embeddings (what is this similar to?)
- Associations (what relates to what?)
- Threads (what conversations span multiple notes?)

The map should be:
- **Automatic** — I don't maintain it manually
- **Visible** — I can see the structure when I want to (future: spatial canvas)
- **Trustworthy** — good enough that I don't second-guess it

### 3. Surface

The librarian doesn't wait for me to ask. They notice things:
- "You wrote about this three months ago..."
- "This connects to your project on X..."
- "You've mentioned this theme five times recently..."
- "Here's what you said last time you felt this way..."

Surfacing happens:
- **In conversation** — SeleneChat finds relevant context
- **Proactively** — daily summaries, pattern detection
- **On demand** — I ask, it retrieves

---

## Why This Matters (ADHD Context)

My brain has:
- **Limited working memory** — can't hold everything I need
- **Time blindness** — forget what I thought last week
- **Out of sight, out of mind** — if I don't see it, it doesn't exist
- **Pattern blindness** — can't see my own recurring themes

Selene compensates:
- **Externalizes memory** — captures everything before it evaporates
- **Provides temporal context** — "you wrote this on [date]"
- **Surfaces the invisible** — brings buried things back to visibility
- **Shows patterns** — "you've been thinking about X a lot"

I don't need productivity hacks. I need a reliable external system that works the way my brain can't.

---

## What Selene Is Not

- **Not a task manager** — though it can extract and route tasks
- **Not a calendar** — though it understands time
- **Not a search engine** — though search is a feature
- **Not an AI assistant** — though AI powers it

Selene is the **layer between my chaotic thoughts and usable knowledge**.

---

## The Librarian Metaphor

Imagine walking into a library where:
- You can drop off any scrap of paper and the librarian files it
- You can ask "what do I know about X?" and they pull relevant materials
- They occasionally say "you might want to revisit this"
- They know your research history and interests
- They never lose anything
- They never judge what you bring in

That's Selene.

---

## Current State vs. Vision

### Working Now
- Capture via Drafts → webhook
- LLM concept extraction
- Embedding generation
- Association/clustering
- Thread detection
- SeleneChat basic queries
- Obsidian export

### Needs Work
- Task extraction and tracking
- SeleneChat feeling like a real librarian conversation
- Proactive surfacing (not just on-demand)
- Daily/weekly summaries that actually help

### Future Vision
- Spatial canvas for visual mapping (see: spatial-design-philosophy.md)
- Touch-screen interaction
- 3D knowledge cube navigation
- Cross-device capture

---

## Design Principles

1. **Capture is sacred** — never add friction to getting things in
2. **Organization is automatic** — I don't maintain the system, it maintains itself
3. **Search is the fallback** — if clustering fails, I can always find things
4. **Show, don't hide** — visibility over tidiness
5. **Trust the system** — if I have to double-check it, it's not working
6. **Conversation is the interface** — talk to the librarian, don't navigate menus

---

## Cognitive Boundaries: Tool, Not Crutch

AI-driven tools risk reducing cognitive load in ways that atrophy real thinking. Selene must be a **tool that supports my thinking**, not a **crutch that replaces it**.

### The Line

**Selene organizes and retrieves. I interpret and decide.**

### What Selene Does (Mechanical Work)

- **Stores** — captures text without judgment
- **Organizes** — tags, clusters, and connects for findability
- **Retrieves** — finds relevant notes when asked
- **Surfaces** — prompts me to revisit things ("you wrote about this before")
- **Shows patterns** — "this theme has come up 5 times"

These are librarian tasks. A librarian shelves books, maintains the catalog, and pulls materials when asked. That doesn't make you a worse reader.

### What Stays Mine (Thinking Work)

- **Interpreting** — what do my notes mean?
- **Synthesizing** — how do these ideas connect?
- **Deciding** — what should I do with this?
- **Concluding** — what do I think about this?
- **Creating** — what new ideas come from this?

### The Spectrum

```
SAFE ◄──────────────────────────────────────► DANGEROUS

Store text   Tag/cluster   Surface      Summarize     Draw conclusions
as-is        for search    connections  my writing    about my thinking
                                           ▲
                                           │
                                     Gray area.
                              Useful but must stay
                              in service of MY reading,
                              not a replacement for it.
```

### ADHD-Specific Justification

Working memory limitations are **neurological**, not a skill deficit. Externalizing memory for ADHD is closer to **wearing glasses** than refusing to exercise. Selene compensates for a system that works differently—it doesn't replace a healthy system.

But that doesn't mean anything goes. The accommodation is **storage and retrieval**. The thinking is still mine.

### Practical Rules

1. **Retrieval over conclusion** — "Here are 5 related notes" not "Based on your notes, you should..."
2. **Concept tags are for findability** — they help search, they don't replace reading the actual notes
3. **Surfacing is a prompt to think** — "You wrote about this" not "Here's what you think about this"
4. **Threads show connections exist** — I decide what they mean
5. **Summaries assist, not replace** — if I stop reading my own notes, something is wrong
6. **I review AI outputs critically** — don't just accept what Selene says about my own thinking

---

## Open Questions

- How does the librarian's "personality" feel in SeleneChat?
- What triggers proactive surfacing? Time? Similarity? Patterns?
- How do I build trust that the system isn't losing things?
- What's the right balance of automatic vs. manual control?

---

*This is the "why" document. Implementation details live elsewhere.*
