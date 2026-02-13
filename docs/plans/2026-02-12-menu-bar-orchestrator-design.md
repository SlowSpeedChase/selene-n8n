# SeleneChat Menu Bar App + Workflow Orchestration

**Date:** 2026-02-12
**Status:** Done
**Topic:** selenechat, infra

---

## Summary

Transform SeleneChat from a standard windowed app into a menu bar utility that launches at login. A Silver Crystal-inspired moon icon lives in the menu bar and sparkles when Ollama is processing. The app takes over workflow scheduling from the 7 launchd plists, consolidating everything into one codebase.

---

## Menu Bar Icon — Silver Crystal Moon

The icon is a small faceted crystal with a crescent moon silhouette, inspired by the Silver Crystal (Ginzuishō) from Sailor Moon. Monochrome template image adapts to macOS light/dark mode.

| State | Appearance | Animation |
|-------|-----------|-----------|
| **Idle** | Crystal outline, static | None |
| **Processing (Ollama)** | Crystal fills with inner glow | Soft pulse + small sparkle particles radiate outward from facets |
| **Error** | Crystal with small red dot badge | Static badge, no animation |

The processing animation is the hero moment — the crystal "awakens" with an inner shimmer and throws off small diamond-shaped sparkles, like it's channeling energy. Subtle enough for a 22x22pt menu bar icon but unmistakably alive.

Implementation: Custom `Image` rendered from a SwiftUI `Canvas` or layered vector assets. Sparkle particles use SwiftUI `TimelineView` for smooth frame-based animation.

---

## Menu Bar Dropdown — Minimal Status

Click the moon icon to see a small popover:

- **Processing state:** `● Processing 3 notes...` or `○ Idle`
- **Open Selene** button (⌘O) — brings chat window to front
- **Quit** button (⌘Q) — terminates app

No logs, no controls, no clutter.

---

## App Lifecycle Changes

- **Launch at login** via `SMAppService.mainApp` (macOS 13+). No launchd plist needed for the app itself.
- **No dock icon when chat is closed** — `LSUIElement` in Info.plist. Menu bar icon always visible.
- **Dock icon appears when chat window opens** — `NSApp.setActivationPolicy(.regular)` when window opens, `.accessory` when it closes.
- **Closing chat window doesn't quit the app** — app keeps running in menu bar. Only "Quit" from dropdown terminates.
- **First launch** — prompt to enable Login Item. Automatic after that.

---

## WorkflowScheduler Service

`@MainActor class WorkflowScheduler: ObservableObject` replaces all 7 launchd plists.

### Schedules (same as current launchd)

| Workflow | Interval | Uses Ollama |
|----------|----------|-------------|
| process-llm.ts | Every 5 min | Yes |
| extract-tasks.ts | Every 5 min | No |
| compute-embeddings.ts | Every 10 min | Yes |
| compute-associations.ts | Every 10 min | No |
| daily-summary.ts | Daily at midnight | Yes |
| send-digest.ts | Daily at 6am | No |
| server.ts | Always running (child process) | No |

### How it works

- Each workflow is a `ScheduledWorkflow` struct: name, script path, interval, last run time.
- `Timer`-based scheduling checks what's due and launches via `Process` (`npx ts-node src/workflows/<name>.ts`).
- Publishes `@Published var activeWorkflows: [String]` — currently running workflow names.
- Publishes `@Published var lastError: WorkflowError?` — drives error badge state.
- The Fastify server (`server.ts`) is launched as a long-running child process, restarted on crash.
- On app quit, gracefully terminates the server and any running workflows.

### Ollama detection

The scheduler knows which workflows use Ollama (process-llm, compute-embeddings, daily-summary). When those are in `activeWorkflows`, the menu bar icon sparkles. Non-Ollama workflows run silently.

---

## Technical Approach

- **Menu bar:** SwiftUI `MenuBarExtra` scene alongside existing `WindowGroup` in `SeleneChatApp.swift`.
- **Scheduling:** Swift `Timer` in `WorkflowScheduler` service, shelling out to existing TypeScript scripts via `Process`.
- **Icon animation:** SwiftUI `Canvas` + `TimelineView` for frame-based sparkle animation.
- **Login item:** `SMAppService.mainApp` registration.

---

## Migration Path

1. **Phase 1** — Ship menu bar app + WorkflowScheduler running in parallel with existing launchd plists. Scheduler disabled by default, toggle in dropdown menu.
2. **Phase 2** — Once verified stable, enable scheduler by default. Provide `./scripts/uninstall-launchd.sh` to remove old plists.
3. **Phase 3** — Remove launchd plists from the repo entirely.

---

## Testing

- **WorkflowScheduler** — Unit tests for scheduling logic: workflows fire at correct intervals, `activeWorkflows` updates on process start/stop, error states propagate. Mock `Process` to avoid running TypeScript.
- **Menu bar icon states** — View tests verifying icon renders correctly for idle/processing/error based on scheduler state.
- **App lifecycle** — Tests for activation policy switching (dock icon with window), Login Item registration.
- **Integration** — Manual verification that TypeScript workflows produce same results when launched via `Process` vs launchd.

---

## Acceptance Criteria

- [ ] SeleneChat launches at login as a menu bar utility (no dock icon unless chat window open)
- [ ] Silver Crystal moon icon visible in menu bar at all times when app running
- [ ] Icon sparkles with particle animation when Ollama-using workflows are active
- [ ] Icon shows error badge when a workflow fails
- [ ] Clicking icon shows minimal status dropdown (processing state + Open Selene + Quit)
- [ ] WorkflowScheduler runs all 6 periodic workflows on correct intervals
- [ ] Fastify server managed as child process with crash restart
- [ ] Chat window opens/closes independently without quitting app
- [ ] Migration Phase 1: scheduler runs in parallel with existing launchd (toggle-able)

## ADHD Check

- [x] **Reduces friction?** Yes — one app to manage instead of 7 launchd plists + a separate app
- [x] **Makes things visible?** Yes — processing activity visible at a glance in menu bar
- [x] **Externalizes cognition?** Yes — no need to remember if workflows are running, the icon tells you

## Scope Check

- [x] Less than 1 week of focused work? Yes — Phase 1 (menu bar + scheduler + icon) is ~3-4 days
