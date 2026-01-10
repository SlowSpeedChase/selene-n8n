# Queue Management & Concurrency Control

## Overview

The LLM Processing workflow includes multiple layers of protection to prevent race conditions, duplicate processing, and queue backups.

---

## How the Queue Works

### Status Flow

```
pending → processing → processed
   ↓           ↓
  (waiting)  (locked)
```

1. **pending**: Note is waiting to be processed
2. **processing**: Note is currently being processed (locked)
3. **processed**: Note has been successfully processed

### Processing Cycle

Every 30 seconds:
1. Workflow triggers via cron
2. Query for oldest `pending` note
3. **Atomically** change status to `processing` (locks the note)
4. Extract concepts via LLM
5. Detect themes via LLM
6. Store results in database
7. Change status to `processed`

---

## Race Condition Prevention

### Problem: Concurrent Executions

If processing takes longer than 30 seconds, multiple executions could run simultaneously:

```
Time: 0s    30s   60s   90s
Exec1: [----processing Note 1----]
Exec2:      [----processing Note 1 again?----]  ❌ BAD!
```

### Solution: Atomic Locking

The workflow uses an **atomic UPDATE** to lock notes:

```javascript
// Step 1: Get pending note
SELECT id FROM raw_notes WHERE status = 'pending' LIMIT 1

// Step 2: Try to lock it
UPDATE raw_notes
SET status = 'processing'
WHERE id = ? AND status = 'pending'

// Step 3: Check if we got the lock
if (changes > 0) {
  // We got it! Process the note
} else {
  // Someone else got it first, skip
}
```

This ensures:
- ✅ Only ONE execution processes each note
- ✅ No duplicate LLM calls
- ✅ No wasted resources

---

## What Happens If Processing Takes Too Long?

### Scenario: Slow LLM Response

If Ollama takes 45 seconds to respond:

```
Time:    0s    30s   45s   60s
Exec1:   [-------processing Note 1--------]✓
Exec2:         [tries Note 1] → skips → [picks Note 2]
```

**Result:**
- Exec1 processes Note 1 (slow)
- Exec2 tries Note 1, sees it's `processing`, skips
- Exec2 picks Note 2 instead
- ✅ No problem! Both continue independently

### Scenario: Very Slow Processing (>5 minutes)

The workflow has a **5-minute timeout**:
- If any execution takes >300 seconds, n8n kills it
- Status remains `processing` (stuck)
- Use cleanup script to recover

---

## Queue Backlog Management

### What Happens If Notes Arrive Faster Than Processing?

**Example:**
- Processing speed: 2 notes/minute (30s each)
- Arrival rate: 5 notes/minute

**Result:**
```
Minute 1: 5 notes arrive, 2 processed → 3 pending
Minute 2: 5 notes arrive, 2 processed → 6 pending
Minute 3: 5 notes arrive, 2 processed → 9 pending
...
```

Queue grows by 3 notes/minute indefinitely.

### Solutions

#### 1. Increase Processing Speed

**Use a faster model:**
```bash
ollama pull llama3.2:3b  # ~5 seconds per note
```

Update workflow to use `llama3.2:3b` instead of `mistral:7b`.

**Result:** 12 notes/minute capacity

#### 2. Reduce Trigger Interval

Change cron from 30s to 15s:
- Doubles throughput
- Only helps if processing is fast

#### 3. Batch Processing

Modify workflow to process multiple notes per execution:
- Change `LIMIT 1` to `LIMIT 5`
- Process in parallel (requires workflow changes)
- Can achieve 10-20x throughput

#### 4. Add More Workers

Run multiple n8n instances processing the same queue:
- Each instance picks different notes (atomic locking)
- Scales linearly with instances

---

## Monitoring Queue Health

### Check Queue Size

```bash
sqlite3 data/selene.db "
SELECT status, COUNT(*) as count
FROM raw_notes
GROUP BY status;
"
```

Expected output:
```
pending|5
processing|1
processed|234
```

### Check Processing Rate

```bash
sqlite3 data/selene.db "
SELECT
  COUNT(*) as processed_last_hour
FROM raw_notes
WHERE status = 'processed'
  AND processed_at > datetime('now', '-1 hour');
"
```

### Check for Stuck Notes

```bash
sqlite3 data/selene.db "
SELECT
  id,
  title,
  status,
  imported_at,
  (julianday('now') - julianday(imported_at)) * 24 * 60 as minutes_stuck
FROM raw_notes
WHERE status = 'processing'
  AND imported_at < datetime('now', '-5 minutes');
"
```

If any notes are stuck >5 minutes, use the cleanup script.

---

## Recovery from Stuck Notes

### Automatic Recovery (TODO)

Future enhancement: Add a "watchdog" that resets stuck notes:

```sql
UPDATE raw_notes
SET status = 'pending'
WHERE status = 'processing'
  AND imported_at < datetime('now', '-10 minutes');
```

### Manual Recovery

Use the provided script:

```bash
# Check for stuck notes
./workflows/02-llm-processing/reset-stuck-notes.sh

# Or manually
sqlite3 data/selene.db "
UPDATE raw_notes
SET status = 'pending'
WHERE status = 'processing';
"
```

---

## Performance Tuning

### Current Configuration

| Setting | Value | Impact |
|---------|-------|--------|
| Trigger Interval | 30 seconds | Throughput ceiling |
| Batch Size | 1 note | Sequential processing |
| LLM Model | mistral:7b | 5-15s per note |
| Timeout | 300 seconds | Max time per note |
| Concurrency | Unlimited | Can overlap |

### Optimized for Speed

```
Trigger Interval: 15 seconds
Batch Size: 1 note
LLM Model: llama3.2:3b
Timeout: 60 seconds
```

**Throughput:** ~120 notes/hour

### Optimized for Accuracy

```
Trigger Interval: 60 seconds
Batch Size: 1 note
LLM Model: llama3.1:8b
Timeout: 300 seconds
```

**Throughput:** ~30 notes/hour (but higher quality)

### Optimized for Volume

```
Trigger Interval: 30 seconds
Batch Size: 5 notes (with parallel processing)
LLM Model: llama3.2:3b
Workers: 3 n8n instances
```

**Throughput:** ~600 notes/hour

---

## Queue States Explained

### Normal Operation

```
Status Distribution:
- pending: 0-10 (normal backlog)
- processing: 1-2 (active work)
- processed: 100s-1000s (completed)
```

### Healthy Backlog

```
Status Distribution:
- pending: 10-50 (manageable)
- processing: 1-3
- processed: growing steadily
```

Processing rate > arrival rate, queue will clear eventually.

### Warning: Queue Building Up

```
Status Distribution:
- pending: 50-200 (growing)
- processing: 1-2
- processed: growing slowly
```

Arrival rate > processing rate. Consider:
- Using faster model
- Reducing trigger interval
- Checking Ollama performance

### Critical: Queue Out of Control

```
Status Distribution:
- pending: 200+ (large backlog)
- processing: 0-1
- processed: barely growing
```

System bottleneck! Actions:
1. Check Ollama is running
2. Check n8n workflow is active
3. Review n8n logs for errors
4. Consider temporary batch processing

### Error: Stuck Notes

```
Status Distribution:
- pending: normal
- processing: 5+ (not changing)
- processed: not growing
```

Notes stuck! Actions:
1. Check n8n executions for failures
2. Run stuck note cleanup script
3. Review error logs

---

## Database Indexes

For optimal queue performance, these indexes are recommended:

```sql
-- Already exists
CREATE INDEX idx_raw_notes_status ON raw_notes(status);

-- Add for better performance
CREATE INDEX idx_raw_notes_status_created
ON raw_notes(status, created_at);
```

The second index optimizes:
```sql
WHERE status = 'pending' ORDER BY created_at ASC
```

---

## Monitoring Alerts

Set up alerts for queue health:

### Alert 1: Large Backlog

```bash
PENDING=$(sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE status='pending';")
if [ $PENDING -gt 100 ]; then
  echo "WARNING: Queue backlog is $PENDING notes"
fi
```

### Alert 2: Stuck Notes

```bash
STUCK=$(sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE status='processing' AND imported_at < datetime('now', '-10 minutes');")
if [ $STUCK -gt 0 ]; then
  echo "ERROR: $STUCK notes stuck in processing"
fi
```

### Alert 3: Slow Processing

```bash
PROCESSED_HOUR=$(sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE status='processed' AND processed_at > datetime('now', '-1 hour');")
if [ $PROCESSED_HOUR -lt 10 ]; then
  echo "WARNING: Only $PROCESSED_HOUR notes processed in last hour"
fi
```

---

## FAQ

### Q: Can two workflows process the same note?
**A:** No. The atomic UPDATE ensures only one execution locks each note.

### Q: What if the workflow crashes mid-processing?
**A:** The note stays in `processing` status. Use the cleanup script to reset it.

### Q: What if Ollama is down?
**A:** The workflow fails with an error. The note stays `processing`. Fix Ollama and run cleanup script.

### Q: Can I process notes in parallel?
**A:** Yes, by running multiple n8n instances or modifying the workflow to batch process.

### Q: How do I prioritize certain notes?
**A:** Modify the query to use a priority field:
```sql
ORDER BY priority DESC, created_at ASC
```

### Q: What's the maximum throughput?
**A:** Depends on:
- LLM speed (~60-120 notes/hour with llama3.2:3b)
- System resources
- Number of workers

---

## Summary

The queue management system provides:

✅ **Race condition prevention** via atomic locking
✅ **Concurrent execution support** via status-based locking
✅ **Graceful backlog handling** via FIFO queue
✅ **Recovery tools** for stuck notes
✅ **Monitoring capabilities** for queue health

**Result:** Robust, scalable, and reliable note processing!
