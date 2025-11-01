# Drafts Integration

**App:** Drafts (iOS/macOS)
**Method:** HTTP POST to n8n webhook
**Endpoint:** `http://localhost:5678/webhook/selene/ingest`

## Overview

Drafts integration is simplified in the n8n version - no complex x-callback-url protocol, no Python HTTP server, just a simple POST request.

## What We're NOT Using (Python Approach)

The Python version had:
- ❌ Complex HTTP server with threading
- ❌ x-callback-url protocol
- ❌ Retry logic and timeout handling
- ❌ 1200+ lines of code

## What We ARE Using (n8n Approach)

Simple Drafts action script:
- ✅ HTTP.create() from Drafts API
- ✅ POST JSON payload to n8n webhook
- ✅ Display success/error message
- ✅ ~30 lines of code

## Drafts Action Script

### File Location
`/drafts-actions/send-to-selene.js`

### Complete Script

```javascript
// Selene n8n Integration
// Sends current draft to Selene for processing

const WEBHOOK_URL = "http://localhost:5678/webhook/selene/ingest";

// Build payload from current draft
const payload = {
  uuid: draft.uuid,
  title: draft.title || "Untitled",
  content: draft.content,
  tags: draft.tags,
  created: draft.createdAt.toISOString()
};

// Create HTTP client
const http = HTTP.create();

// Send POST request to n8n
const response = http.request({
  url: WEBHOOK_URL,
  method: "POST",
  headers: {
    "Content-Type": "application/json"
  },
  data: payload
});

// Handle response
if (response.success) {
  app.displayInfoMessage("✅ Sent to Selene!");
  console.log("Response:", response.responseText);
} else {
  app.displayErrorMessage(`❌ Failed: ${response.statusCode}`);
  console.log("Error:", response.error);
}
```

### Payload Format

```json
{
  "uuid": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
  "title": "My Note Title",
  "content": "The full note content goes here...",
  "tags": ["work", "project", "planning"],
  "created": "2025-10-30T10:30:00.000Z"
}
```

**Fields:**
- `uuid` - Unique Draft identifier (prevents duplicates)
- `title` - First line of draft or "Untitled"
- `content` - Full draft text
- `tags` - Array of tags assigned in Drafts
- `created` - ISO 8601 timestamp of draft creation

## Setting Up in Drafts

### 1. Create New Action

1. Open Drafts app
2. Tap/click Actions (⚙️) icon
3. Tap "+" to create new action
4. Name it "Send to Selene"

### 2. Add Script Step

1. In action editor, tap "+"
2. Choose "Script"
3. Paste the complete script above
4. Save

### 3. Configure Action (Optional)

**Icon:** 🧠 or 📝
**Color:** Purple or Blue
**Keyboard Shortcut:** ⌘⇧S (or your preference)

### 4. Test Action

1. Create a test draft with some content
2. Run "Send to Selene" action
3. Should see "✅ Sent to Selene!" message
4. Verify in database:
   ```bash
   sqlite3 /selene/data/selene.db "SELECT * FROM raw_notes WHERE uuid = 'YOUR-UUID';"
   ```

## Webhook Endpoint Configuration

### n8n Webhook Node

**Workflow:** 01-ingestion

**Node Configuration:**
- **HTTP Method:** POST
- **Path:** `selene/ingest`
- **Respond:** Immediately
- **Response Code:** 200
- **Response Data:** JSON

**Full URL:** `http://localhost:5678/webhook/selene/ingest`

### Expected Request

**Method:** POST

**Headers:**
```
Content-Type: application/json
```

**Body:** JSON payload (see format above)

### Response Format

**Success (200):**
```json
{
  "success": true,
  "message": "Note received",
  "note_id": 123
}
```

**Error (400):**
```json
{
  "success": false,
  "error": "Missing required field: content"
}
```

**Error (500):**
```json
{
  "success": false,
  "error": "Database error"
}
```

## Testing the Integration

### 1. Test Webhook Directly

```bash
curl -X POST http://localhost:5678/webhook/selene/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "uuid": "test-123",
    "title": "Test Note",
    "content": "This is a test note about project planning.",
    "tags": ["test"],
    "created": "2025-10-30T10:00:00Z"
  }'
```

**Expected Output:**
```json
{
  "success": true,
  "message": "Note received",
  "note_id": 1
}
```

### 2. Test from Drafts App

1. Create draft with content:
   ```
   Test Note

   This is a test of the Selene integration.
   Project planning and task management.
   ```
2. Add tags: `test`, `work`
3. Run "Send to Selene" action
4. Check for success message

### 3. Verify in Database

```bash
sqlite3 /selene/data/selene.db "SELECT * FROM raw_notes ORDER BY id DESC LIMIT 1;"
```

Should show your test note with status 'pending'.

### 4. Wait for Processing

After ~30 seconds (when cron triggers), check processed:

```bash
sqlite3 /selene/data/selene.db "SELECT title, concepts, themes FROM processed_notes ORDER BY id DESC LIMIT 1;"
```

Should show extracted concepts and themes.

## Error Handling

### Common Issues

#### 1. Connection Refused

**Error:** `❌ Failed: 0` or connection timeout

**Causes:**
- n8n not running
- Wrong webhook URL
- Network issue

**Fix:**
```bash
# Check n8n is running
curl http://localhost:5678

# Check workflow is active in n8n UI
# Verify webhook URL matches script
```

#### 2. 404 Not Found

**Error:** `❌ Failed: 404`

**Causes:**
- Workflow not activated
- Wrong webhook path
- Workflow deleted

**Fix:**
- Open n8n: http://localhost:5678
- Check workflow 01-ingestion is active (toggle in top right)
- Verify webhook path is `/selene/ingest`

#### 3. 500 Server Error

**Error:** `❌ Failed: 500`

**Causes:**
- Database error
- Workflow misconfigured
- Missing fields in payload

**Fix:**
- Check n8n execution log for details
- Verify database exists and is writable
- Check workflow error details

#### 4. Duplicate UUID Error

**Error:** Database constraint violation

**Causes:**
- Sending same draft twice
- UUID collision (extremely rare)

**Fix:**
- Expected behavior - prevents duplicates
- Check database: `SELECT * FROM raw_notes WHERE uuid = 'THE-UUID';`
- If truly want to resend, change UUID in script temporarily

## Advanced Configuration

### Custom Webhook URL

If using different n8n port or hostname:

```javascript
const WEBHOOK_URL = "http://your-server:5678/webhook/selene/ingest";
```

### Additional Fields

Add custom fields to payload:

```javascript
const payload = {
  uuid: draft.uuid,
  title: draft.title || "Untitled",
  content: draft.content,
  tags: draft.tags,
  created: draft.createdAt.toISOString(),
  // Custom fields
  location: draft.latitude && draft.longitude
    ? `${draft.latitude},${draft.longitude}`
    : null,
  wordCount: draft.content.split(/\s+/).length,
  source: "drafts-ios"  // or "drafts-mac"
};
```

Then update n8n workflow to handle these fields.

### Conditional Processing

Only send drafts with specific tag:

```javascript
// Only send drafts tagged "selene"
if (!draft.tags.includes("selene")) {
  app.displayWarningMessage("⚠️ Add 'selene' tag to send");
  context.cancel();
}

// ... rest of script
```

### Archive After Sending

Automatically archive draft after successful send:

```javascript
if (response.success) {
  app.displayInfoMessage("✅ Sent to Selene!");
  draft.isArchived = true;
  draft.update();
} else {
  app.displayErrorMessage(`❌ Failed: ${response.statusCode}`);
}
```

## Test Connection Script

Simpler script to just test connection:

**File:** `/drafts-actions/test-connection.js`

```javascript
// Test Selene Connection
const WEBHOOK_URL = "http://localhost:5678/webhook/selene/ingest";

const http = HTTP.create();
const response = http.request({
  url: WEBHOOK_URL,
  method: "POST",
  headers: {"Content-Type": "application/json"},
  data: {
    uuid: `test-${Date.now()}`,
    title: "Connection Test",
    content: "Testing connection to Selene",
    tags: ["test"],
    created: new Date().toISOString()
  }
});

if (response.success) {
  app.displayInfoMessage(`✅ Connected! Note ID: ${JSON.parse(response.responseText).note_id}`);
} else {
  app.displayErrorMessage(`❌ Connection failed: ${response.statusCode}`);
}
```

## Comparison to Python Version

| Aspect | Python Version | n8n Version |
|--------|---------------|-------------|
| **Code Lines** | ~1200 | ~30 |
| **Setup** | HTTP server, threading, x-callback | Single Drafts action |
| **Retry Logic** | Exponential backoff | Simple success/fail |
| **Callback URL** | x-callback-url protocol | Standard HTTP POST |
| **Error Handling** | Complex timeout handling | Status code check |
| **Maintenance** | Python expertise needed | Modify 30-line script |
| **Reliability** | Complex, many failure points | Simple, one HTTP call |

## Security Considerations

### Local Network Only

**Current setup:** Webhook only accessible on localhost

**If exposing to network:**
1. Add authentication token to webhook
2. Use HTTPS
3. Validate requests in n8n workflow
4. Rate limiting

### No Sensitive Data

Drafts content is sent in plaintext over local network. Don't include:
- Passwords
- API keys
- Credit card numbers
- Other secrets

Use Drafts' built-in security features for sensitive notes.

## Related Documentation

- [03-PHASE-1-CORE.md](./03-PHASE-1-CORE.md) - Ingestion workflow details
- [13-N8N-WORKFLOW-SPECS.md](./13-N8N-WORKFLOW-SPECS.md) - Webhook node configuration
- [15-TESTING.md](./15-TESTING.md) - Testing procedures
- [22-TROUBLESHOOTING.md](./22-TROUBLESHOOTING.md) - Common issues
