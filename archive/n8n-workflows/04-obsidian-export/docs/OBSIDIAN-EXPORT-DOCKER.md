# Docker Compose Configuration for Obsidian Export

## ✅ Yes, Docker Compose is Properly Configured!

The docker-compose.yml is **already set up** to allow n8n to read/write files to your Obsidian vault.

## How It Works

### Volume Mount (docker-compose.yml:75-76)

```yaml
volumes:
  # Mount Obsidian vault (read/write access)
  - ${OBSIDIAN_VAULT_PATH:-./vault}:/obsidian:rw
```

**What this means:**
- **Host side:** `${OBSIDIAN_VAULT_PATH:-./vault}`
  - Uses environment variable `OBSIDIAN_VAULT_PATH` from `.env`
  - Falls back to `./vault` if not set

- **Container side:** `/obsidian`
  - Inside the n8n container, vault is accessible at `/obsidian`

- **Permissions:** `:rw` (read-write)
  - n8n can create, read, update, and delete files

### Environment Variable (docker-compose.yml:64)

```yaml
environment:
  - OBSIDIAN_VAULT_PATH=/obsidian
```

**What this means:**
- Workflows can access `process.env.OBSIDIAN_VAULT_PATH`
- Value inside container: `/obsidian`
- This is the mounted vault location

## Configuration Options

### Option 1: Use Local Vault (Default)

Creates vault in project directory:

**.env:**
```bash
OBSIDIAN_VAULT_PATH=./vault
```

**Result:**
- Host: `./vault/` (in project directory)
- Container: `/obsidian/`
- Good for: Testing, standalone setup

**Create structure:**
```bash
mkdir -p vault/Selene/{Timeline,By-Concept,By-Theme,By-Energy,Concepts}
```

### Option 2: Use Existing Obsidian Vault

Points to your actual Obsidian vault:

**.env:**
```bash
OBSIDIAN_VAULT_PATH=/Users/yourusername/Documents/ObsidianVault
```

**Result:**
- Host: Your real Obsidian vault
- Container: `/obsidian/` (mounted)
- Good for: Production use, immediate access in Obsidian

**Create Selene folder:**
```bash
mkdir -p /Users/yourusername/Documents/ObsidianVault/Selene/{Timeline,By-Concept,By-Theme,By-Energy,Concepts}
```

### Option 3: Separate Vault, Manual Sync

Use local vault, manually sync to Obsidian:

**.env:**
```bash
OBSIDIAN_VAULT_PATH=./vault
```

**Then sync periodically:**
```bash
# Copy to your Obsidian vault
rsync -av ./vault/Selene/ /Users/yourusername/Documents/ObsidianVault/Selene/
```

## How Workflows Access the Vault

### Inside n8n Workflows

The ADHD-optimized workflow uses:

```javascript
const vaultPath = process.env.OBSIDIAN_VAULT_PATH || '/vault';
```

**Path resolution:**
1. Checks environment variable (set by docker-compose)
2. Gets `/obsidian` (the mounted vault)
3. Falls back to `/vault` if env var missing

**File creation example:**
```javascript
// Workflow creates:
const filePath = `/obsidian/Selene/By-Concept/Docker/2025-10-30-note.md`;

// Which maps to host:
// ./vault/Selene/By-Concept/Docker/2025-10-30-note.md
// or
// /Users/you/Documents/ObsidianVault/Selene/By-Concept/Docker/2025-10-30-note.md
```

## Verification

### Check Current Configuration

```bash
# Check what's in your .env
grep OBSIDIAN_VAULT_PATH .env

# Check if vault directory exists
ls -la vault/

# Check if mounted in container
docker exec selene-n8n ls -la /obsidian
```

### Test Write Access

```bash
# Test n8n can write to vault
docker exec selene-n8n sh -c "echo 'test' > /obsidian/test.txt"

# Verify on host
cat vault/test.txt
# or
cat /Users/yourusername/Documents/ObsidianVault/test.txt

# Clean up
rm vault/test.txt
```

## Common Issues

### Problem: "Permission denied" when writing files

**Cause:** User/group mismatch between host and container

**Fix:**
```bash
# Option 1: Fix ownership (macOS/Linux)
sudo chown -R $(id -u):$(id -g) vault/

# Option 2: Open permissions (less secure but works)
chmod -R 755 vault/
```

### Problem: "Directory not found" errors

**Cause:** Vault structure not created

**Fix:**
```bash
# Create required directories
mkdir -p vault/Selene/{Timeline,By-Concept,By-Theme,By-Energy/{high,medium,low},Concepts,Themes}

# Verify
ls -la vault/Selene/
```

### Problem: "Path /obsidian does not exist" in container

**Cause:** Volume not mounted (docker-compose issue)

**Fix:**
```bash
# Recreate containers with proper volumes
docker-compose down
docker-compose up -d --build

# Verify mount
docker exec selene-n8n ls -la /obsidian
```

### Problem: Files appear in container but not on host

**Cause:** Wrong volume path in docker-compose

**Fix:**
```bash
# Check actual mount
docker inspect selene-n8n | grep -A5 Mounts

# Should show:
# "Source": "/Users/you/path/to/vault"
# "Destination": "/obsidian"
```

## Using Different Vault Locations Per Workflow

If you want different workflows to export to different vaults:

### Method 1: Edit Workflow Directly

In the workflow function node, hardcode path:

```javascript
// Override environment variable
const vaultPath = '/obsidian/AlternateVault';
```

### Method 2: Multiple Volume Mounts

Edit docker-compose.yml:

```yaml
volumes:
  - ./vault:/obsidian:rw
  - ./vault-work:/obsidian-work:rw
  - ./vault-personal:/obsidian-personal:rw
```

Then in workflows:
```javascript
const vaultPath = '/obsidian-work';  // or /obsidian-personal
```

## Obsidian Integration

### Open Vault in Obsidian

If using local vault:

1. Open Obsidian
2. "Open folder as vault"
3. Select: `./vault` (in project directory)
4. Selene notes will be in `Selene/` folder

If using existing vault:

1. Notes automatically appear in your vault
2. Navigate to `Selene/` folder
3. Use Dataview queries from README-ADHD.md

### Obsidian Sync Considerations

**If using Obsidian Sync:**
- Add `Selene/` folder to sync settings
- Notes will sync across devices
- Be aware of sync conflicts if exporting frequently

**If using iCloud/Dropbox vault:**
- Works automatically
- Cloud service syncs the files
- No additional configuration needed

## Performance Notes

### File System Performance

**Local vault (./vault):**
- ✅ Fastest (no network overhead)
- ✅ Good for Docker volume mounts
- ❌ Requires manual sync to Obsidian vault

**Direct Obsidian vault mount:**
- ⚠️ Slightly slower (depends on location)
- ✅ Immediate availability in Obsidian
- ⚠️ Watch for sync conflicts

**Network mount (NAS, etc.):**
- ❌ Slower (network latency)
- ⚠️ May timeout on large exports
- Not recommended unless necessary

### Recommended Setup

**For development/testing:**
```bash
OBSIDIAN_VAULT_PATH=./vault
```

**For production use:**
```bash
OBSIDIAN_VAULT_PATH=/Users/you/Documents/ObsidianVault
```

## Summary

### ✅ What's Already Working

1. **Volume mount configured** in docker-compose.yml
2. **Read-write permissions** enabled (`:rw`)
3. **Environment variable** set for workflows
4. **Vault path accessible** inside container at `/obsidian`

### ✅ What You Can Do

1. **Create files** from n8n workflows
2. **Organize in multiple folders** (Timeline, By-Concept, etc.)
3. **Use either local or real Obsidian vault**
4. **Access immediately** in Obsidian

### 🎯 Next Steps

1. **Set vault path** in `.env` (if not using default)
2. **Create directory structure** (see SETUP-GUIDE.md)
3. **Import ADHD workflow** and activate
4. **Test export** with curl command
5. **Open in Obsidian** and verify files

---

**Your docker-compose is ready for Obsidian export! 🚀**

No additional docker configuration needed. Just follow the SETUP-GUIDE.md to start exporting.
