# SeleneChat Redesign: Forest Study Design System

**Status:** Design Complete
**Created:** 2026-01-05
**Author:** Brainstorming session

---

## Overview

A complete visual redesign of SeleneChat using the "Forest Study" aesthetic — a cabin library for your thoughts. The design combines precision (Linear-style exactness) with sophistication (Mercury-style quiet confidence) using an earthy, natural color palette.

### Emotional Goals

- **Calm:** Reduce anxiety about scattered thoughts. "Your thoughts are safe here."
- **Sharp:** Cut through mental fog. "Here's exactly what matters right now."

### Design Personality

**Precision + Sophistication** — the exactness of Linear with the quiet confidence of Mercury. A tool that *has its act together*, which is exactly what an ADHD mind needs to trust.

---

## Color System

### The Palette

```
BACKGROUNDS
├── Canvas:     #FAF8F5  (warm cream - primary background)
├── Surface:    #F3F0EA  (soft linen - cards, panels)
└── Elevated:   #FFFEFA  (paper white - focused content)

BORDERS & DIVIDERS
├── Border:     #E5DED3  (warm sand - subtle lines)
└── Divider:    #EBE6DC  (lighter sand - section breaks)

TEXT
├── Primary:    #2C2416  (deep earth - headlines, body)
├── Secondary:  #6B5F4F  (warm gray - captions, muted)
└── Tertiary:   #9A8F7F  (faded earth - timestamps, hints)

ACCENTS
├── Primary:    #4A6741  (forest sage - actions, focus)
├── Secondary:  #5B7C8A  (muted blue - links, info)
├── Warm:       #B5694D  (terracotta - energy, alerts)
└── Success:    #5A7C5A  (moss green - confirmations)
```

### Depth Strategy

**Surface color shifts only — no shadows.** Hierarchy comes from warmth:
- Canvas (`#FAF8F5`) → Surface (`#F3F0EA`) → Elevated (`#FFFEFA`)
- Borders only where truly needed, at `0.5px` warm sand

---

## Typography System

### The Approach: Scholarly Interface

Serif typefaces for reading (notes, threads, AI responses) create a book-like quality. Sans-serif for UI controls keeps the interface crisp.

### Type Stack

```
READING (Serif)
├── Font:       Charter, Georgia, serif
├── Body:       15px / 1.6 line-height
├── Note title: 17px / 600 weight
└── Blockquote: 15px / italic

UI (Sans-serif)
├── Font:       SF Pro, system-ui, sans-serif
├── Labels:     13px / 500 weight
├── Captions:   11px / 400 weight
├── Buttons:    13px / 500 weight
└── Headers:    14px / 600 weight / -0.01em tracking

MONOSPACE (Data)
├── Font:       SF Mono, monospace
├── Timestamps: 11px / tabular-nums
├── IDs/codes:  12px
```

### Hierarchy Rules

| Level | Font | Size | Weight | Color |
|-------|------|------|--------|-------|
| Page title | SF Pro | 18px | 600 | Primary |
| Section header | SF Pro | 14px | 600 | Primary |
| Card title | Charter | 17px | 600 | Primary |
| Body text | Charter | 15px | 400 | Primary |
| UI label | SF Pro | 13px | 500 | Secondary |
| Caption | SF Pro | 11px | 400 | Tertiary |
| Timestamp | SF Mono | 11px | 400 | Tertiary |

---

## Layout Structure

### The Pattern: List-Detail Split

A two-panel layout where the left side provides navigation and context, the right side shows focused content.

```
┌─────────────────────────────────────────────────────────────┐
│  ┌──────────┐                                               │
│  │ Selene   │  [mode tabs: Threads | Search | Chat]        │
│  └──────────┘                                               │
├────────────────────┬────────────────────────────────────────┤
│                    │                                        │
│   LIST PANEL       │         DETAIL PANEL                   │
│   (280px fixed)    │         (flexible)                     │
│                    │                                        │
│   Thread list      │    Selected thread content             │
│   Project groups   │    Note detail                         │
│   Search results   │    Chat conversation                   │
│                    │                                        │
└────────────────────┴────────────────────────────────────────┘
```

### Panel Specifications

| Element | Value |
|---------|-------|
| List panel width | 280px fixed |
| Detail panel | Flexible, min 400px |
| Panel divider | 1px `#E5DED3` border, no shadow |
| List panel background | Surface (`#F3F0EA`) |
| Detail panel background | Canvas (`#FAF8F5`) |

### Mode Tabs

Three modes as subtle horizontal tabs:
- **Threads** — Thought threads grouped by project
- **Search** — Find across all notes
- **Chat** — Open conversation with AI

Tabs: SF Pro 13px/500, forest sage underline for active state.

---

## Core Components

### Cards & Surfaces

```
THREAD CARD (in list)
┌─────────────────────────────┐
│  Project Name          12m  │  ← SF Pro 11px, tertiary
│  Thread title here          │  ← Charter 15px/600, primary
│  Two lines of preview       │  ← Charter 14px, secondary
│  text maximum...            │
│                             │
│  ● 3 tasks    ◐ In progress │  ← SF Pro 11px, tertiary + sage
└─────────────────────────────┘

Background: Surface (#F3F0EA)
Selected: Elevated (#FFFEFA) + 3px left border in sage
Padding: 12px 16px
Corner radius: 6px
Gap between cards: 8px
```

### Buttons

```
PRIMARY (actions)
├── Background:  Forest sage (#4A6741)
├── Text:        White (#FFFEFA)
├── Padding:     8px 16px
├── Radius:      6px
├── Hover:       Darken 8%

SECONDARY (less emphasis)
├── Background:  Transparent
├── Border:      1px warm sand (#E5DED3)
├── Text:        Primary (#2C2416)
├── Hover:       Surface background (#F3F0EA)

GHOST (minimal)
├── Background:  Transparent
├── Text:        Secondary (#6B5F4F)
├── Hover:       Text becomes primary
```

### Input Fields

```
TEXT INPUT
├── Background:  Elevated (#FFFEFA)
├── Border:      1px warm sand (#E5DED3)
├── Radius:      6px
├── Padding:     10px 12px
├── Font:        SF Pro 14px
├── Focus:       Border becomes sage (#4A6741)

CHAT INPUT (special)
├── Background:  Elevated (#FFFEFA)
├── Border:      1px warm sand, 2px bottom sage
├── Radius:      8px
├── Min height:  44px
├── Font:        Charter 15px (matches conversation)
```

### Status Indicators

```
Energy levels (ADHD feature):
├── High:    Terracotta dot (#B5694D)
├── Medium:  Sage dot (#4A6741)
├── Low:     Muted blue dot (#5B7C8A)

Thread status:
├── Active:     Sage left border
├── Pending:    Terracotta left border
├── Completed:  Moss green left border
├── Parked:     No border, muted text
```

---

## Conversation UI

### Message Layout

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │ Your message appears here, right-aligned,       │   You  │
│  │ in a subtle warm container.                     │        │
│  └─────────────────────────────────────────────────┘        │
│                                                     2:34 PM │
│                                                             │
│      ┌─────────────────────────────────────────────────┐    │
│  AI  │ Response text in Charter serif. Citations       │    │
│      │ appear as [1] clickable links in sage.          │    │
│      └─────────────────────────────────────────────────┘    │
│  Local · 2:34 PM                                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Message Bubbles

```
USER MESSAGE
├── Background:  Sage tint (#4A6741 at 10%)
├── Text:        Primary (#2C2416), Charter 15px
├── Alignment:   Right
├── Max width:   70%
├── Padding:     12px 16px
├── Radius:      12px (top-right: 4px)

AI MESSAGE
├── Background:  Elevated (#FFFEFA)
├── Border:      1px warm sand (#E5DED3)
├── Text:        Primary, Charter 15px
├── Alignment:   Left
├── Max width:   85%
├── Padding:     16px 20px
├── Radius:      12px (top-left: 4px)

CITATION LINK [1]
├── Color:       Forest sage (#4A6741)
├── Style:       Underline on hover
├── Font:        Inherit (Charter)
```

### AI Provider Indicator

```
┌──────────────────┐
│ 🌲 Local         │  ← Ollama/local processing
│ ☁️  Cloud         │  ← Claude API
└──────────────────┘

Font: SF Pro 11px, tertiary color
Background: none (text only)
```

### Thinking State

```
Dots: Sage color, gentle fade animation (not bouncy)
Animation: 150ms fade, staggered
Text: SF Pro 13px, tertiary
```

---

## Planning & Thread Views

### Thread List View (Left Panel)

```
┌────────────────────────────┐
│  ACTIVE PROJECTS        ▾  │  ← Section header, collapsible
├────────────────────────────┤
│  ┌────────────────────────┐│
│  │▎Home Renovation        ││  ← Sage left bar = active
│  │ Planning the kitchen   ││  ← Charter 14px
│  │ 3 tasks · Updated 2h   ││  ← SF Pro 11px, tertiary
│  └────────────────────────┘│
│  ┌────────────────────────┐│
│  │ Career Planning        ││
│  │ Resume updates needed  ││
│  │ 1 task · Updated 1d    ││
│  └────────────────────────┘│
├────────────────────────────┤
│  INBOX (4)              ▾  │  ← Count badge in terracotta
├────────────────────────────┤
│  ┌────────────────────────┐│
│  │▎Thought about moving   ││  ← Terracotta bar = needs triage
│  │ Raw note, unsorted     ││
│  │ 15m ago                ││
│  └────────────────────────┘│
├────────────────────────────┤
│  PARKED                 ▸  │  ← Collapsed by default
└────────────────────────────┘
```

### Section Headers

```
SECTION HEADER
├── Font:        SF Pro 11px, 600 weight
├── Color:       Tertiary (#9A8F7F)
├── Transform:   Uppercase, 0.05em tracking
├── Padding:     12px 16px 8px
├── Chevron:     Right (collapsed) / Down (expanded)
├── Count badge: Terracotta background for inbox
```

### Project Detail View (Right Panel)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Home Renovation                              [Park] [···]  │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  THREADS                                                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Planning the kitchen                                │    │
│  │ Last updated 2 hours ago · 3 tasks                  │    │
│  │                                                     │    │
│  │ "Should we go with IKEA or custom cabinets?         │    │
│  │  Need to measure the space first..."                │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Budget breakdown                                    │    │
│  │ Last updated 3 days ago · 0 tasks                   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  [+ New Thread]                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Project title: SF Pro 18px/600
Thread cards: Surface background, 12px padding
New thread button: Ghost style
```

---

## Iconography

Use SF Symbols (native macOS) for consistency.

```
NAVIGATION
├── Threads:     text.bubble (or list.bullet.rectangle)
├── Search:      magnifyingglass
├── Chat:        bubble.left.and.bubble.right

ACTIONS
├── New:         plus
├── Send:        arrow.up.circle.fill
├── Settings:    gearshape
├── Back:        chevron.left

STATUS
├── Active:      circle.fill (sage)
├── Pending:     circle.fill (terracotta)
├── Complete:    checkmark.circle.fill (moss)
├── Parked:      moon.zzz (tertiary)

THREAD TYPES
├── Planning:    lightbulb
├── Task list:   checklist
├── Research:    book
├── Quick note:  note.text
```

### Icon Treatment

- Size: 14px for inline, 16px for navigation
- Color: Inherit from text (secondary by default)
- Active state: Forest sage
- No background containers unless grouped

---

## Motion

Restrained, functional motion. No bouncy springs.

```
TIMING
├── Micro (hover, focus):     100ms
├── Standard (panels, cards): 150ms
├── Navigation (mode switch): 200ms

EASING
├── Default:  ease-out (quick start, gentle stop)
├── Enter:    ease-out
├── Exit:     ease-in

WHAT ANIMATES
├── Hover states:       Opacity/color shift
├── Selection:          Background fade
├── Panel transitions:  Crossfade content
├── Collapse/expand:    Height + opacity

WHAT DOESN'T
├── No bounce/spring
├── No sliding panels
├── No elaborate loading spinners
```

---

## ADHD-Specific Features

```
ENERGY INDICATORS
├── Visual:     Colored dot before task/thread title
├── Colors:     Terracotta (high), Sage (medium), Blue (low)
├── Placement:  Consistent left position, always visible

INBOX COUNT
├── Badge:      Terracotta background, white text
├── Purpose:    "This needs attention" without anxiety
├── Placement:  Next to "Inbox" section header

FOCUS MODE (future)
├── Hides:      Sidebar, section headers
├── Shows:      Only current thread/conversation
├── Trigger:    Double-click thread or keyboard shortcut

PROGRESS VISIBILITY
├── Task counts shown on threads
├── Completion states clearly marked
├── "Last updated" timestamps for context
```

---

## Implementation Notes

### SwiftUI Considerations

1. **Colors:** Define as `Color` extensions with semantic names
2. **Typography:** Use custom `Font` modifiers for Charter serif
3. **Spacing:** Define spacing scale as constants (4, 8, 12, 16, 24, 32)
4. **Components:** Build reusable view components for cards, buttons, inputs

### File Structure Suggestion

```
SeleneChat/Sources/
├── Design/
│   ├── Colors.swift         # Color palette extensions
│   ├── Typography.swift     # Font definitions
│   ├── Spacing.swift        # Spacing constants
│   └── Components/
│       ├── ThreadCard.swift
│       ├── MessageBubble.swift
│       ├── SectionHeader.swift
│       └── ...
```

### Migration Strategy

1. Create design system files first (colors, typography, spacing)
2. Build new components alongside existing ones
3. Migrate views one at a time, starting with Chat
4. Remove old components after full migration

---

## Summary

The Forest Study redesign transforms SeleneChat from a generic SwiftUI app into a distinctive, calming workspace. Key differentiators:

- **Earthy palette** instead of typical tech-cool grays
- **Serif typography** for content, creating a book-like reading experience
- **Surface color shifts** instead of shadows for depth
- **Moderate density** balancing calm and efficiency
- **Restrained motion** respecting the calm goal

The result should feel like a quiet cabin library where scattered thoughts can settle and organize themselves.
