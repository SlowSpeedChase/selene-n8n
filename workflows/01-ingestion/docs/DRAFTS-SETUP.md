# Drafts App Integration Setup

## Overview

This guide will help you set up the Drafts app on iOS/macOS to send notes to your Selene n8n ingestion workflow.

## Prerequisites

- ✅ n8n is running at http://localhost:5678
- ✅ Ingestion workflow is imported and activated
- ✅ Drafts app installed on iOS or macOS

## Network Configuration

### Option 1: Same Device (macOS Drafts to Local n8n) ⭐ EASIEST

If you're running Drafts on the **same Mac** where n8n is running:

> **IMPORTANT:** The webhook path depends on workflow activation status:
> - **Activated:** `http://localhost:5678/webhook/api/drafts`
> - **Not Activated (Testing):** `http://localhost:5678/webhook-test/api/drafts`

**Webhook URL (activated):** `http://localhost:5678/webhook/api/drafts`

This is the simplest setup - no network configuration needed!

### Option 2: iOS Device on Same Network (Recommended for Mobile)

If you want to use Drafts on your **iPhone/iPad** while n8n runs on your Mac:

#### Step 1: Find Your Mac's IP Address

```bash
# On your Mac, run:
ifconfig | grep "inet " | grep -v 127.0.0.1

# Look for something like: inet 192.168.1.XXX
```

Common formats:
- **192.168.1.XXX** (typical home network)
- **10.0.0.XXX** (some routers)
- **172.16.XXX.XXX** (less common)

#### Step 2: Test Accessibility from iOS

On your iPhone/iPad, open Safari and navigate to:
```
http://YOUR-MAC-IP:5678/healthz
```

You should see: `{"status":"ok"}`

> **IMPORTANT:** Check if your n8n workflow is activated:
> - **Activated:** Use `/webhook/api/drafts`
> - **Not Activated:** Use `/webhook-test/api/drafts`

**Webhook URL (activated):** `http://YOUR-MAC-IP:5678/webhook/api/drafts`
**Webhook URL (testing):** `http://YOUR-MAC-IP:5678/webhook-test/api/drafts`

Example: `http://192.168.1.100:5678/webhook/api/drafts`

⚠️ **Important:** Your Mac must be:
- On the same WiFi network as your iOS device
- Not in sleep mode when you send notes
- Have firewall configured to allow port 5678

#### Firewall Configuration (if needed)

```bash
# Check if port 5678 is accessible
sudo lsof -i :5678

# If blocked, add firewall rule (macOS):
# System Settings > Network > Firewall > Options
# Add rule: Allow incoming connections for port 5678
```

### Option 3: Public Access (Advanced)

If you need to access from anywhere (different networks, outside home):

**Options:**
1. **Tailscale/VPN** (Recommended - secure)
2. **ngrok** (Quick testing)
3. **Port forwarding** (Requires router access, security risk)

See "Public Access Setup" section below for details.

## Creating the Drafts Action

### Method 1: Import Pre-Made Action (Recommended)

1. **Open Drafts App**
2. **Tap the Action Directory icon** (bottom right, grid icon)
3. **Search for "Selene n8n"** (if you've published it) OR
4. **Use the action JSON below** to create manually

### Method 2: Create Action Manually

#### Step 1: Create New Action

1. Open **Drafts** app
2. Tap **Action Directory** (grid icon)
3. Tap **+** to create new action
4. Name it: **"Send to Selene"**

#### Step 2: Configure HTTP Request

1. **Add Step** → **Script** → **HTTP Request**
2. Configure settings:

**URL:**
```
http://localhost:5678/webhook/api/drafts
```
*(Replace with your actual URL from Network Configuration above)*

**Method:** `POST`

**Headers:**
```
Content-Type: application/json
```

**Body Template:**
```javascript
{
  "title": "[[title]]",
  "content": "[[body]]",
  "created_at": "[[created_iso]]",
  "source_type": "drafts"
}
```

**Optional - Add test_run for testing:**
```javascript
{
  "title": "[[title]]",
  "content": "[[body]]",
  "created_at": "[[created_iso]]",
  "source_type": "drafts",
  "test_run": "drafts-test"
}
```

#### Step 3: Configure Response Handling (Optional)

Add another step: **Script** → **Script**

```javascript
// Check if the note was successfully sent
if (draft.processedText.indexOf('"success":true') > -1) {
  app.displaySuccessMessage("Note sent to Selene!");
} else {
  app.displayWarningMessage("Note queued in n8n");
}
```

#### Step 4: Save Action

1. Tap **Done**
2. The action is now available in your action list

## Drafts Action JSON (Advanced)

For quick import, here's the complete action configuration:

```json
{
  "name": "Send to Selene",
  "steps": [
    {
      "type": "http",
      "method": "POST",
      "url": "http://localhost:5678/webhook/api/drafts",
      "headers": {
        "Content-Type": "application/json"
      },
      "body": {
        "title": "[[title]]",
        "content": "[[body]]",
        "created_at": "[[created_iso]]",
        "source_type": "drafts"
      }
    }
  ]
}
```

## Testing Your Setup

### Test 1: Simple Note

1. **Create a test note in Drafts:**
   ```
   Test Note from Drafts

   This is a test to verify the integration works.
   ```

2. **Run your "Send to Selene" action**

3. **Verify in database:**
   ```bash
   sqlite3 data/selene.db "SELECT title, content FROM raw_notes ORDER BY id DESC LIMIT 1;"
   ```

### Test 2: Note with Tags

1. **Create a note with hashtags:**
   ```
   My Note with Tags

   This note includes #productivity and #ideas tags.
   ```

2. **Run the action**

3. **Verify tags were extracted:**
   ```bash
   sqlite3 data/selene.db "SELECT title, tags FROM raw_notes ORDER BY id DESC LIMIT 1;"
   ```

Expected: `["productivity","ideas"]`

### Test 3: Duplicate Prevention

1. **Send the same note twice**
2. **Check database:**
   ```bash
   sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE title='Test Note from Drafts';"
   ```

Expected: `1` (duplicate should be rejected)

## Troubleshooting

### Error: "Could not connect to server"

**On Same Device (localhost):**
- ✅ Check n8n is running: `docker-compose ps`
- ✅ Check URL is exactly: `http://localhost:5678/webhook/api/drafts`

**On Different Device (iOS):**
- ✅ Verify both devices on same WiFi network
- ✅ Test Mac IP in Safari: `http://YOUR-MAC-IP:5678/healthz`
- ✅ Check firewall settings on Mac
- ✅ Ensure Mac is not in sleep mode

### Error: "Workflow was started" but no data in database

- ✅ Check workflow is activated in n8n UI
- ✅ Check for errors in n8n logs: `docker-compose logs n8n --tail=50`
- ✅ Verify the workflow was re-imported after recent updates

### Notes appearing multiple times

- This shouldn't happen - duplicate detection should prevent it
- Check if you modified the content slightly between sends
- Verify content_hash is being generated correctly

### Mac going to sleep breaks connection

**Solution:** Keep Mac awake or use:
```bash
# Prevent Mac from sleeping while plugged in
caffeinate -s
```

Or use **Energy Saver settings** to prevent sleep.

## Public Access Setup (Advanced)

### Option A: Tailscale (Recommended - Secure)

1. **Install Tailscale:**
   ```bash
   brew install tailscale
   sudo tailscale up
   ```

2. **Install Tailscale on iOS** (from App Store)

3. **Get Tailscale IP:**
   ```bash
   tailscale ip -4
   ```

4. **Use Tailscale URL in Drafts:**
   ```
   http://TAILSCALE-IP:5678/webhook/api/drafts
   ```

**Benefits:**
- ✅ Secure encrypted connection
- ✅ Works from anywhere
- ✅ No port forwarding needed
- ✅ Private network

### Option B: ngrok (Quick Testing Only)

**⚠️ Warning:** ngrok URLs change on restart, not suitable for permanent setup

1. **Install ngrok:**
   ```bash
   brew install ngrok
   ```

2. **Start tunnel:**
   ```bash
   ngrok http 5678
   ```

3. **Copy the HTTPS URL** (e.g., `https://abc123.ngrok.io`)

4. **Use in Drafts:**
   ```
   https://abc123.ngrok.io/webhook/api/drafts
   ```

**Limitations:**
- URL changes every time you restart ngrok
- Free tier has limitations
- Not suitable for production

### Option C: Port Forwarding (Not Recommended)

**⚠️ Security Risk:** Exposes your n8n instance to the internet

Only use if you understand the security implications and add authentication.

## Production Tips

### 1. Always Mark Drafts Tests

When testing, include `test_run` in your action:

```javascript
{
  "title": "[[title]]",
  "content": "[[body]]",
  "created_at": "[[created_iso]]",
  "source_type": "drafts",
  "test_run": "drafts-testing"
}
```

Then clean up: `./workflows/01-ingestion/cleanup-tests.sh drafts-testing`

### 2. Create Multiple Actions

Consider creating variations:
- **Send to Selene** (production)
- **Send to Selene (Test)** (with test_run marker)
- **Quick Capture** (minimal processing)

### 3. Use Drafts Workspaces

Organize your drafts:
- **Inbox** - New captures
- **To Process** - Needs review before sending
- **Sent** - Already sent to Selene

### 4. Add Confirmation

Add a final step to archive or delete sent drafts:

```javascript
// Archive the draft after successful send
draft.isArchived = true;
```

## Advanced: Batch Processing

To send multiple drafts at once, create a script action:

```javascript
// Get all drafts in current workspace
let drafts = Workspace.query("", "inbox");

for (let d of drafts) {
  let http = HTTP.create();

  let response = http.request({
    "url": "http://localhost:5678/webhook/api/drafts",
    "method": "POST",
    "headers": {
      "Content-Type": "application/json"
    },
    "data": {
      "title": d.title,
      "content": d.content,
      "created_at": d.createdAt.toISOString(),
      "source_type": "drafts"
    }
  });

  if (response.success) {
    d.isArchived = true;
    d.update();
  }
}

app.displaySuccessMessage("Batch send complete!");
```

## Next Steps

After setting up Drafts:

1. **Test thoroughly** with the test cases above
2. **Set up the 02-llm-processing workflow** to process your notes
3. **Configure Obsidian export** for note management
4. **Create custom Drafts actions** for different note types

## Support

If you encounter issues:

1. Check n8n logs: `docker-compose logs n8n --tail=100`
2. Verify database: `sqlite3 data/selene.db "SELECT * FROM raw_notes ORDER BY id DESC LIMIT 5;"`
3. Test webhook directly: `curl -X POST http://localhost:5678/webhook/api/drafts -H "Content-Type: application/json" -d '{"title":"Test","content":"Test"}'`

## Resources

- [Drafts Actions Directory](https://actions.getdrafts.com/)
- [Drafts Scripting Reference](https://scripting.getdrafts.com/)
- [n8n Webhook Documentation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/)
