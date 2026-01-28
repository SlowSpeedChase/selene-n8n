# Selene's Spatial Design Philosophy

> **Status:** Future Vision (post-SeleneChat stability)
> **Started:** 2026-01-27
> **Purpose:** Capture the vision for visual/spatial knowledge management in Selene
> **Priority:** After task creation/tracking is working and in regular use

---

## The Core Insight

Traditional knowledge management fails ADHD brains because it relies on **hierarchical navigation**—folders, trees, nested structures. The problem: **out of sight, out of mind**. If I can't see it, it doesn't exist in my working memory.

Selene needs to be **spatial**, not hierarchical.

---

## The Cork Board Metaphor

Imagine a physical cork board covered in notes, photos, strings connecting ideas. This is how my brain wants to work:

- **Everything visible at once** — no hidden folders
- **Spatial memory** — I remember *where* something is, not what I named it
- **Physical manipulation** — moving things around *is* thinking
- **Clusters emerge naturally** — related things drift together
- **Strings show connections** — relationships are visible, not metadata

The digital version: an **infinite canvas** where notes can be:
- Placed freely in 2D space
- Stacked and layered (z-axis)
- Connected with visible links
- Touched and dragged (future: touch screen)
- Zoomed and panned fluidly

---

## Layers: Hierarchy Without Hiding

The key innovation: **vertical layers** that add structure without making things disappear.

Instead of folders that hide content, imagine layers you can:
- **Rise above** to see the big picture (themes, patterns, projects)
- **Dive into** for detail (individual notes, raw captures)
- **Move between** fluidly, like adjusting altitude

### The Cube Model

Think of it as **3D storage**:
- **X/Y axes** = spatial arrangement on the canvas (clustering, proximity)
- **Z axis** = depth/layers (abstraction level, time, or context)

Like a cube you can rotate, zoom into, slice through. Not just a flat board—a *volume* of knowledge.

### Possible Layer Types

**Abstraction layers:**
```
     [Projects / Goals]
          ↑
     [Themes / Patterns]
          ↑
     [Threads / Conversations]
          ↑
     [Raw Notes / Captures]
```

**Temporal layers:**
- Today's active thinking (top)
- This week's context
- Historical archive (deeper)

**Context layers:**
- Work
- Personal
- Creative
- Different planes, same spatial logic

*Question: Are these different models, or can they coexist?*

---

## Graph View vs. Canvas

Two complementary modes:

| Graph View | Canvas |
|------------|--------|
| Automatic relationships | Manual arrangement |
| Shows what's connected | Shows how I think about connections |
| Algorithm-driven | Human-driven |
| Discovery tool | Thinking tool |

The graph shows me connections I didn't know existed.
The canvas lets me *work* with those connections spatially.

Maybe: Graph view *suggests* arrangements, canvas lets me *confirm* and refine them?

---

## Where SeleneChat Fits

Open questions:
- Is SeleneChat a floating panel over the canvas?
- Does conversation *create* spatial arrangements? (Chat about a topic → notes cluster)
- Can I ask SeleneChat "show me everything related to X" and have it arrange the canvas?
- Is SeleneChat the voice interface to spatial navigation?

---

## Touch Screen Vision

Future state: Selene on a touch screen (iPad? Touch-enabled Mac?)

- Literal manipulation of notes with fingers
- Pinch to zoom between layers
- Drag to cluster
- Two-finger to draw connections
- Flick to archive/dismiss

This makes the cork board metaphor *literal*.

---

## ADHD Design Principles Applied

How this connects to the core ADHD principles:

| Principle | Spatial Application |
|-----------|---------------------|
| **Externalize working memory** | Canvas IS external working memory—visible, manipulable |
| **Make time visible** | Temporal layers show when things happened |
| **Reduce friction** | Spatial navigation faster than folder drilling |
| **Visual over mental** | Everything visible, nothing hidden |
| **Realistic over idealistic** | Organic clustering vs. perfect taxonomies |

---

## Obsidian Integration

Why Obsidian was appealing:
- **Graph view** already exists
- **Canvas** already exists
- Plugin ecosystem for customization
- Markdown files = Selene's current export format

Possible approach:
- Selene handles capture, processing, AI enrichment
- Obsidian provides the spatial/visual layer
- Sync between them (already have Obsidian export)

Or: Build native spatial features in SeleneChat?

Trade-offs to consider...

---

## Decisions Made

**How do new captures enter the spatial world?**
→ **Auto-cluster.** New captures automatically drift toward related content based on embeddings. No inbox guilt pile. Search is always the fallback—loss of control isn't a concern because you can always find things.

**Manual vs. automatic arrangement?**
→ **Both.** Chat-driven placement for quick integration ("this relates to X project"). Manual arrangement on a LARGE screen when you want to see everything and think spatially. The system suggests, you can override.

**Interaction model?**
→ **Freeform-style.** Zoomable infinite canvas. Pinch to zoom in/out. See everything at high altitude, dive into clusters. Like Apple Freeform on iPad.

## Open Questions

1. When I touch a note on the canvas, what happens? Does it expand? Show connections? Let me write inline?

2. How do layers interact? Can a note exist on multiple layers?

3. What's the relationship between Selene's automatic associations and manual canvas arrangement?

4. What hardware? Large monitor? iPad? Touch-enabled Mac?

---

## Inspirations

- **Apple Freeform** — zoomable infinite canvas, touch-native, the gold standard for feel
- **Obsidian Canvas** — infinite canvas with linked notes
- **Obsidian Graph View** — automatic relationship visualization
- **Miro/FigJam** — collaborative infinite canvas
- **Scapple** — freeform idea arrangement
- **Physical cork boards** — the original spatial thinking tool
- **Minority Report interface** — gestural manipulation of information
- **3D file managers** (conceptual) — cube/volume-based navigation

---

## Next Steps

- [ ] Answer the open questions above
- [ ] Sketch what this looks like (paper? Figma?)
- [ ] Decide: Obsidian integration vs. native SeleneChat spatial features
- [ ] Explore existing canvas/graph libraries for Swift/macOS
- [ ] Write about daily workflow and where spatial thinking fits

---

*This is a living document. Add to it as the vision develops.*
