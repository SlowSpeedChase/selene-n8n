# Instructions for Building Selene Workflow Integrations

This document provides Claude Code with the patterns, requirements, and standards established during the Drafts integration. Use these guidelines when building subsequent workflow steps and integrations.

---

## Project Context

**Project:** Selene - Personal Knowledge Management System
**Architecture:** n8n workflows + SQLite database + External integrations
**Current Environment:** Docker-based n8n running on macOS

### Key Paths
- **Workflows:** `/workflows/[workflow-name]/`
- **Documentation:** `/workflows/[workflow-name]/docs/`
- **Database:** `/data/selene.db`
- **n8n Access:** `http://localhost:5678`

---

## Integration Development Pattern

When building a new integration or workflow step, follow this pattern:

### 1. JavaScript Action/Script (If Applicable)

**File:** `workflows/[workflow-name]/docs/[source]-action.js`

**Required Features:**
- ✅ Configuration section at the top of the script
- ✅ Clear comments explaining each option
- ✅ Support for multiple environments (local/network/VPN)
- ✅ Built-in error handling with user-friendly messages
- ✅ Test mode support with cleanup markers
- ✅ Optional features (commented out, ready to enable)

**Configuration Template:**
```javascript
const CONFIG = {
  // Network environment
  network: "local",  // Options: "local", "vpn", "mac"

  // Connection details
  localIP: "192.168.1.26",
  vpnIP: "100.111.6.10",
  port: "5678",

  // Endpoint configuration
  webhookPath: "/webhook/api/[name]",

  // Testing mode
  testMode: false,
  testMarker: "[name]-test"
};
```

**Error Handling Pattern:**
```javascript
try {
  const result = performAction();

  if (result.success) {
    app.displayInfoMessage("✓ Success message");
    context.cancel(); // Clean exit
  } else {
    alert("Action Failed", `Error: ${result.error}\n\nTroubleshooting steps here`);
    context.fail();
  }
} catch (error) {
  alert("Error", `An error occurred:\n\n${error.message}`);
  context.fail();
}
```

### 2. Comprehensive Documentation

Create **three documentation files** for each integration:

#### A. Setup Guide
**File:** `[SOURCE]-SETUP.md`

**Required Sections:**
1. **Overview** - What this integration does
2. **Prerequisites** - What must be ready first
3. **Network Configuration** - Multiple environment options
4. **Step-by-Step Setup** - Detailed instructions
5. **Testing** - How to verify it works
6. **Troubleshooting** - Common issues and fixes
7. **Production Readiness** - Moving from test to production

#### B. JavaScript Action Guide (if applicable)
**File:** `[SOURCE]-JAVASCRIPT-ACTION.md`

**Required Sections:**
1. **Why Use This** - Advantages over alternatives
2. **Setup Instructions** - Platform-specific steps
3. **Configuration Guide** - Detailed CONFIG explanation
4. **First Test** - Step-by-step testing procedure
5. **Optional Features** - How to enable extras
6. **Troubleshooting** - Specific to this action
7. **Advanced Usage** - Power user features

#### C. Quick Reference
**File:** `[SOURCE]-REFERENCE.md` or `WEBHOOK-PATHS.md`

**Required Sections:**
1. **Quick Facts** - One-page reference
2. **Common URLs/Endpoints**
3. **Test Commands** - curl examples
4. **Expected Responses**
5. **Error Messages** - What they mean and how to fix

### 3. Status Document

**File:** `[SOURCE]-STATUS.md`

Create this when the integration is **complete and tested**.

**Required Sections:**
1. **Status and Date**
2. **What Was Completed**
3. **Current Configuration**
4. **Test Results**
5. **Next Steps** (optional enhancements)
6. **Files Created**
7. **Technical Details**
8. **Testing & Validation**

---

## n8n Workflow Standards

### Test/Production Workflow Process

**CRITICAL:** Always work in test workflows first. Only deploy to production after explicit user approval.

#### Development Workflow

**Phase 1: Development (TEST)**
1. Make all changes in `workflow-test.json` files
2. Use test webhook paths: `/webhook-test/api/[endpoint]`
3. Configure Drafts action or other sources to use test endpoints
4. Test thoroughly with test data

**Phase 2: User Testing**
1. User tests with real data on test endpoint
2. User validates functionality
3. User provides explicit approval: "Looks good, deploy to production"

**Phase 3: Deployment (PROD)**
```bash
# Step 1: Copy test workflow to production
cp workflows/XX-workflow-name/workflow-test.json \
   workflows/XX-workflow-name/workflow.json

# Step 2: Update webhook paths in production workflow
# Change /webhook-test/ to /webhook/ in workflow.json

# Step 3: Deploy to n8n via CLI
docker exec selene-n8n n8n import:workflow \
  --input=/workflows/workflows/XX-workflow-name/workflow.json

# Step 4: Activate workflow (via UI or database)
docker exec selene-n8n sqlite3 /home/node/.n8n/database.sqlite \
  "UPDATE workflow_entity SET active = 1 WHERE name = 'Workflow Name';"

# Step 5: Restart n8n
docker-compose restart n8n

# Step 6: Verify deployment
docker-compose logs n8n | grep "Activated workflow"
```

**Phase 4: Validation**
1. Test production endpoint with real data
2. Verify database records
3. Confirm all functionality working
4. Update status documents

#### File Structure

Each workflow should have both test and production versions:

```
workflows/XX-workflow-name/
├── workflow.json          # Production workflow (activated)
├── workflow-test.json     # Test workflow (for development)
├── docs/
│   ├── SETUP.md
│   ├── REFERENCE.md
│   └── [source]-action.js
└── README.md
```

#### When Test Doesn't Exist

If starting a new workflow or if test workflow doesn't exist:

```bash
# Create test workflow from production (if needed)
cp workflows/XX-workflow-name/workflow.json \
   workflows/XX-workflow-name/workflow-test.json
```

Then modify `workflow-test.json` to use test webhook paths.

#### Important Notes

- **NEVER modify production workflows directly** during development
- **ALWAYS get explicit user approval** before deploying to production
- **TEST thoroughly** before requesting approval
- **VERIFY** webhook paths are correct (test vs production)
- **DOCUMENT** all changes in commit messages and status files

#### Enforcement & Best Practices

**TodoWrite Pattern for Workflow Changes:**

Every workflow modification MUST start with a TodoWrite checklist:

```
- Check if workflow-test.json exists
- Make changes to workflow-test.json FIRST
- Test the changes thoroughly
- Wait for user approval ("deploy to production")
- Apply changes to workflow.json (only after approval)
```

**Enforcement Mechanisms:**

1. **Git Pre-Commit Hook** (`.git/hooks/pre-commit`)
   - Warns when modifying `workflow.json` files
   - Prompts for confirmation before allowing commit
   - References this documentation

2. **Slash Command** (`.claude/commands/edit-workflow.md`)
   - Use `/edit-workflow` to see the workflow modification protocol
   - Provides checklist and examples
   - Reminds of the test-first approach

3. **Protocol Documentation** (`.claude/WORKFLOW-PROTOCOL.md`)
   - Quick reference for the workflow modification rules
   - Links to this detailed documentation
   - Explains why the protocol matters

**Quick Check Before Modifying Workflows:**

```bash
# 1. Verify test file exists
ls workflows/[workflow-name]/workflow-test.json

# 2. If missing, create it (with user approval)
cp workflows/[workflow-name]/workflow.json \
   workflows/[workflow-name]/workflow-test.json

# 3. Make changes to TEST file only
# 4. Wait for user approval
# 5. Then update production file
```

### Workflow Deployment via CLI

**n8n provides a powerful CLI for deploying and managing workflows programmatically:**

#### Available Commands

```bash
# Import a workflow
docker exec selene-n8n n8n import:workflow --input=/path/to/workflow.json

# Import multiple workflows from a directory
docker exec selene-n8n n8n import:workflow --separate --input=/path/to/workflows/

# Export a workflow by ID
docker exec selene-n8n n8n export:workflow --id=WORKFLOW_ID --output=/path/output.json

# Export all workflows
docker exec selene-n8n n8n export:workflow --all --output=/path/to/export/

# Export all workflows (backup mode)
docker exec selene-n8n n8n export:workflow --backup --output=/backups/
```

#### Workflow Deployment Pattern

**Step 1: Prepare Workflow JSON**

Add required metadata to workflow.json:
```json
{
  "name": "Workflow Name",
  "active": true,
  "nodes": [ ... ],
  "connections": { ... }
}
```

**Step 2: Import via CLI**

```bash
# Import workflow (will be created as inactive initially)
docker exec selene-n8n n8n import:workflow \
  --input=/workflows/workflows/XX-workflow-name/workflow.json
```

**Step 3: Activate Workflow**

Option A - Via n8n UI:
1. Open http://localhost:5678
2. Find the imported workflow
3. Toggle "Active" switch

Option B - Via database + restart:
```bash
# Update database
docker exec selene-n8n sqlite3 /home/node/.n8n/database.sqlite \
  "UPDATE workflow_entity SET active = 1 WHERE name = 'Workflow Name';"

# Restart n8n to reload
docker-compose restart
```

**Step 4: Verify Deployment**

```bash
# Check n8n logs for activation
docker-compose logs n8n | grep "Activated workflow"

# Test webhook if applicable
curl -X POST http://localhost:5678/webhook/api/[path] \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

#### Important Notes

1. **Imported workflows are NOT automatically activated** - You must activate manually or update database
2. **Restarting n8n required** - After database updates, restart to reload workflow states
3. **Database location** - n8n internal DB is at `/home/node/.n8n/database.sqlite` inside container
4. **Data location** - Selene data DB is at `/selene/data/selene.db` inside container (mapped to `./data/selene.db` on host)

#### When to Use CLI vs UI

**Use CLI when:**
- Deploying multiple workflows at once
- Automating workflow deployment (CI/CD)
- Batch exporting for backups
- Scripting workflow updates
- Version control integration

**Use UI when:**
- Building/editing workflows visually
- Debugging workflow execution
- Viewing execution history
- Testing individual nodes
- First-time workflow creation

### Webhook Configuration

**Critical Issue:** n8n uses different paths for activated vs non-activated workflows!

- **Activated (Production):** `/webhook/[path]`
- **Not Activated (Testing):** `/webhook-test/[path]`

**Always document both paths prominently!**

### Workflow Node Structure

Follow this pattern for ingestion workflows:

```
1. Webhook Node (Receive)
   ↓
2. Function Node (Parse & Validate)
   ↓
3. Function Node (Check for Duplicates)
   ↓
4. IF Node (Is New?)
   ├─ True → Insert Node
   └─ False → Duplicate Response Node
   ↓
5. Build Response Node
```

### Database Operations

**Use SQLite Function Nodes:**

```javascript
const Database = require('better-sqlite3');

try {
  const db = new Database('/selene/data/selene.db');

  // Your database operations here

  db.close();
  return { json: result };

} catch (error) {
  console.error('Database Error:', error);
  throw new Error(`Operation failed: ${error.message}`);
}
```

**Always:**
- Close database connections
- Handle errors gracefully
- Return structured JSON
- Log errors for debugging

---

## Testing Standards

### Test Mode Implementation

Every integration must support test mode:

```javascript
// In CONFIG
testMode: true,
testMarker: "[integration-name]-test"

// In payload
if (CONFIG.testMode) {
  payload.test_run = CONFIG.testMarker;
}
```

### Test Data Cleanup

Provide a cleanup script or document cleanup SQL:

```bash
# Cleanup script pattern
./workflows/[workflow-name]/cleanup-tests.sh [test-marker]
```

```sql
-- Or SQL for manual cleanup
DELETE FROM raw_notes WHERE test_run = '[test-marker]';
```

### Testing Checklist

Document this checklist in every setup guide:

- [ ] Enable test mode
- [ ] Send test data
- [ ] Verify in database
- [ ] Check n8n workflow execution
- [ ] Verify response/feedback
- [ ] Clean up test data
- [ ] Disable test mode

---

## Documentation Standards

### File Naming
- Use UPPERCASE for main documentation files
- Use lowercase for scripts and code files
- Use hyphens for multi-word names
- Be descriptive and consistent

Examples:
- ✅ `DRAFTS-SETUP.md`
- ✅ `drafts-selene-action.js`
- ✅ `WEBHOOK-PATHS.md`
- ❌ `setup.md` (too generic)
- ❌ `drafts_action.js` (use hyphens)

### Markdown Standards

**Use callouts for important information:**
```markdown
> **IMPORTANT:** Critical information here
> - Bullet point
> - Another point
```

**Use emojis sparingly for status:**
- ✅ Complete/Working
- ❌ Error/Problem
- ⭐ Recommended
- ⚠️ Warning
- 🎉 Success/Celebration (rare)

**Code blocks must include language:**
````markdown
```javascript
// code here
```

```bash
# commands here
```

```json
{"data": "here"}
```
````

### Section Structure

Every documentation file should have:

1. **Title** - Clear, descriptive
2. **Table of Contents** - For files >100 lines
3. **Horizontal Rules** - Separate major sections with `---`
4. **Headers** - Use proper hierarchy (H1 → H2 → H3)
5. **Code Examples** - Always include working examples
6. **Commands** - Show both the command and expected output

---

## User Experience Standards

### Configuration Simplicity
- All configuration in ONE place (top of file)
- Clear comments for every option
- Sensible defaults
- Examples for common scenarios

### Error Messages
- Must be user-friendly
- Include troubleshooting steps
- Provide specific guidance
- Never just throw technical errors

**Good:**
```javascript
alert("Connection Failed",
  "Cannot reach n8n server. Check that:\n" +
  "1. n8n is running (docker-compose ps)\n" +
  "2. You're on the correct network\n" +
  "3. IP address is correct in CONFIG");
```

**Bad:**
```javascript
throw new Error("ECONNREFUSED");
```

### Success Feedback
- Show clear success messages
- Provide next steps
- Confirm what was accomplished

**Good:**
```javascript
app.displayInfoMessage("✓ Sent to Selene");
```

### Optional Features
- Comment out optional features by default
- Explain what they do
- Show exactly how to enable
- Group related optional features

---

## Integration Checklist

Use this checklist when building a new integration:

### Planning
- [ ] Understand the source system/app
- [ ] Identify data format and structure
- [ ] Determine authentication requirements
- [ ] Plan network/connectivity approach

### Implementation
- [ ] Create workflow in n8n
- [ ] Test workflow thoroughly
- [ ] Write JavaScript action/script (if applicable)
- [ ] Implement error handling
- [ ] Add test mode support
- [ ] Add optional features

### Documentation
- [ ] Write setup guide
- [ ] Write JavaScript action guide (if applicable)
- [ ] Write quick reference
- [ ] Create status document
- [ ] Update main project README (if applicable)

### Testing
- [ ] Test in each environment (local/network/VPN)
- [ ] Test error conditions
- [ ] Test with various data formats
- [ ] Verify database operations
- [ ] Test cleanup procedures
- [ ] Verify test mode

### Validation
- [ ] Get user confirmation it works
- [ ] Document any issues encountered
- [ ] Note any limitations
- [ ] Provide optimization suggestions

---

## Common Patterns

### Network Environment Detection

```javascript
function getBaseURL() {
  switch(CONFIG.network) {
    case "mac":
      return `http://localhost:${CONFIG.port}`;
    case "vpn":
      return `http://${CONFIG.vpnIP}:${CONFIG.port}`;
    case "local":
    default:
      return `http://${CONFIG.localIP}:${CONFIG.port}`;
  }
}
```

### Payload Building

```javascript
function buildPayload(data) {
  const payload = {
    title: data.title || "Untitled",
    content: data.content,
    created_at: data.timestamp || new Date().toISOString(),
    source_type: "[source-name]"
  };

  if (CONFIG.testMode) {
    payload.test_run = CONFIG.testMarker;
  }

  return payload;
}
```

### HTTP Request Pattern

```javascript
const http = HTTP.create();

const response = http.request({
  url: url,
  method: "POST",
  headers: {
    "Content-Type": "application/json"
  },
  data: payload
});

if (response.success) {
  // Handle success
} else {
  // Handle error with user-friendly message
}
```

---

## Database Schema Reference

### raw_notes Table
Primary table for ingested notes:

```sql
CREATE TABLE raw_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  source_type TEXT NOT NULL,
  word_count INTEGER,
  character_count INTEGER,
  tags TEXT,  -- JSON array
  created_at TEXT,
  imported_at TEXT DEFAULT CURRENT_TIMESTAMP,
  status TEXT DEFAULT 'pending',
  test_run TEXT,  -- For test mode cleanup
  metadata TEXT   -- JSON for source-specific data
);
```

### Expected Fields
Every ingestion should provide:
- `title` - Note title (required, use "Untitled" if missing)
- `content` - Note content (required)
- `content_hash` - For duplicate detection (generated)
- `source_type` - Source identifier (e.g., "drafts", "email")
- `word_count` - Calculated from content
- `character_count` - Calculated from content
- `tags` - JSON array of tags (extracted from content)
- `created_at` - ISO 8601 timestamp
- `test_run` - Test marker if in test mode (optional)

---

## Troubleshooting Template

Every integration guide must include this troubleshooting structure:

### Connection Issues
1. Check service is running
2. Verify network connectivity
3. Test with curl/browser
4. Check firewall settings

### Webhook/API Issues
1. Verify activation status (for n8n)
2. Check endpoint URL
3. Validate payload format
4. Review logs

### Data Issues
1. Check database accessibility
2. Verify data format
3. Test duplicate detection
4. Validate required fields

### Application-Specific Issues
1. App configuration
2. Permissions
3. Network access
4. Version compatibility

---

## Example: Building a New Integration

Let's say you're building an "Email" integration:

### Step 1: Plan
- Source: Email (via IMAP or webhook)
- Data: Subject, body, sender, date
- Authentication: Email account credentials or webhook token
- Network: Local n8n instance

### Step 2: Create Files
```
workflows/01-ingestion/
├── docs/
│   ├── EMAIL-SETUP.md
│   ├── EMAIL-REFERENCE.md
│   ├── email-status.md (after completion)
│   └── email-integration.js (if needed)
└── workflow.json (update or create)
```

### Step 3: Implement
1. Add webhook to n8n workflow
2. Add parsing function
3. Add database insertion
4. Test thoroughly

### Step 4: Document
1. Write setup guide with all sections
2. Create reference with test commands
3. Include troubleshooting
4. Add network configuration for all scenarios

### Step 5: Test
1. Enable test mode
2. Send test email
3. Verify in database
4. Test cleanup
5. Document results

### Step 6: Finalize
1. Create status document
2. Mark as complete
3. Provide next steps
4. Celebrate! 🎉

---

## Key Principles

1. **User-Friendly First** - Always prioritize user experience
2. **Document Everything** - If it's not documented, it doesn't exist
3. **Test Mode Always** - Every integration must support testing
4. **Handle Errors Gracefully** - Never show raw errors to users
5. **Be Consistent** - Follow established patterns
6. **Think About Networks** - Support multiple network scenarios
7. **Make Configuration Easy** - One place, clear options
8. **Provide Examples** - Working code examples for everything
9. **Plan for Cleanup** - Test data should be easy to remove
10. **Validate Thoroughly** - Test in all scenarios before marking complete

---

## Questions to Ask

When building a new integration, ask:

1. **What is the data source?**
2. **How will it connect?** (API, webhook, email, etc.)
3. **What authentication is needed?**
4. **What data fields are available?**
5. **What's the expected data format?**
6. **How should errors be handled?**
7. **What environments need support?** (local, network, VPN)
8. **How will users test this?**
9. **How will test data be cleaned up?**
10. **What optional features might be useful?**

---

## Success Criteria

An integration is complete when:

- ✅ Working in production environment
- ✅ Test mode implemented and verified
- ✅ All three documentation files created
- ✅ Error handling tested
- ✅ User has confirmed it works
- ✅ Status document written
- ✅ Cleanup procedure documented
- ✅ Optional features identified and documented

---

## Resources

### Testing Commands
```bash
# Check n8n is running
docker-compose ps

# View n8n logs
docker-compose logs n8n --tail=50

# Query database
sqlite3 data/selene.db "SELECT * FROM raw_notes LIMIT 5;"

# Test webhook
curl -X POST http://localhost:5678/webhook/api/[path] \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","content":"Testing"}'
```

### Common URLs
- n8n UI: `http://localhost:5678`
- Health check: `http://localhost:5678/healthz`
- Webhooks (activated): `http://localhost:5678/webhook/[path]`
- Webhooks (testing): `http://localhost:5678/webhook-test/[path]`

---

## Final Notes

These standards were established during the Drafts integration and represent a battle-tested approach. When in doubt:

1. Reference the Drafts integration files as examples
2. Follow the patterns established here
3. Ask clarifying questions before proceeding
4. Test thoroughly in all environments
5. Document everything clearly

**Remember:** The goal is to create integrations that are easy to use, well-documented, and maintainable. Quality over speed!
