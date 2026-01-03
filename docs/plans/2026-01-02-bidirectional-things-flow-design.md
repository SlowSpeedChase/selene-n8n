# Phase 7.2e: Bidirectional Things Flow

**Status:** Ready for Implementation
**Created:** 2026-01-02
**Author:** Chase Easterling + Claude

---

## Overview

Enable SeleneChat to query task status from Things 3 and resurface planning threads based on progress triggers. When tasks are completed, stuck, or hitting deadlines, the associated planning thread moves to "review" status with a contextual message.

**Key Principle:** Sync happens on Planning tab open only - no background polling. Simple, battery-friendly, matches ADHD workflow.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        PlanningView                              │
│                            │                                     │
│                       .task { }                                  │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              ThingsStatusService                          │   │
│  │  • syncAllTaskStatuses() - batch query via AppleScript   │   │
│  │  • getTaskStatus(id) - single task query                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            ResurfaceTriggerService                        │   │
│  │  • evaluateTriggers(thread, tasks) → ResurfaceTrigger?   │   │
│  │  • Reads config/resurface-triggers.yaml                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              DatabaseService                              │   │
│  │  • resurfaceThread(id, reason)                           │   │
│  │  • fetchThreads(status: .review)                         │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Things 3 App                                │
│  • Queried via AppleScript (get-task-status.scpt)               │
│  • Returns: id, status, name, completion_date, project, tags    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Database Changes

### Migration: task_links status tracking

```sql
-- Add status tracking columns to task_links
ALTER TABLE task_links ADD COLUMN things_status TEXT DEFAULT 'open';
ALTER TABLE task_links ADD COLUMN things_completed_at TEXT;
ALTER TABLE task_links ADD COLUMN last_synced_at TEXT;
```

**Fields:**
- `things_status` - Current status from Things (`open`, `completed`, `canceled`)
- `things_completed_at` - When task was completed (ISO 8601)
- `last_synced_at` - When we last checked this task

### Migration: discussion_threads review state

```sql
-- Extend status check constraint to include 'review'
-- SQLite doesn't support ALTER CHECK, so this requires table recreation
-- or we just allow the new value (SQLite CHECK is advisory)

ALTER TABLE discussion_threads ADD COLUMN resurface_reason TEXT;
ALTER TABLE discussion_threads ADD COLUMN last_resurfaced_at TEXT;
```

**Fields:**
- `resurface_reason` - Which trigger fired (e.g., "progress_50", "stuck_3d", "completion")
- `last_resurfaced_at` - When thread was last resurfaced (for cooldown tracking)

**Status values:** `pending` → `active` → `review` → `completed` | `dismissed`

---

## Swift Services

### ThingsStatusService.swift

Bridges AppleScript to Swift using existing `get-task-status.scpt`:

```swift
import Foundation

class ThingsStatusService: ObservableObject {
    private let scriptPath: String

    init() {
        // Path to scripts/things-bridge/get-task-status.scpt
        self.scriptPath = Self.findScriptPath()
    }

    /// Query Things for a single task's status
    func getTaskStatus(thingsId: String) async throws -> ThingsTaskStatus {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [scriptPath, thingsId]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = String(data: data, encoding: .utf8) else {
            throw ThingsStatusError.invalidResponse
        }

        return try parseTaskStatus(json)
    }

    /// Batch sync all tracked tasks
    func syncAllTaskStatuses(
        taskIds: [String],
        db: DatabaseService
    ) async -> SyncResult {
        var total = 0
        var synced = 0
        var newlyCompleted = 0
        var errors = 0

        for thingsId in taskIds {
            total += 1
            do {
                let status = try await getTaskStatus(thingsId: thingsId)

                // Check if newly completed
                let wasOpen = try await db.getTaskLinkStatus(thingsId) == "open"
                if wasOpen && status.status == "completed" {
                    newlyCompleted += 1
                }

                // Update database
                try await db.updateTaskLinkStatus(
                    thingsId: thingsId,
                    status: status.status,
                    completedAt: status.completionDate
                )
                synced += 1

            } catch {
                errors += 1
                print("Failed to sync task \(thingsId): \(error)")
            }
        }

        return SyncResult(
            total: total,
            synced: synced,
            newlyCompleted: newlyCompleted,
            errors: errors
        )
    }
}

struct ThingsTaskStatus {
    let id: String
    let status: String        // "open", "completed", "canceled"
    let name: String
    let completionDate: Date?
    let modificationDate: Date
    let project: String?
    let area: String?
    let tags: [String]
}

struct SyncResult {
    let total: Int
    let synced: Int
    let newlyCompleted: Int
    let errors: Int
}

enum ThingsStatusError: Error {
    case scriptNotFound
    case invalidResponse
    case taskNotFound(String)
}
```

### ResurfaceTriggerService.swift

Evaluates triggers from YAML config:

```swift
import Foundation
import Yams

class ResurfaceTriggerService: ObservableObject {
    private let config: ResurfaceConfig

    init() {
        self.config = Self.loadConfig()
    }

    /// Evaluate all triggers for a thread based on its tasks
    func evaluateTriggers(
        thread: DiscussionThread,
        tasks: [ThingsTaskStatus]
    ) -> ResurfaceTrigger? {
        guard !tasks.isEmpty else { return nil }

        let total = tasks.count
        let completed = tasks.filter { $0.status == "completed" }.count
        let percent = (completed * 100) / total

        // Priority order: completion > progress > stuck > deadline

        // 1. Completion trigger (100%)
        if config.completion.enabled && percent == 100 {
            return .completion(message: config.completion.message)
        }

        // 2. Progress trigger (threshold %)
        if config.progress.enabled && percent >= config.progress.thresholdPercent {
            // Check trigger_once
            if !config.progress.triggerOnce || thread.lastResurfacedAt == nil {
                return .progress(percent: percent, message: config.progress.message)
            }
        }

        // 3. Stuck trigger (days inactive)
        if config.stuck.enabled {
            let lastActivity = mostRecentActivity(tasks)
            let daysSince = Calendar.current.dateComponents(
                [.day],
                from: lastActivity,
                to: Date()
            ).day ?? 0

            if daysSince >= config.stuck.daysInactive {
                // Check cooldown
                if let lastResurfaced = thread.lastResurfacedAt {
                    let cooldownPassed = Calendar.current.dateComponents(
                        [.day],
                        from: lastResurfaced,
                        to: Date()
                    ).day ?? 0 >= config.stuck.cooldownDays

                    if !cooldownPassed { return nil }
                }

                return .stuck(days: daysSince, message: config.stuck.message)
            }
        }

        // 4. Deadline trigger (future enhancement)
        // Requires deadline tracking in task_links

        return nil
    }

    private func mostRecentActivity(_ tasks: [ThingsTaskStatus]) -> Date {
        tasks.map { $0.modificationDate }.max() ?? Date.distantPast
    }
}

enum ResurfaceTrigger {
    case progress(percent: Int, message: String)
    case stuck(days: Int, message: String)
    case completion(message: String)
    case deadline(daysUntil: Int, message: String)

    var reasonCode: String {
        switch self {
        case .progress(let percent, _): return "progress_\(percent)"
        case .stuck(let days, _): return "stuck_\(days)d"
        case .completion: return "completion"
        case .deadline(let days, _): return "deadline_\(days)d"
        }
    }

    var message: String {
        switch self {
        case .progress(_, let msg), .stuck(_, let msg),
             .completion(let msg), .deadline(_, let msg):
            return msg
        }
    }
}

struct ResurfaceConfig {
    struct ProgressTrigger {
        let enabled: Bool
        let thresholdPercent: Int
        let message: String
        let triggerOnce: Bool
    }

    struct StuckTrigger {
        let enabled: Bool
        let daysInactive: Int
        let message: String
        let cooldownDays: Int
    }

    struct CompletionTrigger {
        let enabled: Bool
        let message: String
        let celebration: Bool
    }

    let progress: ProgressTrigger
    let stuck: StuckTrigger
    let completion: CompletionTrigger
}
```

---

## PlanningView Integration

### Sync on Tab Open

```swift
struct PlanningView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @StateObject private var statusService = ThingsStatusService()
    @StateObject private var triggerService = ResurfaceTriggerService()

    @State private var syncInProgress = false
    @State private var lastSyncResult: SyncResult?

    var body: some View {
        Group {
            // ... existing view code
        }
        .task {
            await syncAndEvaluateTriggers()
        }
    }

    private func syncAndEvaluateTriggers() async {
        syncInProgress = true
        defer { syncInProgress = false }

        // 1. Get all tracked task IDs
        guard let taskIds = try? await databaseService.getAllTaskLinkIds() else {
            return
        }

        // 2. Sync statuses from Things
        let result = await statusService.syncAllTaskStatuses(
            taskIds: taskIds,
            db: databaseService
        )
        lastSyncResult = result

        // 3. Evaluate triggers for active threads
        guard let threads = try? await databaseService.fetchThreads(
            statuses: [.active]
        ) else { return }

        for thread in threads {
            guard let tasks = try? await databaseService.fetchTaskStatusesForThread(
                thread.id
            ) else { continue }

            if let trigger = triggerService.evaluateTriggers(
                thread: thread,
                tasks: tasks
            ) {
                try? await databaseService.resurfaceThread(
                    thread.id,
                    reason: trigger.reasonCode,
                    message: trigger.message
                )
            }
        }
    }
}
```

### Thread List Ordering

Resurfaced threads appear at top:

```swift
// In thread list query or sort
let sortedThreads = threads.sorted { a, b in
    // Review status takes priority
    if a.status == .review && b.status != .review { return true }
    if a.status != .review && b.status == .review { return false }
    // Then by recency
    return a.updatedAt > b.updatedAt
}
```

---

## File Changes Summary

### New Files

| File | Purpose |
|------|---------|
| `SeleneChat/Sources/Services/ThingsStatusService.swift` | AppleScript bridge |
| `SeleneChat/Sources/Services/ResurfaceTriggerService.swift` | Trigger evaluation |
| `SeleneChat/Sources/Services/Migrations/Migration003_BidirectionalThings.swift` | Schema updates |

### Modified Files

| File | Changes |
|------|---------|
| `SeleneChat/Sources/Services/DatabaseService.swift` | Add resurface methods, task status queries |
| `SeleneChat/Sources/Views/PlanningView.swift` | Add sync on appear |
| `SeleneChat/Sources/Models/DiscussionThread.swift` | Add review status, resurface fields |

### Existing (No Changes)

| File | Notes |
|------|-------|
| `scripts/things-bridge/get-task-status.scpt` | Already complete |
| `config/resurface-triggers.yaml` | Already complete |

---

## Implementation Order

1. **Database migration** - Add columns to task_links and discussion_threads
2. **DiscussionThread model** - Add review status and resurface fields
3. **ThingsStatusService** - AppleScript bridge
4. **ResurfaceTriggerService** - Config loading and trigger evaluation
5. **DatabaseService** - Resurface queries and updates
6. **PlanningView** - Wire sync on tab open
7. **Testing** - Manual verification with real Things tasks

---

## Testing Strategy

### Manual Testing

1. Create planning thread with tasks in Things
2. Complete some tasks in Things
3. Open Planning tab → verify sync runs
4. Verify thread shows resurface message
5. Test each trigger type (progress, stuck, completion)

### Shell Script Testing

```bash
# Test AppleScript directly
osascript scripts/things-bridge/get-task-status.scpt "TASK_ID"

# Test batch sync
./scripts/things-bridge/sync-things-status.sh --dry-run
```

---

## Configuration Reference

From `config/resurface-triggers.yaml`:

```yaml
progress_trigger:
  enabled: true
  threshold_percent: 50
  message: "Good progress! Ready to plan next steps?"
  trigger_once: true

stuck_trigger:
  enabled: true
  days_inactive: 3
  message: "This seems stuck. Want to rethink the approach?"
  cooldown_days: 7

completion_trigger:
  enabled: true
  threshold_percent: 100
  message: "All tasks done! Want to reflect or plan what's next?"
  celebration: true

sync:
  interval_minutes: 0  # Disabled - tab open only
  on_launch: false
  on_tab_open: true
```

---

## Future Enhancements

- **Deadline trigger** - Requires task deadline tracking
- **macOS notifications** - Alert when triggers fire (background sync needed)
- **Menu bar indicator** - Show pending resurface count
- **Celebration animation** - Visual reward for completion trigger

---

## Related Documentation

- [Phase 7.2 Design](./2025-12-31-phase-7.2-selenechat-planning-design.md)
- [Things AppleScript Guide](https://culturedcode.com/things/download/Things3AppleScriptGuide.pdf)
- [Resurface Triggers Config](../../config/resurface-triggers.yaml)
