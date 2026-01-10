# Drafts JavaScript Action - Quick Setup

This guide shows you how to set up the Selene JavaScript action in Drafts for a more powerful, customizable integration.

## Why Use the JavaScript Action?

The JavaScript action offers several advantages over the basic HTTP Request action:
- ✅ Easy configuration at the top of the script
- ✅ Automatic network detection (local WiFi, Tailscale, or Mac)
- ✅ Built-in error handling and user-friendly messages
- ✅ Optional health check before sending
- ✅ Test mode with cleanup marker
- ✅ Optional auto-archive after successful send

---

## Setup Instructions

### Step 1: Get the JavaScript Code

The complete JavaScript action is available at:
```
workflows/01-ingestion/docs/drafts-selene-action.js
```

Copy the entire contents of this file.

### Step 2: Create the Action in Drafts

#### On iOS/iPadOS:
1. Open **Drafts** app
2. Tap the **Action Directory** (grid icon at bottom)
3. Tap **+** (top right) to create a new action
4. Name it: **"Send to Selene"**
5. Tap **Add Step**
6. Select **Script** → **Script**
7. Paste the JavaScript code
8. Tap **Done**

#### On macOS:
1. Open **Drafts** app
2. Click **Action Directory** in the sidebar (or press `⌘3`)
3. Click **+** to create a new action
4. Name it: **"Send to Selene"**
5. Click **+ Add Step**
6. Select **Script** → **Script**
7. Paste the JavaScript code
8. Click **Done**

### Step 3: Configure for Your Environment

At the top of the script, you'll see the `CONFIG` section. Update it with your settings:

```javascript
const CONFIG = {
  // Choose your network environment
  network: "local",  // Options: "local", "tailscale", "mac"

  // Your IP addresses
  localIP: "192.168.1.26",      // Your Mac's local IP
  tailscaleIP: "100.111.6.10",  // Your Tailscale IP (if using)

  // n8n configuration
  port: "5678",

  // Webhook path - IMPORTANT: Check your n8n workflow status!
  // If activated (production): "/webhook/api/drafts"
  // If NOT activated (testing): "/webhook-test/api/drafts"
  webhookPath: "/webhook/api/drafts",

  // Testing mode
  testMode: false,              // Set to true for testing
  testMarker: "drafts-test"
};
```

#### Network Options:
- **"local"** - Use when on the same WiFi as your Mac (uses `localIP`)
- **"tailscale"** - Use when connected via Tailscale VPN (uses `tailscaleIP`)
- **"mac"** - Use when running Drafts on your Mac (uses `localhost`)

---

## First Test

### 1. Enable Test Mode

Edit the action and set:
```javascript
testMode: true
```

### 2. Create a Test Note

In Drafts, create a new note:
```
Test from Drafts JavaScript Action

This is testing the new JavaScript-based Selene integration.

#test #drafts
```

### 3. Run the Action

- **iOS/iPadOS:** Swipe left on the draft → Select "Send to Selene"
- **macOS:** Right-click the draft → Select "Send to Selene" (or assign a keyboard shortcut)

### 4. Verify Success

You should see: **"✓ Sent to Selene (TEST MODE)"**

On your Mac, verify it was received:
```bash
sqlite3 data/selene.db "SELECT title, tags FROM raw_notes WHERE metadata LIKE '%drafts-test%' ORDER BY id DESC LIMIT 1;"
```

### 5. Clean Up Test Data

```bash
./workflows/01-ingestion/cleanup-tests.sh drafts-test
```

### 6. Disable Test Mode

Edit the action and set:
```javascript
testMode: false
```

---

## Optional Features

### Auto-Archive After Send

To automatically archive drafts after successfully sending to Selene, uncomment these lines in the script:

```javascript
// Optional: Archive the draft after successful send
draft.isArchived = true;
draft.update();
```

### Connection Health Check

To verify n8n is reachable before sending, uncomment this section:

```javascript
// Optional: Uncomment to test connection first
const health = checkHealth();
if (!health.success) {
  alert("Connection Failed", "Cannot reach n8n server. Check that:\n1. n8n is running\n2. You're on the correct network\n3. IP address is correct");
  context.fail();
}
```

### Keyboard Shortcut (macOS)

1. Open the action in the Action Directory
2. Click **Options** (gear icon)
3. Click **Add Keyboard Shortcut**
4. Press your desired key combination (e.g., `⌘⇧S`)

### Action Group

Create a dedicated action group for Selene actions:
1. Create a new Action Group called "Selene"
2. Add the "Send to Selene" action to it
3. Set the action group as default or access via action list

---

## Troubleshooting

### "Connection Failed" or 404 Error

**Most Common Issue: Wrong Webhook Path**

n8n uses different webhook paths depending on whether the workflow is activated:
- **Activated workflow:** `/webhook/api/drafts`
- **Test/inactive workflow:** `/webhook-test/api/drafts`

To fix:
1. Open n8n at `http://localhost:5678`
2. Open the "Selene: Note Ingestion" workflow
3. Check if it's **ACTIVATED** (toggle in top right)
4. Update the `webhookPath` in your Drafts action CONFIG to match

**Other Connection Checks:**
1. Is n8n running? → `docker-compose ps`
2. Is your `network` setting correct in CONFIG?
3. Are you on the correct network (WiFi/Tailscale)?
4. Is the IP address correct?

**Test from Safari/browser:**
```
http://192.168.1.26:5678/healthz
```
Should return: `{"status":"ok"}`

### "Send Failed" Error

**Check these:**
1. Is the workflow activated in n8n?
2. Check n8n logs: `docker-compose logs n8n --tail=20`
3. Try enabling test mode and checking the error message

### Works on Mac but Not iPhone

Your Mac's firewall may be blocking connections:
1. **System Settings** → **Network** → **Firewall**
2. Allow connections on port 5678
3. Or temporarily disable to test

### "Cannot parse response" Error

This usually means n8n is running but the workflow isn't responding correctly:
1. Check workflow is **activated** in n8n
2. Verify webhook URL in workflow matches your configuration
3. Check n8n logs for errors

---

## Switching Networks

You can easily switch between networks by changing the `network` setting:

```javascript
// At home on WiFi
network: "local"

// Away from home, using Tailscale
network: "tailscale"

// On your Mac
network: "mac"
```

No need to change the IP addresses - the script automatically uses the right one!

---

## Advanced: Multiple Environments

If you need to quickly switch between environments (e.g., development and production), you can create multiple versions of the action:

1. **"Send to Selene (Dev)"** - Points to development server
2. **"Send to Selene (Prod)"** - Points to production server

Just duplicate the action and update the IP addresses and port in each.

---

## Next Steps

- Assign a keyboard shortcut for quick access
- Set up auto-archive for a cleaner workflow
- Create additional actions for different note types
- Explore Drafts' automation features with the action

For the original HTTP Request-based setup, see **DRAFTS-QUICKSTART.md**
