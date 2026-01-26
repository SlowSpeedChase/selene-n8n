# Today View Design

**Status:** Ready for Implementation
**Created:** 2026-01-26
**Purpose:** ADHD-optimized landing page showing new captures and heating threads

---

## Overview

The Today view is a new default landing page in SeleneChat. When you open the app without a specific purpose, this view shows what's worth your attention right now.

**Problem:** Opening SeleneChat requires already knowing what you want to ask. For ADHD users, this creates friction - you open the app, see a blank chat, and have to generate intent from scratch.

**Solution:** A dashboard that surfaces new notes and active threads, letting you scan and follow your interest rather than forcing a specific query.

---

## Navigation

### Tab Order

1. **Today** (new, default)
2. **Chat**
3. **Search**
4. **Planning**

Today becomes the landing page. Chat, Search, and Planning remain available as tabs.

---

## Layout

Two-column layout, side by side:

```
┌─────────────────────────────────────────────────────────┐
│  Today                                                   │
├───────────────────────────┬─────────────────────────────┤
│                           │                             │
│   NEW CAPTURES            │   HEATING UP                │
│                           │                             │
│   ┌───────────────────┐   │   ┌───────────────────────┐ │
│   │ Note title   2h   │   │   │ 🔥 Thread Name     5  │ │
│   │ First line of...  │   │   │ Summary snippet...    │ │
│   │ → 🔥 Thread Name  │   │   │ • recent note 1       │ │
│   └───────────────────┘   │   │ • recent note 2       │ │
│                           │   │ • recent note 3       │ │
│   ┌───────────────────┐   │   └───────────────────────┘ │
│   │ Another note      │   │                             │
│   │ Preview text...   │   │   ┌───────────────────────┐ │
│   │ (no thread yet)   │   │   │ 🔥 Another Thread  3  │ │
│   └───────────────────┘   │   │ Summary...            │ │
│                           │   │ • note title          │ │
│                           │   └───────────────────────┘ │
└───────────────────────────┴─────────────────────────────┘
```

---

## New Captures Column

### Definition of "New"

A note is "new" if created after the **later** of:
- 24 hours ago
- Last app open timestamp

This ensures you never miss notes from a busy day, even if you briefly opened the app.

### Card Content

```
┌─────────────────────────────────────────┐
│ Home renovation ideas            2h ago │
│ Thinking about knocking out the wall   │
│ between kitchen and living room...      │
│                                         │
│ → 🔥 House Projects                     │
└─────────────────────────────────────────┘
```

- **Title** (bold) + **relative timestamp** (right-aligned, muted)
- **Preview** - First ~80 characters of note content
- **Thread link** (if connected) - Arrow + emoji + thread name

### Interactions

- **Click card** → Open note detail view (modal/sheet)
- **Click thread link** → Jump to Chat with "What's happening with [thread]?"

### Empty State

```
┌─────────────────────────────────────────┐
│                                         │
│   No new notes since yesterday          │
│                                         │
│   Your last capture was 2 days ago.     │
│   [Open Drafts]                         │
│                                         │
└─────────────────────────────────────────┘
```

### Data Query

```sql
SELECT r.id, r.title, r.content, r.created_at, t.name as thread_name, t.id as thread_id
FROM raw_notes r
LEFT JOIN thread_notes tn ON r.id = tn.raw_note_id
LEFT JOIN threads t ON tn.thread_id = t.id
WHERE r.created_at > :cutoff
  AND r.test_run IS NULL
ORDER BY r.created_at DESC
LIMIT 10
```

---

## Heating Up Column

### Ranking

Threads sorted by `momentum_score` descending. Show top 5 threads max.

### Card Content

```
┌─────────────────────────────────────────┐
│ 🔥 House Projects                    5  │
├─────────────────────────────────────────┤
│ Exploring ideas for making the house    │
│ feel more like home, focusing on...     │
├─────────────────────────────────────────┤
│ • Home renovation ideas                 │
│ • Paint color research                  │
│ • Kitchen layout thoughts               │
└─────────────────────────────────────────┘
```

- **Thread name** (bold) with 🔥 + **note count** (right-aligned)
- **Summary snippet** - First ~100 characters of LLM summary
- **Recent notes** - Up to 3 most recent note titles

### Interactions

- **Click card** → Jump to Chat with "What's happening with [thread name]?"

### Empty State

```
┌─────────────────────────────────────────┐
│                                         │
│   No threads heating up right now       │
│                                         │
│   Threads gain momentum when you add    │
│   notes to the same line of thinking.   │
│                                         │
└─────────────────────────────────────────┘
```

### Data Queries

Threads:
```sql
SELECT t.id, t.name, t.summary, t.momentum_score, t.note_count
FROM threads t
WHERE t.status = 'active'
  AND t.momentum_score > 0
ORDER BY t.momentum_score DESC
LIMIT 5
```

Recent notes per thread:
```sql
SELECT r.title
FROM raw_notes r
JOIN thread_notes tn ON r.id = tn.raw_note_id
WHERE tn.thread_id = :thread_id
ORDER BY r.created_at DESC
LIMIT 3
```

---

## Session Tracking

### Last App Open

Store in UserDefaults:

```swift
// On app launch, before loading Today view:
let lastOpen = UserDefaults.standard.object(forKey: "lastAppOpen") as? Date

// After Today view loads:
UserDefaults.standard.set(Date(), forKey: "lastAppOpen")
```

### Cutoff Calculation

```swift
func getNewCutoff() -> Date {
    let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
    let lastOpen = UserDefaults.standard.object(forKey: "lastAppOpen") as? Date
                   ?? Date.distantPast
    return min(twentyFourHoursAgo, lastOpen)
}
```

### Refresh Behavior

- **On appear:** Fetch fresh data
- **Pull to refresh:** Manual refresh gesture
- **Background return:** Refresh if >5 minutes since last fetch

---

## Chat Integration

When a thread is tapped, navigate to Chat with pre-filled message:

```swift
// ContentView coordination
@State private var pendingThreadQuery: String?

// In TodayView callback:
pendingThreadQuery = "What's happening with \(thread.name)?"
selectedView = .chat

// ChatView receives initialQuery parameter
struct ChatView: View {
    var initialQuery: String? = nil

    .onAppear {
        if let query = initialQuery, !query.isEmpty {
            inputText = query
        }
    }
}
```

The existing thread query detection handles the response.

---

## Implementation Structure

### New Files

| File | Purpose |
|------|---------|
| `Sources/Models/TodayModels.swift` | NoteWithThread, ThreadSummary structs |
| `Sources/Services/TodayService.swift` | Database queries for Today view |
| `Sources/Views/TodayView.swift` | Main Today dashboard view |

### Modified Files

| File | Change |
|------|--------|
| `Sources/App/ContentView.swift` | Add Today tab, make it default |
| `Sources/Views/ChatView.swift` | Accept optional initialQuery parameter |

### Model Definitions

```swift
struct NoteWithThread: Identifiable {
    let id: Int64
    let title: String
    let preview: String
    let createdAt: Date
    let threadName: String?
    let threadId: Int64?
}

struct ThreadSummary: Identifiable {
    let id: Int64
    let name: String
    let summary: String
    let noteCount: Int
    let momentumScore: Double
    let recentNoteTitles: [String]
}
```

---

## Edge Cases

### Both Columns Empty

Centered message replacing both columns:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                   All caught up                         │
│                                                         │
│   No new notes since yesterday, and no threads are      │
│   heating up right now. A good time to:                 │
│                                                         │
│   [Capture a thought]     [Browse past notes]           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Loading State

Skeleton placeholders while data loads.

### Error State

Friendly error message with "Try Again" button.

---

## Accessibility

- All cards keyboard-navigable
- VoiceOver labels: "Note: Home renovation ideas, captured 2 hours ago, in thread House Projects"
- Respect reduced motion preferences

---

## Future Enhancements (Not in Scope)

- "Mark all seen" button to manually clear new captures
- Cooling Down section for dormant threads
- Orphan Notes section for unthreaded captures
- Push notifications when threads heat up
- Daily digest email/notification

---

## Success Criteria

1. User can open SeleneChat and immediately see what's new
2. User can navigate to a thread conversation with one click
3. User can read a recent note without typing anything
4. Empty states guide user toward productive actions
5. View loads in <500ms on typical data volume
