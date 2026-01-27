# Things 3 Checklist Integration Design

**Status:** Deprioritized (bundled with Cloud AI Integration)
**Created:** 2026-01-11
**Scope:** Add automatic checklist generation for planning/research tasks

> **Note:** This feature would benefit significantly from Cloud AI (Phase 7.3) for higher quality checklist generation. Local Ollama with mistral:7b produces adequate but not great breakdowns. Bundled with Cloud AI integration for future implementation.

---

## Overview

Enhance the Things 3 integration to automatically generate checklist items for planning and research tasks. This reduces ADHD overwhelm by breaking ambiguous tasks into concrete, action-sized steps.

### What Changes

The `extract-tasks.ts` workflow gets a new step. After classifying a task as `planning` or `research`, it makes a second LLM call to generate checklist items before writing to the Things bridge.

### Updated Flow

```
Note → Classify → Extract Tasks → [NEW: Generate Checklist] → Write JSON → Things Bridge
                                        ↑
                                  Only for planning/research tasks
```

### Files to Modify

| File | Change |
|------|--------|
| `src/workflows/extract-tasks.ts` | Add checklist generation step |
| `scripts/things-bridge/add-task-to-things.scpt` | Create checklist items in Things |

### What Stays the Same

- Classification logic (actionable/needs_planning/archive_only)
- Task extraction (title, notes, task_type, etc.)
- Oversized task routing to discussion threads
- Project matching
- The shell bridge script

---

## LLM Prompt Design

### Checklist Generation Prompt

```typescript
const GENERATE_CHECKLIST_PROMPT = `Break this task into 2-5 concrete action steps.

Task: {title}
Context: {notes}
Type: {task_type}

Requirements:
- Each step should take roughly 15 minutes
- Use action verbs (research, draft, compare, decide, etc.)
- First step should be immediately obvious - no "figure out what to do"
- Last step should produce a clear output or decision

Respond in JSON array format:
["Step 1 description", "Step 2 description", ...]

JSON response:`;
```

### Why This Works for ADHD

1. **"Immediately obvious" first step** - Eliminates the "where do I start?" paralysis
2. **Action verbs** - Each item is doable, not vague
3. **Clear output** - Knowing what "done" looks like reduces anxiety
4. **15-minute chunks** - Small enough to start, big enough to feel progress

### Example Output

Task: "Research project management tools for team"

```json
[
  "List 5 tools from quick Google search",
  "Sign up for free trials of top 3",
  "Test each with a sample project for 20 min",
  "Compare in simple pros/cons table",
  "Pick one and share recommendation"
]
```

---

## Data Structure Changes

### Updated JSON Task File Format

```json
{
  "title": "Research project management tools",
  "notes": "Team needs better task tracking...",
  "task_type": "research",
  "estimated_minutes": 60,
  "overwhelm_factor": 5,
  "project_id": "ABC123",
  "heading": "Research",
  "checklist": [
    "List 5 tools from quick Google search",
    "Sign up for free trials of top 3",
    "Test each with a sample project for 20 min",
    "Compare in simple pros/cons table",
    "Pick one and share recommendation"
  ]
}
```

### New Field

`checklist` - array of strings, only present for planning/research tasks.

### TypeScript Type Update

```typescript
interface ExtractedTask {
  title: string;
  notes?: string;
  task_type?: string;
  estimated_minutes?: number;
  overwhelm_factor?: number;
  checklist?: string[];  // NEW
}
```

### No Database Changes

Checklists live only in the JSON bridge files and Things itself. The task metadata in `extracted_tasks` table doesn't need to store checklist items.

---

## AppleScript Changes

### Limitation

Things 3's AppleScript API doesn't support creating checklist items directly. But the **URL scheme does**.

### Solution: Hybrid Approach

Use AppleScript for task creation (to get the ID back), then URL scheme to add checklist items.

### Updated Logic

```
1. Create task via AppleScript (existing code)
2. Get task ID back
3. If checklist array exists in JSON:
   → Build Things URL: things:///update?id={taskId}&checklist-items={items}
   → Call: open location thingsUrl
4. Return task ID
```

### URL Scheme Format

```
things:///update?id=ABC123&checklist-items=Step%201%0AStep%202%0AStep%203
```

Items are newline-separated (`%0A`) and URL-encoded.

### AppleScript Addition

After task creation, add:

```applescript
-- Add checklist items via URL scheme if present
if checklistItems is not "" then
    set encodedItems to do shell script "echo " & quoted form of checklistItems & " | /usr/bin/python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))'"
    set thingsUrl to "things:///update?id=" & taskId & "&checklist-items=" & encodedItems
    open location thingsUrl
    delay 0.5  -- Give Things time to process
end if
```

---

## Testing Approach

### Test Scenarios

| Scenario | Input | Expected Output |
|----------|-------|-----------------|
| Planning task | task_type: "planning" | Task created with 2-5 checklist items |
| Research task | task_type: "research" | Task created with 2-5 checklist items |
| Action task | task_type: "action" | Task created, no checklist |
| Decision task | task_type: "decision" | Task created, no checklist |

### Manual Test Flow

```bash
# 1. Create test note that will classify as planning/research
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Plan vacation",
    "content": "Need to figure out where to go for summer vacation. Research destinations, compare costs, decide on dates.",
    "test_run": "test-checklist-001"
  }'

# 2. Run the workflows
npx ts-node src/workflows/process-llm.ts
npx ts-node src/workflows/extract-tasks.ts

# 3. Check pending JSON file for checklist field
cat scripts/things-bridge/pending/*.json | jq

# 4. Run Things bridge
./scripts/things-bridge/process-pending-tasks.sh

# 5. Verify in Things 3 - task should have checklist items

# 6. Cleanup
./scripts/cleanup-tests.sh test-checklist-001
```

---

## Future Enhancements (Out of Scope)

These were discussed but deferred for later:

1. **Smarter project matching** - Use thread context, not just concept overlap
2. **Energy/context tags** - Route tasks by energy level (high-focus, low-energy, etc.)

---

## Implementation Checklist

- [ ] Add `GENERATE_CHECKLIST_PROMPT` to extract-tasks.ts
- [ ] Add checklist generation logic for planning/research tasks
- [ ] Update JSON file writing to include checklist array
- [ ] Update add-task-to-things.scpt to read checklist from JSON
- [ ] Add URL scheme call for checklist items
- [ ] Test with planning task
- [ ] Test with research task
- [ ] Test with action task (no checklist)
- [ ] Update documentation
