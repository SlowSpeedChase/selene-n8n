# SeleneChat Remote Access Setup

This guide explains how to set up SeleneChat to work remotely, allowing you to access your notes from your laptop while the server runs on your Mac mini.

## Architecture

```
┌─────────────────┐                    ┌─────────────────┐
│    Laptop       │                    │    Mac Mini     │
│  (SeleneChat)   │◄──── WiFi/LAN ────►│   (Server)      │
│                 │                    │                 │
│ - Remote mode   │                    │ - Fastify API   │
│ - Ollama proxy  │                    │ - SQLite DB     │
│                 │                    │ - Ollama        │
└─────────────────┘                    └─────────────────┘
```

## Mac Mini (Server) Setup

### 1. Configure Ollama for Network Access

Update the Ollama launchd agent to listen on all interfaces:

```bash
# Install the updated launchd agents
./scripts/install-launchd.sh
```

This installs `com.selene.ollama.plist` which sets `OLLAMA_HOST=0.0.0.0:11434`.

### 2. Start the Selene Server

The server automatically binds to all interfaces (0.0.0.0:5678).

```bash
# Using launchd (recommended)
launchctl load ~/Library/LaunchAgents/com.selene.server.plist

# Or manually
npm run start
```

### 3. Build the App Bundle

```bash
./scripts/build-selenechat-release.sh
```

This creates `build/SeleneChat.app` which will be served to clients.

### 4. Note Your IP Address

```bash
# Find your Mac mini's IP address
ifconfig | grep "inet " | grep -v 127.0.0.1
```

Example: `192.168.1.100`

## Laptop (Client) Setup

### 1. Create Client Directory

```bash
mkdir -p ~/selene-client
```

### 2. Copy the Update Script

Copy `scripts/update-selenechat.sh` to your laptop:

```bash
# On Mac mini
scp scripts/update-selenechat.sh your-laptop:~/selene-client/
```

Or copy manually and edit `SERVER_ADDRESS` in the script.

### 3. Configure Server Address

Edit `~/selene-client/update-selenechat.sh`:

```bash
SERVER_ADDRESS="192.168.1.100"  # Your Mac mini's IP
```

### 4. Install SeleneChat

Run the update script to download and install:

```bash
cd ~/selene-client
./update-selenechat.sh
```

### 5. Set Up Auto-Updates (Optional)

Copy the launchd agent for automatic updates:

```bash
# Edit the plist to set your server address
nano ~/Library/LaunchAgents/com.selene.update-check.plist

# Load the agent
launchctl load ~/Library/LaunchAgents/com.selene.update-check.plist
```

The agent checks for updates:
- Every 6 hours
- At 9am daily
- Shortly after login

## Using SeleneChat in Remote Mode

### 1. Open Settings

Launch SeleneChat and open Settings (⌘+,).

### 2. Configure Connection Mode

1. Select "Remote Server" in the Connection Mode section
2. Enter your Mac mini's IP address (e.g., `192.168.1.100`)
3. Click "Test" to verify the connection

### 3. Verify Connection

The sidebar shows a connection status indicator:
- 🟢 Green dot = Connected
- 🟡 Orange dot = Connecting/checking
- 🔴 Red dot = Disconnected

## API Endpoints

The server exposes these endpoints for SeleneChat:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Server health check |
| `/api/notes` | GET | List notes |
| `/api/notes/search` | GET | Search notes |
| `/api/sessions` | GET/POST | Manage chat sessions |
| `/api/threads` | GET/PATCH | Manage discussion threads |
| `/api/app/version` | GET | Get app version info |
| `/api/app/download` | GET | Download app bundle |

## Troubleshooting

### Can't Connect to Server

1. **Check Mac mini is on the same network**
   ```bash
   ping 192.168.1.100  # Replace with your Mac mini's IP
   ```

2. **Check server is running**
   ```bash
   curl http://192.168.1.100:5678/health
   ```

3. **Check firewall**
   - System Settings → Network → Firewall
   - Ensure Node.js and Ollama are allowed

### Ollama Not Responding

1. **Check Ollama is listening on all interfaces**
   ```bash
   # On Mac mini
   lsof -i :11434
   ```

2. **Restart Ollama**
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.selene.ollama
   ```

### App Updates Not Working

1. **Check update script logs**
   ```bash
   cat /tmp/selenechat-update.log
   ```

2. **Force update**
   ```bash
   ./update-selenechat.sh --force
   ```

## Security Considerations

- The server binds to all interfaces (0.0.0.0), so it's accessible on your local network
- Consider using your router's firewall to restrict access
- The app transport security is configured to allow local networking
- No authentication is required for the API (trusted home network)

For enhanced security:
1. Use a dedicated VLAN for your devices
2. Set up WireGuard or similar VPN for remote access
3. Consider adding API key authentication

## File Locations

### Mac Mini (Server)

| Path | Description |
|------|-------------|
| `~/selene-n8n/` | Main project directory |
| `~/selene-n8n/data/selene.db` | SQLite database |
| `~/selene-n8n/build/SeleneChat.app` | Built app bundle |
| `~/Library/LaunchAgents/com.selene.*.plist` | Launchd agents |

### Laptop (Client)

| Path | Description |
|------|-------------|
| `~/selene-client/` | Client scripts |
| `/Applications/SeleneChat.app` | Installed app |
| `/tmp/selenechat-update.log` | Update logs |
| `~/Library/LaunchAgents/com.selene.update-check.plist` | Auto-update agent |
