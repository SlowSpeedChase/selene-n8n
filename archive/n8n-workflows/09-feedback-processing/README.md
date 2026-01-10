# 09-Feedback-Processing Workflow

## Purpose

Processes user feedback notes tagged with `#selene-feedback`, converting raw feedback into structured user stories via Ollama LLM. This enables systematic tracking and prioritization of feature requests and bug reports.

## Trigger

**Schedule:** Runs every 5 minutes
- Queries `feedback_notes` table for unprocessed entries (`processed_at IS NULL`)
- Processes up to 10 feedback items per run

## Data Flow

1. **Schedule Trigger** - Fires every 5 minutes
2. **Query Unprocessed Feedback** - Gets feedback notes awaiting processing
3. **Build LLM Prompt** - Creates prompt from template for user story conversion
4. **Send to Ollama** - Calls mistral:7b model (60s timeout)
5. **Parse LLM Response** - Extracts user_story, theme, and priority with fallback parsing
6. **Update Feedback Record** - Stores results back to feedback_notes table

## Output Format

The LLM converts feedback into:
```json
{
  "user_story": "As a user, I want [X] so that [Y]",
  "theme": "task-routing|dashboard|planning|ui|performance|other",
  "priority_hint": 1-3
}
```

## Theme Categories

| Theme | Description |
|-------|-------------|
| task-routing | Task suggestions, energy matching, context awareness |
| dashboard | Display, visualization, overview features |
| planning | Scheduling, breakdown, project planning |
| ui | Interface design, usability, accessibility |
| performance | Speed, responsiveness, reliability |
| other | Uncategorized feedback |

## Priority Levels

| Priority | Meaning |
|----------|---------|
| 1 | Low - Nice to have |
| 2 | Medium - Would improve experience |
| 3 | High - Significantly impacts usability |

## Database Schema

**Table: feedback_notes**
```sql
CREATE TABLE feedback_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    content_hash TEXT UNIQUE,
    user_story TEXT,
    theme TEXT,
    priority INTEGER,
    processed_at DATETIME,
    processing_error TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    test_run TEXT
);
```

## Testing

```bash
# Run test with markers
./scripts/test-with-markers.sh

# Verify results
sqlite3 data/selene.db "SELECT * FROM feedback_notes WHERE test_run LIKE 'test-run-%'"

# Cleanup test data
sqlite3 data/selene.db "DELETE FROM feedback_notes WHERE test_run LIKE 'test-run-%'"
```

## Error Handling

- **Ollama timeout/error**: Records error in `processing_error` column, sets default theme/priority
- **JSON parse failure**: Falls back to regex extraction of user story pattern
- **Empty queue**: Workflow exits cleanly when no unprocessed feedback

## Configuration

- **Model**: mistral:7b
- **Timeout**: 60 seconds
- **Temperature**: 0.3 (lower for consistent output)
- **Max predictions**: 500 tokens

## Related Files

- `prompts/feedback/user-story-conversion.md` - Prompt template
- `docs/STATUS.md` - Test results and current state
- `scripts/test-with-markers.sh` - Automated test script

## Dependencies

- Ollama running at `http://host.docker.internal:11434`
- SQLite database at `/selene/data/selene.db`
- `feedback_notes` table created (see Task 2 schema migration)
