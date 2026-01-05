# SeleneChat Interface Design Inspiration

**Status:** Research Complete
**Created:** 2026-01-05
**Purpose:** Synthesize design patterns from best-in-class apps for SeleneChat improvements

---

## Executive Summary

Research across PKM apps (Obsidian, Notion, Logseq), ADHD productivity tools (Things 3, Sunsama), and AI interfaces (Perplexity, Raycast) reveals consistent patterns that could enhance SeleneChat. The themes are:

1. **Progressive disclosure** - Hide complexity until needed
2. **Quick capture** - One action to externalize thoughts
3. **Visual hierarchy** - Guide attention, reduce decisions
4. **Trust through transparency** - Citations and sources visible
5. **Polish through accumulation** - Many small details create delight

---

## Current State

SeleneChat has three tabs:
- **Chat** - Conversational queries with `[1]` citations
- **Search** - Three-pane filtering with concepts/themes
- **Planning** - Project-based threads with Things integration

Existing ADHD-friendly patterns:
- Collapsible sections in Planning
- Energy level indicators
- Things integration for task capture
- Citation system for AI responses

---

## Design Patterns by Category

### 1. Citation & Source Design

**Source:** [Perplexity](https://www.shapeof.ai/patterns/citations), [NN/G on Perplexity](https://www.nngroup.com/articles/perplexity-henry-modisett/)

| Pattern | Current State | Opportunity |
|---------|--------------|-------------|
| Sources at top of response | Citations inline `[1]` | Show source note chips above response |
| Hover-to-preview | Click navigates away | Hover shows note snippet inline |
| Metadata for scanning | Note ID only | Show note title + date + concepts |
| Suggested follow-ups | None | Predict related questions after response |
| Broken citation handling | Silent | Explicit "source not found" messaging |

**Key insight:** "Every claim maps to a source" - citations should be embedded, not optional.

---

### 2. ADHD Task Management

**Source:** [Things 3 Design Critique](http://ixd.prattsi.org/2020/02/design-critique-things-3-ios-app/), [Eight Years with Things 3](https://meetdaniel.me/blog/eight-years-with-things-3/)

| Pattern | Current State | Opportunity |
|---------|--------------|-------------|
| Quick Entry from anywhere | Must navigate to Planning | Global `⌃Space` or `⌘K` capture |
| Progressive field disclosure | All fields visible | Tuck optional fields until needed |
| No fluff/duplication | Some redundant navigation | Audit for single-purpose elements |
| Headers as dividers | Section headings | Visual dividers within project threads |
| Transform animations | Instant transitions | Smooth expand/collapse with context |

**Key insight:** "Everything has a purpose, functionality is never duplicated."

---

### 3. Daily Planning Rituals

**Source:** [Sunsama for ADHD](https://www.sunsama.com/for-adhd), [Time Blindness with Sunsama](https://mariaisquixotic.com/manage-time-blindness-with-sunsama/)

| Pattern | Current State | Opportunity |
|---------|--------------|-------------|
| Guided daily ritual | None | Morning prompt: "What threads need attention today?" |
| Time estimates | Not captured | Add time estimate before Things export |
| Workload warnings | None | "You have 8 threads resurfacing - realistic?" |
| Visual timeline | Static list | Grey out addressed items, highlight pending |
| Focus mode | All visible | Single-project view hiding everything else |

**Key insight:** Front-load decisions in a ritual to reduce decision fatigue throughout the day.

---

### 4. Progressive Disclosure

**Source:** [Notion Progressive Disclosure](https://medium.com/design-bootcamp/how-notion-uses-progressive-disclosure-on-the-notion-ai-page-ae29645dae8d), [NN/G Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/)

| Pattern | Current State | Opportunity |
|---------|--------------|-------------|
| Minimal landing state | 5 sections visible | Default: only Active Projects expanded |
| Depth on demand | Collapsible but visible | "Show more" link for Inbox/Parked |
| Accordion navigation | Partial | Full sidebar collapse support |
| Single-focus view | List always visible | Click project → full-screen detail mode |

**Key insight:** "Initially show only the most important options. Offer specialized options upon request."

**Benefits:**
- Learnability - new users aren't overwhelmed
- Efficiency - power users access depth quickly
- Error rate - fewer visible options = fewer mistakes

---

### 5. Knowledge Graphs & Linking

**Source:** [Obsidian Core Principles](https://medium.com/obsidian-observer/obsidian-understanding-its-core-design-principles-7f3fafbd6e36), [Logseq Graph Comparison](https://medium.com/alvistor/comparing-roamresearch-graph-view-with-logseq-and-obsidian-b0c1fd51c2ee)

| Pattern | Current State | Opportunity |
|---------|--------------|-------------|
| Graph visualization | None | Concept graph showing note/project relationships |
| Backlinks | None | "Notes mentioning this project's concepts" |
| Related content sidebar | None | "Related threads" when viewing a thread |
| Daily Notes as hub | Planning tab | "Today" view: resurfaced threads + captures |
| Filterable graph | N/A | Filter by concept, theme, date range |

**Key insight:** SeleneChat already has concept metadata - the opportunity is making connections visually explorable, not just searchable.

---

### 6. Command Palette

**Source:** [Raycast](https://www.raycast.com/), [Raycast for Engineers](https://www.pixelmatters.com/insights/raycast-for-software-engineers)

| Pattern | Current State | Opportunity |
|---------|--------------|-------------|
| Universal search | Per-tab search | `⌘K` searches notes, projects, threads, actions |
| Quick actions | Navigate then act | Type "new thread Home Renovation" directly |
| AI inline | Separate Chat tab | Ask quick question without tab switch |
| Recent items | None | Show recently accessed for quick return |
| Keyboard shortcuts | Limited | `⌘1/2/3` tabs, `⌘N` new, `⌘Enter` send |

**Key insight:** "One of the biggest productivity killers is context switching. Do everything from a single interface."

---

### 7. Cognitive Load Reduction

**Source:** [ADHD UX Design](https://medium.com/design-bootcamp/ux-design-for-adhd-when-focus-becomes-a-challenge-afe160804d94), [Neurodivergent UX](https://medium.com/design-bootcamp/inclusive-ux-ui-for-neurodivergent-users-best-practices-and-challenges-488677ed2c6e)

| Pattern | Current State | Opportunity |
|---------|--------------|-------------|
| Hick's Law (fewer options) | 5 Planning sections | Reduce visible sections to 2-3 |
| Step-by-step processes | All at once | Show one step, progress indicator |
| Pause and resume | Threads persist | Visual "where I left off" indicator |
| Whitespace | Moderate | Audit for breathing room |
| Grey completed items | Binary complete/not | Gentle visual de-emphasis |

**Key insight:** More options = harder decisions. Every screen should answer: "What's the ONE action here?"

---

### 8. Visual Polish

**Source:** [Linear Liquid Glass](https://linear.app/now/linear-liquid-glass)

| Pattern | Current State | Opportunity |
|---------|--------------|-------------|
| Consistent spacing | Good | Audit for pixel-perfect alignment |
| Hover states | Basic | Subtle feedback on interactive elements |
| Smooth transitions | Instant | Interruptible animations on expand/collapse |
| Depth cues | Flat | Subtle shadows for layering |
| Dark mode polish | Functional | Equal attention to dark mode details |

**Key insight:** "None of these details were individually complex. It's the sum total that creates an enjoyable experience."

---

## Prioritized Recommendations

### High Impact, Lower Effort

1. **Command Palette (`⌘K`)**
   - Universal search across all content types
   - Quick actions without navigation
   - Keyboard-driven workflow

2. **Citation Hover Preview**
   - Show note snippet on hover over `[1]`
   - Reduces context-switching when verifying sources

3. **Planning Tab Simplification**
   - Default only Active Projects expanded
   - Move Inbox/Parked behind "Show more"
   - Reduce visible sections from 5 to 2

4. **Keyboard Shortcuts**
   - `⌘1/2/3` for tab switching
   - `⌘N` for new thread
   - `Escape` to close modals/return

### High Impact, Higher Effort

5. **Daily Planning View**
   - Morning ritual: "What needs attention today?"
   - Consolidated view of resurfaced threads + pending tasks
   - Time estimates before Things export

6. **Concept Graph Visualization**
   - Interactive graph of concept relationships
   - Click concept → see all related notes/projects
   - Discovery of unexpected connections

7. **Focus Mode**
   - Single-project view hiding all else
   - Reduces visual noise during deep work
   - Toggle via keyboard shortcut

### Polish & Refinement

8. **Transition Animations**
   - Smooth expand/collapse on sections
   - Transform effect when opening project detail
   - Subtle, interruptible, purposeful

9. **Hover States Audit**
   - Consistent feedback on all interactive elements
   - Project cards, thread items, action buttons

10. **Spacing & Alignment Audit**
    - Pixel-perfect consistency
    - Breathing room in dense areas

---

## Design Principles (Synthesized)

Based on this research, SeleneChat should adhere to:

1. **Externalize, don't internalize** - If it requires memory, show it visually
2. **One action per context** - Every screen should have a clear primary action
3. **Hide until needed** - Progressive disclosure over upfront complexity
4. **Capture instantly** - Never more than one action away from saving a thought
5. **Trust through transparency** - Sources visible, not hidden
6. **Polish through accumulation** - Many small refinements, not flashy features

---

## Sources

### PKM / Note-Taking
- [Obsidian Core Design Principles](https://medium.com/obsidian-observer/obsidian-understanding-its-core-design-principles-7f3fafbd6e36)
- [Notion Progressive Disclosure](https://medium.com/design-bootcamp/how-notion-uses-progressive-disclosure-on-the-notion-ai-page-ae29645dae8d)
- [Logseq Graph Comparison](https://medium.com/alvistor/comparing-roamresearch-graph-view-with-logseq-and-obsidian-b0c1fd51c2ee)

### ADHD / Productivity
- [Things 3 Design Critique](http://ixd.prattsi.org/2020/02/design-critique-things-3-ios-app/)
- [Eight Years with Things 3](https://meetdaniel.me/blog/eight-years-with-things-3/)
- [Sunsama for ADHD](https://www.sunsama.com/for-adhd)
- [Time Blindness with Sunsama](https://mariaisquixotic.com/manage-time-blindness-with-sunsama/)

### AI Interfaces
- [Perplexity UX - NN/G](https://www.nngroup.com/articles/perplexity-henry-modisett/)
- [AI Citation Patterns](https://www.shapeof.ai/patterns/citations)
- [Perplexity Citation-Forward Design](https://www.unusual.ai/blog/perplexity-platform-guide-design-for-citation-forward-answers)
- [Raycast for Engineers](https://www.pixelmatters.com/insights/raycast-for-software-engineers)

### ADHD Design Patterns
- [UX Design for ADHD](https://medium.com/design-bootcamp/ux-design-for-adhd-when-focus-becomes-a-challenge-afe160804d94)
- [Inclusive UX for Neurodivergent Users](https://medium.com/design-bootcamp/inclusive-ux-ui-for-neurodivergent-users-best-practices-and-challenges-488677ed2c6e)
- [ADHD App Accessibility](https://www.focusbear.io/blog-post/adhd-accessibility-designing-apps-for-focus)

### Visual Design
- [Linear Liquid Glass](https://linear.app/now/linear-liquid-glass)
- [NN/G Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/)

---

## Next Steps

1. Review prioritized recommendations
2. Select 2-3 items for first implementation sprint
3. Create user stories for selected items
4. Prototype command palette and citation hover as quick wins
