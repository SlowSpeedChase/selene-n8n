# LLM Processing Workflow Setup

## Overview

The LLM Processing workflow is the second step in the Selene knowledge management pipeline. It automatically processes notes from the `raw_notes` table that have a `status` of "pending", extracts key concepts and themes using a local LLM (Ollama), and stores the processed results in the `processed_notes` table.

**What This Workflow Does:**
- Polls the database every 30 seconds for pending notes
- Extracts 3-5 key concepts from each note using AI
- Detects the primary theme and secondary themes
- Calculates confidence scores for extracted data
- Updates the note status from "pending" to "processed"
- Stores all analysis in the `processed_notes` table

---

## Prerequisites

Before setting up the LLM processing workflow, ensure you have:

- ✅ n8n is running at http://localhost:5678
- ✅ The 01-ingestion workflow is set up and working
- ✅ SQLite database exists at `/data/selene.db`
- ✅ Ollama is installed and running locally
- ✅ At least one LLM model downloaded in Ollama (mistral:7b recommended)

---

## Ollama Setup

The LLM processing workflow requires a local LLM running via Ollama.

### Step 1: Install Ollama

**On macOS:**
```bash
# Using Homebrew
brew install ollama

# Or download from https://ollama.ai
```

**On Linux:**
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### Step 2: Start Ollama Service

```bash
# Start Ollama in the background
ollama serve
```

Or on macOS, Ollama should start automatically after installation.

### Step 3: Download a Model

The workflow is configured to use `mistral:7b` by default (good balance of speed and quality):

```bash
# Download Mistral 7B (recommended)
ollama pull mistral:7b
```

**Alternative Models:**

```bash
# Faster, less accurate (good for testing)
ollama pull llama3.2:3b

# Larger, more accurate (slower)
ollama pull llama3.1:8b
```

### Step 4: Verify Ollama is Running

```bash
# Check Ollama health
curl http://localhost:11434/api/tags

# Should return a JSON list of available models
```

### Step 5: Test the Model

```bash
# Quick test
ollama run mistral:7b "What are the key concepts in this text: Docker is a containerization platform that helps developers build and deploy applications."
```

Expected: Should extract concepts like "Docker", "containerization", "deployment", etc.

---

## Network Configuration

The workflow needs to access Ollama from inside the n8n Docker container.

### On macOS (Default Configuration)

The workflow is already configured to use `host.docker.internal:11434`, which allows the Docker container to access services running on the host machine.

**Ollama URL in workflow:** `http://host.docker.internal:11434`

This is already configured in the workflow, so no changes needed!

### On Linux

On Linux, you may need to use the host's IP address instead:

```bash
# Find your host IP
ip addr show docker0 | grep inet
```

Then update the workflow nodes to use:
```
http://172.17.0.1:11434
```

Or use `host.docker.internal` if you added it to `extra_hosts` in docker-compose.yml (already configured).

---

## Importing the Workflow

### Step 1: Access n8n

Open your browser and navigate to:
```
http://localhost:5678
```

Login with credentials (from docker-compose.yml):
- **Username:** `admin`
- **Password:** `selene_n8n_2025`

### Step 2: Import the Workflow

1. **Click "Workflows" in the left sidebar**
2. **Click "Import from File"**
3. **Navigate to:**
   ```
   /workflows/02-llm-processing/workflow.json
   ```
4. **Click "Import"**

### Step 3: Verify Node Configuration

The workflow should import with all nodes configured. Verify key settings:

**Cron Trigger Node:**
- Runs every 30 seconds
- Can be adjusted based on your needs

**Get Pending Note Node:**
- Queries database for `status = 'pending'`
- Returns oldest note first (FIFO processing)
- Processes one note at a time

**Ollama HTTP Request Nodes:**
- URL: `http://host.docker.internal:11434/api/generate`
- Model: `mistral:7b`
- Timeout: 60 seconds
- Temperature: 0.3 (for consistent results)

### Step 4: Activate the Workflow

1. **Toggle the "Active" switch** in the top right
2. **Verify it's running** - the switch should be green

---

## How It Works

### Processing Pipeline

```
[Every 30s] → [Get Pending Note] → [Has Pending?]
                                          ↓
                                    [Build Concept Prompt]
                                          ↓
                                    [Extract Concepts via LLM]
                                          ↓
                                    [Parse Concepts]
                                          ↓
                                    [Build Theme Prompt]
                                          ↓
                                    [Detect Themes via LLM]
                                          ↓
                                    [Parse Themes]
                                          ↓
                                    [Update Database]
                                          ↓
                                    [Mark as Processed]
```

### Note Type Detection

The workflow automatically detects the note type based on content:

- **meeting** - Contains: "meeting", "met with", "discussed", "action items"
- **technical** - Contains: "docker", "api", "database", "code", "git"
- **idea** - Contains: "idea", "concept", "what if", "brainstorm"
- **personal** - Contains: "i feel", "my goal", "personally", "overwhelmed"
- **task** - Contains: "todo", "must do", "deadline", "task"
- **reflection** - Contains: "learned", "realized", "thinking about", "reflecting"
- **general** - Default if no specific type detected

Note types influence how concepts and themes are extracted.

### Concept Extraction

**What It Extracts:**
- 3-5 key concepts per note
- Short phrases (1-4 words)
- Concrete topics, not abstract feelings
- Confidence score for each concept (0.0-1.0)

**Example:**
```
Note: "Had a meeting about Docker deployment. Discussed using GitHub Actions for CI/CD."

Extracted Concepts:
- "Docker deployment" (confidence: 0.95)
- "GitHub Actions" (confidence: 0.90)
- "CI/CD" (confidence: 0.85)
```

### Theme Detection

**What It Extracts:**
- One primary theme
- 1-2 secondary themes
- Overall confidence score

**Standard Theme Vocabulary:**
```
work, meeting, project, task, personal, health,
learning, reflection, idea, problem_solving, planning,
technical, tools, process, communication, collaboration,
feedback, improvement, decision, notes
```

**Example:**
```
Note: "Had a meeting about Docker deployment. Discussed using GitHub Actions for CI/CD."

Primary Theme: "technical"
Secondary Themes: ["meeting", "tools"]
Confidence: 0.88
```

---

## Testing Your Setup

### Test 1: Check for Pending Notes

```bash
sqlite3 /Users/chaseeasterling/selene-n8n/data/selene.db "SELECT id, title, status FROM raw_notes WHERE status = 'pending';"
```

Expected: Should show notes with `status = 'pending'`

### Test 2: Activate Workflow and Watch Processing

1. **Activate the workflow** in n8n
2. **Open the Executions tab** (left sidebar)
3. **Wait 30 seconds** for the next trigger
4. **Click on the latest execution** to see the processing details

You should see:
- ✅ Note retrieved from database
- ✅ Concepts extracted
- ✅ Themes detected
- ✅ Database updated

### Test 3: Verify Processed Results

```bash
sqlite3 /Users/chaseeasterling/selene-n8n/data/selene.db "
SELECT
  r.id,
  r.title,
  r.status,
  p.concepts,
  p.primary_theme
FROM raw_notes r
LEFT JOIN processed_notes p ON r.id = p.raw_note_id
ORDER BY r.id DESC
LIMIT 5;
"
```

Expected output:
- Note status changed from "pending" to "processed"
- Concepts extracted as JSON array
- Primary theme assigned

### Test 4: Check Processing Quality

```bash
sqlite3 /Users/chaseeasterling/selene-n8n/data/selene.db "
SELECT
  raw_note_id,
  concepts,
  primary_theme,
  theme_confidence
FROM processed_notes
ORDER BY id DESC
LIMIT 1;
"
```

Review the results:
- Are concepts relevant to the note content?
- Is the theme accurate?
- Are confidence scores reasonable (>0.5)?

---

## Troubleshooting

### Error: "Cannot connect to Ollama"

**Symptoms:**
- Workflow execution fails at Ollama nodes
- Error message: "ECONNREFUSED" or "timeout"

**Solutions:**

1. **Check Ollama is running:**
   ```bash
   curl http://localhost:11434/api/tags
   ```

2. **Verify Ollama service:**
   ```bash
   # macOS
   ps aux | grep ollama

   # If not running
   ollama serve
   ```

3. **Test from inside Docker container:**
   ```bash
   docker exec -it selene-n8n sh -c "wget -qO- http://host.docker.internal:11434/api/tags"
   ```

4. **Check Docker extra_hosts configuration:**
   ```bash
   docker inspect selene-n8n | grep -A5 ExtraHosts
   ```
   Should show: `host.docker.internal:host-gateway`

### Error: "Model not found"

**Symptoms:**
- Ollama responds but workflow fails
- Error: "model 'mistral:7b' not found"

**Solution:**
```bash
# Download the model
ollama pull mistral:7b

# Verify it's available
ollama list
```

### Workflow Not Processing Notes

**Symptoms:**
- Workflow is active but notes remain "pending"
- No executions showing up

**Solutions:**

1. **Check workflow is activated:**
   - Green toggle in top right should be ON

2. **Check for pending notes:**
   ```bash
   sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE status = 'pending';"
   ```

3. **Manually trigger workflow:**
   - Click "Test workflow" button in n8n
   - Check execution results

4. **Check n8n logs:**
   ```bash
   docker-compose logs n8n --tail=50
   ```

### Concepts/Themes Are Inaccurate

**Symptoms:**
- Extracted concepts don't match note content
- Themes are generic or wrong

**Solutions:**

1. **Try a different model:**
   ```bash
   # Download a larger model
   ollama pull llama3.1:8b
   ```

   Then update workflow nodes to use `llama3.1:8b` instead of `mistral:7b`

2. **Adjust temperature:**
   - Lower temperature (0.1-0.2) = more focused, deterministic
   - Higher temperature (0.5-0.7) = more creative, varied

3. **Review prompt engineering:**
   - Check the "Build Concept Extraction Prompt" node
   - Ensure context guidance is appropriate for your note types

### Database Errors

**Symptoms:**
- Error: "database is locked"
- Error: "table doesn't exist"

**Solutions:**

1. **Check database accessibility:**
   ```bash
   sqlite3 data/selene.db ".tables"
   ```

2. **Verify processed_notes table exists:**
   ```bash
   sqlite3 data/selene.db ".schema processed_notes"
   ```

3. **Close other database connections:**
   ```bash
   # Check if other processes are using the database
   lsof | grep selene.db
   ```

### Slow Processing

**Symptoms:**
- Each note takes 30+ seconds to process
- Ollama response times are slow

**Solutions:**

1. **Use a smaller/faster model:**
   ```bash
   ollama pull llama3.2:3b
   ```

2. **Check system resources:**
   ```bash
   # Monitor CPU/memory usage
   top
   ```

3. **Reduce number of tokens:**
   - In workflow, reduce `num_predict` from 2000 to 500

4. **Increase cron interval:**
   - Change from 30 seconds to 60 seconds if processing is slow

---

## Configuration Options

### Changing the Processing Interval

**Default:** Every 30 seconds

To change:
1. Open workflow in n8n
2. Click "Every 30 Seconds" node
3. Adjust interval (e.g., 60 seconds, 5 minutes)
4. Save workflow

### Changing the LLM Model

**Default:** `mistral:7b`

To change:
1. Pull new model: `ollama pull llama3.1:8b`
2. Update both Ollama HTTP Request nodes:
   - "Ollama: Extract Concepts"
   - "Ollama: Detect Themes"
3. Change `model` parameter from `mistral:7b` to your model
4. Save workflow

### Adjusting Batch Size

**Default:** Processes 1 note per execution

To process multiple notes:
1. Edit "Get Pending Note" node
2. Change `LIMIT 1` to `LIMIT 5` in SQL query
3. Add a "Loop" node after "Has Pending Notes?" switch
4. Route all processing through the loop

### Temperature Settings

**Default:** 0.3 (balanced)

- **Lower (0.1-0.2):** More deterministic, focused
- **Higher (0.5-0.7):** More creative, varied

Update in the HTTP Request nodes under `options.temperature`

---

## Production Tips

### 1. Monitor Processing Performance

Track how long processing takes:

```bash
sqlite3 data/selene.db "
SELECT
  COUNT(*) as total_processed,
  AVG(JULIANDAY(processed_at) - JULIANDAY(imported_at)) * 24 * 60 as avg_minutes
FROM raw_notes
WHERE status = 'processed';
"
```

### 2. Set Up Error Notifications

Add an error path in the workflow:
- Connect error outputs to a notification node
- Send alerts when processing fails

### 3. Periodic Quality Review

Regularly review processed notes:

```bash
sqlite3 data/selene.db "
SELECT
  r.title,
  p.concepts,
  p.primary_theme,
  p.theme_confidence
FROM processed_notes p
JOIN raw_notes r ON p.raw_note_id = r.id
ORDER BY RANDOM()
LIMIT 10;
"
```

### 4. Optimize for Your Note Types

If you primarily capture one type of note:
- Customize the note type detection logic
- Adjust prompts for your specific use case
- Fine-tune confidence thresholds

### 5. Database Maintenance

Periodically check database health:

```bash
# Vacuum to reclaim space
sqlite3 data/selene.db "VACUUM;"

# Analyze for query optimization
sqlite3 data/selene.db "ANALYZE;"
```

---

## Advanced Configuration

### Custom Note Type Detection

Edit the "Build Concept Extraction Prompt" node to add custom note types:

```javascript
function detectNoteType(text) {
  const lower = text.toLowerCase();

  // Add your custom types here
  if (/(standup|daily sync|team update)/i.test(lower)) {
    return 'standup';
  }
  // ... existing types
}
```

### Custom Theme Vocabulary

Edit the "Build Theme Detection Prompt" node:

```javascript
const standardThemes = [
  'work', 'meeting', 'project', // ... existing
  'fitness', 'finance', 'hobby' // Add your custom themes
];
```

### Confidence Score Filtering

Add a filter node after parsing to skip low-confidence results:

```javascript
if ($json.themeConfidence < 0.5) {
  // Re-process or flag for manual review
  return { json: { skipUpdate: true } };
}
```

---

## Integration with Other Workflows

The processed data is used by downstream workflows:

- **03-pattern-detection:** Analyzes trends across processed notes
- **04-obsidian-export:** Exports processed notes with metadata
- **05-sentiment-analysis:** Adds emotional context to processed notes
- **06-connection-network:** Builds a concept graph from processed data

Ensure this workflow is running smoothly before enabling downstream workflows.

---

## Support

If you encounter issues:

1. **Check n8n execution logs** in the Executions tab
2. **Review Ollama logs:**
   ```bash
   journalctl -u ollama -f  # Linux
   # Or check macOS Console app
   ```
3. **Test database connectivity:**
   ```bash
   sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes;"
   ```
4. **Verify Docker networking:**
   ```bash
   docker exec -it selene-n8n ping host.docker.internal
   ```

---

## Next Steps

After setting up LLM processing:

1. **Test with existing pending notes** - Let it process your backlog
2. **Monitor quality** - Review extracted concepts and themes
3. **Tune parameters** - Adjust model, temperature, and prompts as needed
4. **Set up 03-pattern-detection** - Analyze trends in your processed notes
5. **Configure 04-obsidian-export** - Export processed notes to Obsidian

---

## Resources

- [Ollama Documentation](https://ollama.ai/docs)
- [n8n Function Node Documentation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.function/)
- [SQLite better-sqlite3 API](https://github.com/WiseLibs/better-sqlite3/blob/master/docs/api.md)
- [Mistral AI Documentation](https://docs.mistral.ai/)
