---
name: log-debug-fix
description: Log a solved debug issue to the debug journal
---

# Log Debug Fix

When invoked after solving a debug issue, document the solution.

## Process

1. Summarize the issue that was just debugged
2. Format using the template below
3. Append to `docs/debug-journal.md`
4. Commit the update

## Template

```markdown
## YYYY-MM-DD: [Brief issue title]

**Symptoms:** [What was observed - error message, visual issue, wrong behavior]
**Context:** [What was happening when it occurred - which view, what action]
**Cause:** [Root cause identified]
**Solution:** [What fixed it]
**Files:** [Affected files with line numbers]
**Prevention:** [Optional - how to avoid similar issues]

---
```

## Example Usage

After fixing a bug where the planning view showed an empty list despite having data:

```markdown
## 2026-01-01: Planning view shows empty list

**Symptoms:** PlanningView renders but shows no threads despite database having 3 threads
**Context:** Opening Planning tab after app launch, database confirmed to have data
**Cause:** Query was using wrong column name - `user_id` instead of `thread_owner`
**Solution:** Changed WHERE clause in `PlanningService.fetchThreads()` from `WHERE user_id = ?` to `WHERE thread_owner = ?`
**Files:** SeleneChat/Sources/Services/PlanningService.swift:45
**Prevention:** Add integration test that verifies threads appear after creation

---
```
