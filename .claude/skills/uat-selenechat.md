# uat-selenechat

Guide interactive UAT sessions for SeleneChat views.

## Triggers

- `/uat <ViewName>` - e.g., `/uat PlanningView`
- "UAT the Planning tab"
- "let's test PlanningView"

## Behavior

1. **Load checklist** from `SeleneChat/Tests/UAT/checklists/<ViewName>.yaml`
2. **Walk through each item** one at a time
3. **Wait for confirmation** - user says yes/no/describes issue
4. **Track results** - pass, fail with notes
5. **Generate sign-off** - markdown file in `SeleneChat/Tests/UAT/sessions/`
6. **Commit** the sign-off document

## Session Flow

### Start
```
Claude: "Starting UAT for PlanningView.

First check: **Empty inbox**
Open the Planning tab with no pending notes in inbox.
Do you see an empty state message (not a loading spinner)?"
```

### Each Check
```
User: "yes"
Claude: "✓ Empty inbox passed.

Next: **Empty active projects**
With no active projects, does the Active Projects section show an empty state?"
```

### Issue Found
```
User: "no, it shows a spinner forever"
Claude: "✗ Loading state failed: shows spinner forever

Next: ..."
```

### Complete
```
Claude: "UAT complete for PlanningView.

**Results:** 24/25 passed

**Failed:**
- Loading state: shows spinner forever

Sign-off saved to: SeleneChat/Tests/UAT/sessions/2026-01-02-planning-view.md

[Commits the file]"
```

## Sign-off Document Format

Generate this format:

```markdown
# UAT Session: [ViewName]

**Date:** YYYY-MM-DD
**Tester:** [from git config user.name]
**Feature/PR:** [ask user or infer from recent commits]
**Result:** ✅ PASSED (X/Y checks) or ❌ FAILED (X/Y checks)

---

## States

| Check | Result | Notes |
|-------|--------|-------|
| Empty state | ✅ Pass | |
| Loading state | ❌ Fail | Shows spinner forever |
...

## Interactions
...

## Bindings
...

## Visual
...

---

**Sign-off:** [PASSED: Ready for merge / FAILED: Issues need fixing]
```

## Category Order

Walk through checks in this order:
1. States (empty, loading, error, populated, edge cases)
2. Interactions (primary actions, secondary actions)
3. Bindings (data reactivity)
4. Visual (appearance, layout)

## Available Checklists

- `PlanningView.yaml` - Planning tab and conversation view
- `_template.yaml` - Template for creating new checklists

## Adding New Checklists

When asked to UAT a view without a checklist:

1. Inform user: "No checklist found for [ViewName]. Would you like me to create one?"
2. If yes, read the view's Swift file
3. Generate checklist based on the view's components
4. Save to `checklists/[ViewName].yaml`
5. Proceed with UAT
