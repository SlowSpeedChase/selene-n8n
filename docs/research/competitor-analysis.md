# Competitor Analysis: ADHD Knowledge Management & Local LLM Tools

> **Research Date:** 2026-01-27
> **Purpose:** Learn from existing approaches, not compete

---

## Context

This research explores similar apps to understand methodologies and apply learnings to Selene. Selene is a personal system first—built for my own ADHD brain—with potential to help others later.

---

## Most Directly Comparable: Privacy-First Local LLM Apps

| App | Approach | Key Similarities to Selene | Key Differences |
|-----|----------|---------------------------|-----------------|
| **[Reor](https://github.com/reorproject/reor)** | Desktop app, Ollama + LanceDB | Local LLM, embeddings, semantic search, auto-linking notes | General PKM, no ADHD focus, Electron-based |
| **[Khoj](https://github.com/khoj-ai/khoj)** | Self-hosted AI assistant | Local LLM, multi-source ingestion, custom agents | More agent-focused, less note-centric |
| **[PrivAware-PKM](https://github.com/ARTHON9611/Privacy-Aware-Personal-Knowledge-Model)** | Local GPU knowledge graphs | Privacy-first, local processing, multi-modal RAG | Research project, less polished |

### Reor - Detailed Analysis

**What they do well:**
- "Self-organizing notes" - automatic linking via vector similarity
- RAG-powered Q&A on personal corpus
- Semantic search that works "conceptually, contextually"
- Writing assistance with contextual sidebar showing related notes
- AI flashcard generation

**Technical approach:**
- Ollama for LLMs
- Transformers.js for embeddings
- LanceDB for vector storage
- Chunks and embeds every note automatically
- Electron desktop app (Mac/Linux/Windows)

**Learnings for Selene:**
- Their "related notes sidebar while writing" is interesting for SeleneChat
- Flashcard generation could help with ADHD memory reinforcement
- They use LanceDB (we're considering this migration)

### Khoj - Detailed Analysis

**What they do well:**
- Multi-source ingestion (images, PDFs, markdown, Notion, etc.)
- Custom agents with personas and specialized tools
- Scheduled automations ("personal newsletters")
- Works across Browser, Obsidian, Emacs, Desktop, Phone, WhatsApp

**Technical approach:**
- Self-hostable Python app
- Integrates with Ollama for local LLMs
- Docker or pip installation
- Can run entirely offline

**Learnings for Selene:**
- Agent system for different "modes" of thinking
- Cross-platform access patterns (WhatsApp integration interesting)
- Scheduled automations align with our launchd approach

---

## ADHD-Focused Apps

| App | Focus | Strengths | Gaps vs Selene |
|-----|-------|-----------|----------------|
| **[Saner.AI](https://www.saner.ai)** | "Built by ADHDers" | Combines notes, tasks, calendar; works with scattered thinking | Cloud-based, no local LLM |
| **[Constella App](https://radiantapp.com/blog/best-second-brain-apps)** | ADHD-specific PKM | Infinite canvas, automatic organization, AI assistant | Appears newer/less mature |
| **[Lunatask](https://lunatask.app/adhd)** | All-in-one ADHD productivity | Habit tracker, journal, pomodoro, mood tracking | More task/habit focused, less knowledge management |

### Saner.AI - Key Insights

**Their ADHD philosophy:**
- "Works how your brain naturally works—then organizes things for you behind the scenes"
- Designed to turn "messy notes, to-dos, emails, and tasks into a calm, organized day"
- Doesn't force structure upfront

**Learnings for Selene:**
- The "organize behind the scenes" principle aligns with our background processing
- Calendar integration for ADHD time blindness
- "Calm" as a design goal (vs. overwhelming dashboards)

### Lunatask - Key Insights

**Holistic approach:**
- Not just todos: habit tracker, calendar, mood tracker, journal, pomodoro, notes
- "Your thoughts find a home in a single ADHD app"
- Multiple productivity techniques to explore what works

**Learnings for Selene:**
- Mood tracking could inform pattern detection
- Habit tracking + note correlation could surface insights
- "Explore which method works best" - personalization matters

---

## Established PKM with AI Add-ons

| App | AI Integration | Pros | Cons |
|-----|---------------|------|------|
| **Obsidian + [Smart Connections](https://github.com/brianpetro/obsidian-smart-connections)** | Local embeddings, semantic search | Mature ecosystem, local-first, free | Requires plugin setup, no unified experience |
| **Obsidian + [Smart Composer](https://github.com/glowingjade/obsidian-smart-composer)** | Ollama chat, vault-aware | Local models, semantic search | Plugin fragmentation |
| **Notion AI** | Built-in AI | Polished UX, databases | Cloud-only, no local processing |

### Smart Connections - Key Insights

**What works:**
- "Local model starts creating embeddings right away. No extra apps, no CLI tools, no API key required"
- Surfaces notes "semantically related to what you are working on right now"
- Lookup view for ad-hoc semantic search

**Learnings for Selene:**
- Zero-config embedding is powerful for ADHD (no setup friction)
- "Related to what you're working on now" - context-aware suggestions
- Our SeleneChat could surface related notes during conversation

---

## Selene's Unique Positioning

Based on this research, Selene occupies a unique space:

1. **Architecture**: TypeScript + launchd background jobs (most competitors use Electron or are cloud-based)
2. **ADHD-specific + Local LLM**: Only Selene combines both—others are either ADHD-focused (cloud) or local-first (general PKM)
3. **Capture-first design**: Drafts app integration for zero-friction capture (most others are write-in-app)
4. **Thread/association system**: Automatic relationship detection more sophisticated than basic backlinking
5. **Native macOS app**: SeleneChat is Swift/SwiftUI (Reor uses Electron, Khoj is web-based)

---

## Feature Ideas from Competitors

Things to consider (not necessarily implement):

- **Flashcard generation** (Reor) - memory reinforcement
- **Custom agents/personas** (Khoj) - different thinking modes
- **Mood tracking correlation** (Lunatask) - pattern detection
- **Calendar integration** (Saner.AI) - time blindness support
- **Related notes sidebar** (Reor) - during SeleneChat conversations
- **Cross-platform capture** (Khoj) - beyond Drafts

---

## Open Questions

- How do others handle the "organize behind the scenes" without losing user agency?
- What's the right balance of automatic organization vs. explicit structure?
- How to surface insights without creating notification overload (ADHD paradox)?

---

## Sources

- [Reor Project - GitHub](https://github.com/reorproject/reor)
- [Khoj AI - GitHub](https://github.com/khoj-ai/khoj)
- [Saner.AI - ADHD Note Taking](https://www.saner.ai/blogs/best-adhd-note-taking-apps)
- [Smart Connections - GitHub](https://github.com/brianpetro/obsidian-smart-connections)
- [Second Brain Apps 2026 - Radiant](https://radiantapp.com/blog/best-second-brain-apps)
- [PKM with AI 2025 - Buildin.AI](https://buildin.ai/blog/personal-knowledge-management-system-with-ai)
- [Building PKM with Reor - KDnuggets](https://www.kdnuggets.com/building-a-personal-knowledge-management-tool-with-reor)
- [ADHD Second Brain - ADHD Pathfinder](https://www.adhdpathfinder.co.uk/post/boosting-productivity-and-memory-unleashing-the-power-of-the-second-brain-for-adhd)
