# n8n Webhook Paths - Quick Reference

## The Issue

n8n uses **different webhook URLs** depending on whether a workflow is activated or not. This is a common source of confusion!

## Webhook Path Reference

Your n8n workflow uses the path: `api/drafts`

### When Workflow is ACTIVATED (Production Mode)
```
http://localhost:5678/webhook/api/drafts              # macOS
http://192.168.1.26:5678/webhook/api/drafts           # Local network
http://100.111.6.10:5678/webhook/api/drafts           # Tailscale
```

### When Workflow is NOT ACTIVATED (Test Mode)
```
http://localhost:5678/webhook-test/api/drafts         # macOS
http://192.168.1.26:5678/webhook-test/api/drafts      # Local network
http://100.111.6.10:5678/webhook-test/api/drafts      # Tailscale
```

Notice the difference: `/webhook/` vs `/webhook-test/`

## How to Check Workflow Status

1. Open n8n at `http://localhost:5678`
2. Open your "Selene: Note Ingestion" workflow
3. Look at the **top right corner** for the activation toggle
4. If it's **ON (blue)** → Use `/webhook/` path
5. If it's **OFF (gray)** → Use `/webhook-test/` path

## Quick Fix for Drafts

### In the JavaScript Action:

Edit line 21 in the CONFIG section:

```javascript
// If workflow is ACTIVATED:
webhookPath: "/webhook/api/drafts",

// If workflow is NOT activated:
webhookPath: "/webhook-test/api/drafts",
```

### In the HTTP Request Action:

Update the URL field:

**Activated:**
```
http://192.168.1.26:5678/webhook/api/drafts
```

**Not Activated:**
```
http://192.168.1.26:5678/webhook-test/api/drafts
```

## Testing the Webhook

### Test if webhook is working:

```bash
# For activated workflow:
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","content":"Testing webhook","source_type":"curl"}'

# For test/inactive workflow:
curl -X POST http://localhost:5678/webhook-test/api/drafts \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","content":"Testing webhook","source_type":"curl"}'
```

### Expected Response:

```json
{
  "success": true,
  "action": "stored",
  "message": "Note successfully ingested into raw_notes table",
  "noteId": 123,
  "title": "Test",
  "wordCount": 2,
  "contentHash": "...",
  "sourceType": "curl",
  "status": "pending"
}
```

## Common Error Messages

### 404 Not Found
```
Cannot POST /webhook/api/drafts
```
**Fix:** Change to `/webhook-test/api/drafts` (workflow not activated)

### Connection Refused
```
ECONNREFUSED
```
**Fix:** n8n is not running. Start it with `docker-compose up -d`

### 502 Bad Gateway
```
Bad Gateway
```
**Fix:** n8n is starting up or has crashed. Check `docker-compose logs n8n`

## Recommendation

**For production use:** Always **activate** the workflow and use `/webhook/` path. This ensures:
- Consistent URLs
- Better reliability
- Automatic execution on workflow updates
- No confusion about which endpoint to use

To activate:
1. Open the workflow in n8n
2. Click the **Activate** toggle (top right)
3. Update all Drafts actions to use `/webhook/api/drafts`
