# SeleneChat Debug System Design

**Date:** 2026-01-01
**Status:** Approved
**Purpose:** Give Claude Code visibility into SeleneChat's runtime state for autonomous debugging

---

## Overview

A hybrid debugging system combining:
- **Continuous logging** of errors and state changes
- **On-demand snapshots** for deep inspection
- **Error alerting** for immediate issue detection
- **Debug journal** for learning from solved issues

### File Locations

| File | Purpose | Persistence |
|------|---------|-------------|
| `/tmp/selenechat-debug.log` | Continuous log of errors and state changes | Ephemeral, 5 MB max |
| `/tmp/selenechat-snapshot-request` | Trigger file Claude creates to request snapshot | Deleted after processing |
| `/tmp/selenechat-snapshot.json` | Full app state dump | Overwritten each snapshot |
| `/tmp/selenechat-last-error` | Timestamp of most recent error | Updated on each error |
| `docs/debug-journal.md` | Persistent record of solved issues | Version-controlled |

### Claude's Debugging Workflow

1. **Routine check:** Read `selenechat-last-error` to see if something went wrong recently
2. **Investigate:** Write to `selenechat-snapshot-request`, then read `selenechat-snapshot.json`
3. **Context:** Read `selenechat-debug.log` for recent state changes leading up to issue
4. **Learn:** After fixing, invoke `/log-debug-fix` to record the solution

---

## Runtime Logging

### Log Format

```
[2025-01-01 14:32:01] STATE  | PlanningStore.threads.count: 0 → 3
[2025-01-01 14:32:01] STATE  | PlanningStore.selectedThread: nil → "abc-123"
[2025-01-01 14:32:02] ERROR  | OllamaService.generate failed: connection refused
[2025-01-01 14:32:02] STATE  | PlanningStore.isLoading: true → false
[2025-01-01 14:32:05] NAV    | Navigated: ThreadList → ThreadDetail(abc-123)
```

### Log Categories

| Category | What it captures |
|----------|------------------|
| `STATE` | Property changes on observable stores/models |
| `ERROR` | Exceptions, failed operations, unexpected conditions |
| `NAV` | View transitions, sheet presentations, navigation stack changes |
| `ACTION` | User-initiated actions (button taps, form submissions) |

### Rotation Behavior

- When log exceeds 5 MB, rename to `selenechat-debug.log.old`
- Start fresh log
- Only keep one backup (10 MB max total)

### Implementation

A lightweight `DebugLogger` singleton that views and services call. Uses `FileHandle` for efficient appends.

---

## Snapshot System

### Trigger Mechanism

1. Claude writes any content to `/tmp/selenechat-snapshot-request`
2. App detects file (polling every 2 seconds via timer)
3. App writes state to `/tmp/selenechat-snapshot.json`
4. App deletes the request file

### Snapshot Contents

```json
{
  "timestamp": "2025-01-01T14:32:05Z",
  "currentView": {
    "name": "PlanningThreadDetail",
    "navigationPath": ["PlanningTab", "ThreadList", "ThreadDetail"],
    "presentedSheet": null,
    "presentedAlert": null
  },
  "models": {
    "planningStore": {
      "threads": [...],
      "selectedThreadId": "abc-123",
      "isLoading": false
    },
    "settingsStore": {
      "aiProvider": "ollama",
      "ollamaModel": "mistral:7b"
    }
  },
  "services": {
    "ollama": { "status": "connected", "lastCheck": "..." },
    "database": { "status": "connected", "path": "..." }
  },
  "recentActions": [
    { "time": "...", "action": "tappedThread", "params": {"id": "abc-123"} },
    { "time": "...", "action": "sentMessage", "params": {"length": 142} }
  ]
}
```

### Implementation

Each store/service conforms to a `DebugSnapshotProvider` protocol with a `debugSnapshot() -> [String: Any]` method.

---

## Error Alerting

### Error File Format

When an error occurs, app writes to `/tmp/selenechat-last-error`:

```
2025-01-01T14:32:02Z|OllamaService.generate|connection refused
```

Format: `timestamp|location|brief message`

### Claude's Check Workflow

```bash
# Quick check - is there a recent error?
cat /tmp/selenechat-last-error

# If timestamp is recent (within last few minutes), investigate:
# 1. Request snapshot
touch /tmp/selenechat-snapshot-request
sleep 3
cat /tmp/selenechat-snapshot.json

# 2. Check recent log context
tail -100 /tmp/selenechat-debug.log
```

### What Triggers an Error Write

- Caught exceptions in service calls
- Network failures (Ollama, database)
- Data inconsistencies (expected data missing)
- View errors (failed to decode, assertion failures)

### Not Written For

- User-caused issues (empty form submission)
- Expected states (no threads yet, Ollama not configured)

---

## Debug Journal

### File Location

`docs/debug-journal.md` (version-controlled)

### Entry Template

```markdown
## YYYY-MM-DD: Brief issue title

**Symptoms:** What was observed (error message, visual issue, wrong behavior)
**Context:** What was happening when it occurred (which view, what action)
**Cause:** Root cause identified
**Solution:** What fixed it
**Files:** Affected files with line numbers
**Prevention:** Optional - how to avoid similar issues

---
```

### Skill: `/log-debug-fix`

When invoked, Claude:
1. Summarizes the issue just solved
2. Formats using the template above
3. Appends to `docs/debug-journal.md`
4. Commits the update

### Searching the Journal

```bash
grep -i "connection refused" docs/debug-journal.md
grep -i "empty list" docs/debug-journal.md
```

---

## Implementation Plan

### New Files

| File | Purpose |
|------|---------|
| `SeleneChat/Debug/DebugLogger.swift` | Singleton for logging, file rotation |
| `SeleneChat/Debug/DebugSnapshotProvider.swift` | Protocol for snapshot-capable types |
| `SeleneChat/Debug/DebugSnapshotService.swift` | Watches trigger file, coordinates snapshot |
| `docs/debug-journal.md` | Empty template to start |

### Modifications to Existing Files

- **Stores** (PlanningStore, SettingsStore, etc.): Conform to `DebugSnapshotProvider`, add logging calls on state changes
- **Services** (OllamaService, DatabaseService, etc.): Add error logging, conform to `DebugSnapshotProvider`
- **Views**: Add navigation logging in `onAppear`/`onDisappear`
- **App entry point**: Initialize `DebugSnapshotService` on launch

### Build Configuration

- Debug logging enabled only in `DEBUG` builds
- Release builds: logging code compiles out via `#if DEBUG`

### Dependencies

None - uses only Foundation file APIs.

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| `/tmp/` for runtime files | Ephemeral, auto-cleaned on reboot, no clutter in project |
| File-based snapshot trigger | Self-contained in app, no external CLI to maintain |
| 5 MB log rotation | Enough context without being unwieldy |
| Polling vs FSEvents | Simpler implementation, 2-second delay acceptable |
| State-only snapshots | Screenshots can be added later if needed |
| Skill for journal | Manual trigger ensures we capture when relevant |

---

## Future Enhancements (Not in Scope)

- Screenshot capture in snapshots
- UI accessibility tree dump
- Automated pattern extraction from conversations
- Integration with Xcode Instruments
