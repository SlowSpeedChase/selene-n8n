# Apple Shortcut Setup Guide - Simplified

**Version:** 2.0 (Simplified Architecture)
**Last Updated:** October 31, 2025

## Overview

This guide will walk you through creating a **simple** Apple Shortcut that processes notes using Apple Intelligence. The Shortcut has only **7 actions** - it gets a note, asks Apple Intelligence to analyze it, and returns the result. All the complex parsing happens in n8n!

---

## Architecture (Simplified!)

```
[Apple Shortcut runs]
    ↓
GET http://localhost:5678/webhook/api/apple/get-pending-note
    ↓
n8n returns: {noteId, prompt}  ← ONE combined prompt
    ↓
[Ask Apple Intelligence ONCE with that prompt]
    ↓
POST {noteId, rawResponse} to n8n
    ↓
n8n parses everything and saves to database
```

**Key simplification:** The Shortcut just passes the raw AI response back. n8n does ALL the parsing!

---

## Prerequisites

1. **n8n running** with the `02-llm-processing_apple` workflow active
2. **Apple device** with Shortcuts app (iOS 18+ or macOS 15+)
3. **Apple Intelligence** or **ChatGPT integration** enabled in Shortcuts
4. **Local network access** from your Apple device to n8n server

---

## Step-by-Step Setup

### Step 1: Create New Shortcut

1. Open **Shortcuts** app on your device
2. Tap **+** to create a new shortcut
3. Name it: `Selene Process Note`

### Step 2: Add Actions (Only 7!)

#### Action 1: Get Pending Note from n8n

**Add:** Get Contents of URL
- URL: `http://localhost:5678/webhook/api/apple/get-pending-note`
- Method: `GET`
- No headers needed

#### Action 2: Parse the Response

**Add:** Get Dictionary from Input
- Input: `Contents of URL`

#### Action 3: Check if Notes Exist

**Add:** If
- Condition: `Dictionary` > `hasPendingNotes` > equals > `true`
- If FALSE: Jump to step 7 (show "no pending notes")

**Inside the IF block:**

#### Action 4: Extract Note ID

**Add:** Get Dictionary Value
- Get: `noteId`
- From: `Dictionary`
- Variable name: `NoteID`

#### Action 5: Extract Prompt

**Add:** Get Dictionary Value
- Get: `prompt`
- From: `Dictionary`
- Variable name: `Prompt`

#### Action 6: Ask Apple Intelligence

**Add:** Ask ChatGPT (or Siri/Apple Intelligence)
- Input: `Prompt`
- Variable name: `AIResponse`

#### Action 7: Build Response Dictionary

**Add:** Dictionary
- Key: `noteId`, Value: `NoteID`
- Key: `rawResponse`, Value: `AIResponse`
- Variable name: `ResponseData`

#### Action 8: Send Back to n8n

**Add:** Get Contents of URL
- URL: `http://localhost:5678/webhook/api/apple/save-processed-note`
- Method: `POST`
- Headers:
  - Key: `Content-Type`, Value: `application/json`
- Request Body: `JSON`
- JSON: `ResponseData`

#### Action 9: Show Success

**Add:** Show Notification
- Title: `Note Processed!`
- Body: `Successfully processed note {NoteID}`

**End IF**

#### Action 10 (Outside IF): Show "No Pending"

**Add:** Show Notification (after the IF block's "Otherwise")
- Title: `No Pending Notes`
- Body: `All notes are processed!`

---

## Visual Flow

```
1. GET pending note
2. Parse to dictionary
3. IF hasPendingNotes = true:
   4. Get noteId
   5. Get prompt
   6. Ask Apple Intelligence
   7. Build {noteId, rawResponse}
   8. POST to n8n
   9. Show success
   ELSE:
   10. Show "no pending notes"
```

**That's it! Only 10 actions total, and 7 in the main flow.**

---

## Example Response from GET

```json
{
  "noteId": 123,
  "title": "Example Note",
  "content": "Full note content...",
  "noteType": "technical",
  "hasPendingNotes": true,
  "prompt": "You are an expert note analysis AI. Analyze the following note and provide a comprehensive analysis in THREE parts:\n\nThis is a TECHNICAL note. Focus on technologies, tools, methods, problems, solutions, and technical concepts discussed.\n\n## PART 1: CONCEPT EXTRACTION\nExtract 3-5 of the most important concepts...\n\n## PART 2: THEME DETECTION\nIdentify themes from this note...\n\n## PART 3: SENTIMENT ANALYSIS\nAnalyze the emotional tone...\n\n## NOTE TO ANALYZE:\n\n[note content here]\n\n## REQUIRED OUTPUT FORMAT:\n\nReturn ONLY valid JSON in this EXACT format:\n\n{\n  \"concepts\": [\"concept1\", \"concept2\", \"concept3\"],\n  \"concept_confidence\": {\"concept1\": 0.95, \"concept2\": 0.85},\n  \"primary_theme\": \"technical\",\n  \"secondary_themes\": [\"tools\", \"learning\"],\n  \"theme_confidence\": 0.87,\n  \"overall_sentiment\": \"positive\",\n  \"sentiment_score\": 0.7,\n  \"emotional_tone\": \"motivated\",\n  \"energy_level\": \"high\"\n}"
}
```

## What You POST Back

```json
{
  "noteId": 123,
  "rawResponse": "{\n  \"concepts\": [\"docker\", \"api\", \"automation\"],\n  \"concept_confidence\": {\"docker\": 0.92, \"api\": 0.88, \"automation\": 0.85},\n  \"primary_theme\": \"technical\",\n  \"secondary_themes\": [\"tools\", \"problem_solving\"],\n  \"theme_confidence\": 0.89,\n  \"overall_sentiment\": \"positive\",\n  \"sentiment_score\": 0.65,\n  \"emotional_tone\": \"focused\",\n  \"energy_level\": \"medium\"\n}"
}
```

**n8n handles parsing this, so even if Apple Intelligence adds extra text or markdown code blocks, n8n will handle it!**

---

## Running the Shortcut

### Manual Execution

1. Open Shortcuts app
2. Find `Selene Process Note`
3. Tap to run
4. Wait 10-30 seconds
5. See success notification

### Automated Execution (Recommended)

Create an automation to run periodically:

1. Open **Shortcuts** app → **Automation** tab
2. Create **Personal Automation**
3. Choose trigger:
   - **Time of Day**: Every hour at :00
   - **When I arrive**: Home location
   - **When I open an app**: Notes app
4. Add action: **Run Shortcut** → Select `Selene Process Note`
5. **Disable** "Ask Before Running" for automatic execution
6. **Disable** "Notify When Run" to avoid spam

Now your notes process automatically!

---

## Testing

### Test 1: Manual GET Test

```bash
curl http://localhost:5678/webhook/api/apple/get-pending-note
```

Expected output:
- If notes pending: `{noteId, prompt, hasPendingNotes: true}`
- If no notes: `{message: "No pending notes...", hasPendingNotes: false}`

### Test 2: Check for Pending Notes

```bash
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE status_apple = 'pending_apple';"
```

### Test 3: Manual POST Test

```bash
curl -X POST http://localhost:5678/webhook/api/apple/save-processed-note \
  -H "Content-Type: application/json" \
  -d '{
    "noteId": 1,
    "rawResponse": "{\"concepts\": [\"test\", \"automation\"], \"concept_confidence\": {\"test\": 0.9}, \"primary_theme\": \"technical\", \"secondary_themes\": [\"tools\"], \"theme_confidence\": 0.85, \"overall_sentiment\": \"positive\", \"sentiment_score\": 0.7, \"emotional_tone\": \"focused\", \"energy_level\": \"medium\"}"
  }'
```

### Test 4: Run Full Shortcut

1. Ingest a test note first:
   ```bash
   curl -X POST http://localhost:5678/webhook/api/ingest \
     -H "Content-Type: application/json" \
     -d '{"title": "Test", "content": "Testing Apple Intelligence with my workflow automation system."}'
   ```

2. Run your Shortcut

3. Check database:
   ```bash
   sqlite3 data/selene.db "SELECT * FROM processed_notes_apple ORDER BY processed_at DESC LIMIT 1;"
   ```

---

## Troubleshooting

### Issue: "No pending notes" every time

**Check:**
```bash
# See if any notes are pending
sqlite3 data/selene.db "SELECT id, title, status_apple FROM raw_notes WHERE status_apple = 'pending_apple';"

# Check if they got stuck
sqlite3 data/selene.db "SELECT id, status_apple, COUNT(*) FROM raw_notes GROUP BY status_apple;"
```

**Fix stuck notes:**
```bash
sqlite3 data/selene.db "UPDATE raw_notes SET status_apple = 'pending_apple' WHERE status_apple = 'processing_apple';"
```

### Issue: Cannot connect to n8n

**Solutions:**
- Use your computer's IP address instead of `localhost`
  - Find IP: System Preferences → Network (e.g., `192.168.1.100`)
  - Update URL: `http://192.168.1.100:5678/webhook/...`
- Ensure both devices on same WiFi
- Check n8n is running: Open http://localhost:5678 in browser

### Issue: Workflow not active

**Fix:**
1. Open n8n UI: http://localhost:5678
2. Go to **Workflows**
3. Find `Selene: LLM Processing (Apple Intelligence) - Simplified`
4. Toggle **Active** to ON (green)

### Issue: Apple Intelligence returns invalid JSON

**Good news:** n8n handles this automatically!

The `Parse AI Response` node:
1. Tries to parse as JSON
2. Strips markdown code blocks (```json)
3. If JSON fails, extracts data from text
4. Always produces valid output

You don't need to do anything special in the Shortcut!

### Issue: Shortcut fails at POST step

**Check the error message:**
- If "noteId required": Check step 4 variable name is exactly `NoteID`
- If "rawResponse required": Check step 6 variable name is exactly `AIResponse`
- Variable names are case-sensitive!

---

## Performance

### Expected Timing

- **GET pending note:** < 1 second
- **Apple Intelligence processing:** 10-30 seconds
- **POST save results:** < 1 second
- **Total:** 11-31 seconds per note

### Throughput

- **Manual:** 2-5 notes per minute
- **Hourly automation:** 1 note per hour
- **On-demand (location-based):** Processes when you get home

---

## Advanced: Process Multiple Notes

Want to process all pending notes in one run?

**Add a Repeat loop:**

1. After step 2, add **Repeat** with count: `10`
2. Put steps 3-9 inside the Repeat
3. Add at the end of repeat: **Wait** 2 seconds (to avoid overwhelming n8n)

Now it processes up to 10 notes per run!

---

## Comparison with Ollama

| Feature | Ollama | Apple Intelligence |
|---------|--------|-------------------|
| **Trigger** | Automatic (cron) | Manual/Automation |
| **Speed** | 5-10s | 10-30s |
| **Shortcut Actions** | N/A | 10 actions |
| **Complexity** | High (n8n only) | Low (simple Shortcut) |
| **Parsing** | n8n | n8n |
| **Results Table** | `processed_notes` | `processed_notes_apple` |

Both approaches use the same prompts and produce comparable results!

---

## Next Steps

1. **Create the shortcut** following steps above
2. **Test with one note** manually
3. **Verify results** in database
4. **Set up automation** for periodic processing
5. **Compare results** with Ollama processing

---

## Summary

**What the Shortcut does:**
1. Gets pending note + prompt from n8n
2. Asks Apple Intelligence once
3. Returns raw response to n8n
4. Shows notification

**What n8n does:**
1. Builds the combined prompt
2. Parses the AI response (JSON or text)
3. Extracts concepts, themes, sentiment
4. Saves to database
5. Updates note status

**Total Shortcut complexity:** 10 actions, ~5 minutes to set up!

---

**Ready to process notes with Apple Intelligence! 🍎✨**
