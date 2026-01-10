# Ollama Setup for Selene

## Overview

Ollama is a local LLM runtime that allows you to run AI models on your own hardware without sending data to external services. The Selene LLM processing workflow uses Ollama to extract concepts and detect themes in your notes.

**Why Ollama?**
- ✅ **Privacy:** All processing happens locally on your machine
- ✅ **Cost:** No API fees or usage limits
- ✅ **Speed:** Fast inference with optimized models
- ✅ **Offline:** Works without internet connection
- ✅ **Customizable:** Choose your own models and parameters

---

## Installation

### macOS

**Option 1: Homebrew (Recommended)**

```bash
brew install ollama
```

**Option 2: Direct Download**

1. Download from https://ollama.ai/download
2. Open the downloaded DMG file
3. Drag Ollama to Applications folder
4. Open Ollama from Applications

**Verify Installation:**

```bash
ollama --version
```

Expected output: `ollama version is 0.x.x`

### Linux

```bash
# Download and install
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
sudo systemctl start ollama
sudo systemctl enable ollama  # Start on boot
```

**Verify Installation:**

```bash
ollama --version
systemctl status ollama
```

### Windows

Currently, Ollama requires WSL2 (Windows Subsystem for Linux):

```bash
# In WSL2 terminal
curl -fsSL https://ollama.ai/install.sh | sh
```

Follow Linux instructions above within WSL2.

---

## Starting Ollama

### macOS

Ollama typically starts automatically after installation.

**Manual Start:**

```bash
# Start Ollama in the foreground
ollama serve

# Or start as background service (macOS)
brew services start ollama
```

**Check if Running:**

```bash
ps aux | grep ollama
# Or
curl http://localhost:11434/api/tags
```

### Linux

```bash
# Start service
sudo systemctl start ollama

# Check status
sudo systemctl status ollama

# View logs
journalctl -u ollama -f
```

### Verify Ollama is Accessible

```bash
# Health check
curl http://localhost:11434/api/tags

# Expected response: {"models": [...]}
```

---

## Downloading Models

### Recommended Model: Mistral 7B

**Best balance of speed and accuracy for Selene**

```bash
ollama pull mistral:7b
```

**Size:** ~4.1 GB
**RAM Required:** 8 GB minimum, 16 GB recommended
**Speed:** 5-10 seconds per note (on M1/M2 Mac or modern Intel/AMD)

### Alternative Models

#### Faster (Good for Testing)

```bash
# Llama 3.2 3B - Faster, slightly less accurate
ollama pull llama3.2:3b
```

**Size:** ~2.0 GB
**RAM Required:** 4 GB minimum
**Speed:** 2-5 seconds per note
**Best for:** High-volume processing, testing, resource-constrained systems

#### More Accurate (Slower)

```bash
# Llama 3.1 8B - Larger, more accurate
ollama pull llama3.1:8b
```

**Size:** ~4.7 GB
**RAM Required:** 16 GB recommended
**Speed:** 10-20 seconds per note
**Best for:** Critical accuracy, detailed analysis

```bash
# Qwen 2.5 14B - Very accurate (if you have the resources)
ollama pull qwen2.5:14b
```

**Size:** ~9.0 GB
**RAM Required:** 32 GB recommended
**Speed:** 20-40 seconds per note
**Best for:** Maximum accuracy, powerful hardware

### List Downloaded Models

```bash
ollama list
```

Expected output:
```
NAME              ID            SIZE    MODIFIED
mistral:7b        abc123...     4.1 GB  2 days ago
llama3.2:3b       def456...     2.0 GB  1 week ago
```

### Delete a Model

```bash
ollama rm llama3.2:3b
```

---

## Testing Ollama

### Basic Test

```bash
ollama run mistral:7b "What is Docker?"
```

Expected: Should return a coherent explanation of Docker.

### Interactive Mode

```bash
ollama run mistral:7b
```

Then type questions interactively. Type `/bye` to exit.

### API Test (for n8n Integration)

```bash
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral:7b",
    "prompt": "List 3 key concepts from this text: Docker is a containerization platform that helps developers build and deploy applications efficiently.",
    "stream": false,
    "options": {
      "temperature": 0.3,
      "num_predict": 500
    }
  }'
```

Expected: JSON response with extracted concepts.

---

## Configuration for Selene

### Default Configuration (macOS)

The Selene workflow is pre-configured for macOS with these settings:

- **URL:** `http://host.docker.internal:11434`
- **Model:** `mistral:7b`
- **Temperature:** `0.3`
- **Timeout:** `60 seconds`

**No changes needed if using defaults!**

### Linux Configuration

On Linux, update the Ollama URL in the workflow:

**From:** `http://host.docker.internal:11434`
**To:** `http://172.17.0.1:11434` (or your Docker bridge IP)

**Find your Docker bridge IP:**

```bash
ip addr show docker0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1
```

**Update workflow nodes:**
1. Open workflow in n8n
2. Edit "Ollama: Extract Concepts" node
3. Change URL to `http://172.17.0.1:11434/api/generate`
4. Edit "Ollama: Detect Themes" node
5. Change URL to `http://172.17.0.1:11434/api/generate`
6. Save workflow

### Custom Model Configuration

To use a different model:

1. **Pull the model:**
   ```bash
   ollama pull llama3.1:8b
   ```

2. **Update workflow nodes:**
   - Open workflow in n8n
   - Edit "Ollama: Extract Concepts" node
   - Change `model` parameter from `mistral:7b` to `llama3.1:8b`
   - Edit "Ollama: Detect Themes" node
   - Change `model` parameter to `llama3.1:8b`
   - Save workflow

---

## Docker Integration

### Accessing Ollama from n8n Container

The n8n Docker container needs to access Ollama running on your host machine.

**macOS/Windows (Docker Desktop):**

Uses `host.docker.internal` (already configured in docker-compose.yml):

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

**Test from inside container:**

```bash
docker exec -it selene-n8n sh -c "wget -qO- http://host.docker.internal:11434/api/tags"
```

Expected: JSON response with model list.

**Linux:**

On Linux, `host.docker.internal` is not available by default. Use:

1. **Docker bridge IP (recommended):**
   ```
   http://172.17.0.1:11434
   ```

2. **Or add to docker-compose.yml:**
   ```yaml
   extra_hosts:
     - "host.docker.internal:172.17.0.1"
   ```

### Firewall Configuration

If Ollama is not accessible from Docker:

**macOS:**
- System Settings > Network > Firewall
- Allow incoming connections for "ollama"

**Linux (ufw):**

```bash
sudo ufw allow 11434/tcp
sudo ufw reload
```

**Linux (firewalld):**

```bash
sudo firewall-cmd --add-port=11434/tcp --permanent
sudo firewall-cmd --reload
```

---

## Performance Tuning

### System Requirements

**Minimum:**
- 8 GB RAM
- 4 CPU cores
- 10 GB free disk space

**Recommended:**
- 16 GB RAM
- 8 CPU cores
- 20 GB free disk space
- Apple Silicon (M1/M2/M3) or modern GPU

### GPU Acceleration

**Ollama automatically uses GPU if available:**

- **macOS:** Uses Metal (Apple Silicon)
- **Linux:** Uses CUDA (NVIDIA) or ROCm (AMD)
- **Windows:** Uses CUDA (NVIDIA) in WSL2

**Check GPU usage:**

```bash
# macOS
top -stats pid,command,cpu,gpu
# Look for ollama process

# Linux with NVIDIA
nvidia-smi
```

### Memory Management

**Control model memory usage:**

```bash
# Set maximum GPU memory (example: 4GB)
export OLLAMA_GPU_MEMORY=4096

# Restart Ollama
brew services restart ollama  # macOS
sudo systemctl restart ollama  # Linux
```

### Concurrent Requests

**Ollama can handle multiple requests:**

```bash
# Set maximum parallel requests (default: 4)
export OLLAMA_MAX_PARALLEL=2

# Restart Ollama
brew services restart ollama
```

Lower value = more memory per request (better quality)
Higher value = more throughput (faster overall)

For Selene, `OLLAMA_MAX_PARALLEL=1` is recommended for consistent quality.

---

## Troubleshooting

### Error: "Connection Refused"

**Symptoms:**
```
curl: (7) Failed to connect to localhost port 11434: Connection refused
```

**Solutions:**

1. **Check if Ollama is running:**
   ```bash
   ps aux | grep ollama
   ```

2. **Start Ollama:**
   ```bash
   # macOS
   ollama serve

   # Linux
   sudo systemctl start ollama
   ```

3. **Check port binding:**
   ```bash
   lsof -i :11434
   ```

   Should show: `ollama` listening on port 11434

### Error: "Model Not Found"

**Symptoms:**
```json
{"error": "model 'mistral:7b' not found"}
```

**Solution:**

```bash
# Pull the model
ollama pull mistral:7b

# Verify it's available
ollama list
```

### Error: "Out of Memory"

**Symptoms:**
- Ollama crashes or hangs
- System becomes unresponsive
- Error: "not enough memory"

**Solutions:**

1. **Use a smaller model:**
   ```bash
   ollama pull llama3.2:3b
   ```

2. **Close other applications** to free up RAM

3. **Reduce concurrent requests:**
   ```bash
   export OLLAMA_MAX_PARALLEL=1
   ```

4. **Add swap space** (Linux):
   ```bash
   sudo fallocate -l 8G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

### Error: "Timeout"

**Symptoms:**
- n8n workflow fails with timeout error
- Ollama takes >60 seconds to respond

**Solutions:**

1. **Use faster model:**
   ```bash
   ollama pull llama3.2:3b
   ```

2. **Reduce token generation:**
   - In workflow, reduce `num_predict` from 2000 to 500

3. **Increase timeout in workflow:**
   - Edit HTTP Request nodes
   - Change timeout from 60000ms to 120000ms (2 minutes)

4. **Check system load:**
   ```bash
   top  # Check CPU usage
   ```

### Slow Performance

**Symptoms:**
- Each note takes 30+ seconds
- System feels sluggish

**Solutions:**

1. **Check GPU usage:**
   ```bash
   # Ensure GPU acceleration is working
   ollama run mistral:7b "test" --verbose
   ```

2. **Reduce model size:**
   ```bash
   ollama pull llama3.2:3b
   ```

3. **Lower temperature and tokens:**
   ```json
   "options": {
     "temperature": 0.2,
     "num_predict": 300
   }
   ```

4. **Restart Ollama:**
   ```bash
   # macOS
   brew services restart ollama

   # Linux
   sudo systemctl restart ollama
   ```

### Docker Cannot Reach Ollama

**Symptoms:**
- Workflow fails with "connection refused"
- curl from inside container fails

**Solutions:**

1. **Test from inside container:**
   ```bash
   docker exec -it selene-n8n sh -c "curl http://host.docker.internal:11434/api/tags"
   ```

2. **Check extra_hosts configuration:**
   ```bash
   docker inspect selene-n8n | grep -A5 ExtraHosts
   ```

3. **Verify Ollama is listening on all interfaces:**
   ```bash
   lsof -i :11434
   # Should show: *:11434 (LISTEN)
   ```

4. **Linux: Use Docker bridge IP:**
   ```bash
   # Get bridge IP
   ip addr show docker0

   # Test with bridge IP
   docker exec -it selene-n8n sh -c "curl http://172.17.0.1:11434/api/tags"
   ```

---

## Advanced Configuration

### Custom Model Parameters

Create a custom Modelfile for fine-tuned behavior:

```bash
# Create Modelfile
cat > Modelfile << 'EOF'
FROM mistral:7b

# Set parameters
PARAMETER temperature 0.2
PARAMETER num_predict 1000
PARAMETER top_p 0.9
PARAMETER top_k 40

# Custom system prompt
SYSTEM You are a concept extraction specialist focused on identifying key topics and themes from text.
EOF

# Create custom model
ollama create selene-concepts -f Modelfile

# Use in workflow by changing model to "selene-concepts"
```

### Environment Variables

```bash
# Set in ~/.zshrc or ~/.bashrc (macOS) or /etc/systemd/system/ollama.service (Linux)

# Model storage location
export OLLAMA_MODELS=/path/to/models

# Host and port
export OLLAMA_HOST=0.0.0.0:11434

# GPU memory limit (MB)
export OLLAMA_GPU_MEMORY=4096

# Max parallel requests
export OLLAMA_MAX_PARALLEL=1

# Debug logging
export OLLAMA_DEBUG=1
```

**Apply changes:**

```bash
# macOS
brew services restart ollama

# Linux
sudo systemctl restart ollama
```

### Multi-User Setup

If multiple users need access to Ollama:

```bash
# Bind to all interfaces (default: localhost only)
export OLLAMA_HOST=0.0.0.0:11434

# Start Ollama
ollama serve
```

**Security Warning:** This makes Ollama accessible on your network. Use firewall rules to restrict access.

---

## Model Comparison for Selene

| Model | Size | RAM | Speed | Concept Accuracy | Theme Accuracy | Best For |
|-------|------|-----|-------|------------------|----------------|----------|
| llama3.2:3b | 2.0 GB | 4 GB | ⚡⚡⚡ Fast | Good (75-85%) | Good (80-90%) | Testing, high-volume |
| mistral:7b | 4.1 GB | 8 GB | ⚡⚡ Medium | Excellent (85-95%) | Excellent (90-95%) | **Recommended** |
| llama3.1:8b | 4.7 GB | 16 GB | ⚡ Slow | Excellent (90-98%) | Excellent (92-98%) | Accuracy-critical |
| qwen2.5:14b | 9.0 GB | 32 GB | 🐌 Very slow | Superior (95-99%) | Superior (95-99%) | Maximum accuracy |

**Recommendation:** Start with `mistral:7b` for best balance.

---

## Monitoring

### Check Ollama Logs

**macOS:**
```bash
log show --predicate 'process == "ollama"' --last 1h
```

**Linux:**
```bash
journalctl -u ollama -f
```

### Monitor Resource Usage

```bash
# CPU and Memory
top | grep ollama

# GPU (macOS)
sudo powermetrics --samplers gpu_power -i 1000 -n 1

# GPU (Linux with NVIDIA)
nvidia-smi -l 1
```

### Check Model Performance

```bash
# Test inference speed
time ollama run mistral:7b "Extract concepts: Docker is a containerization platform."

# Should complete in 2-10 seconds for mistral:7b
```

---

## Updating Ollama

### macOS

```bash
# Update via Homebrew
brew update
brew upgrade ollama

# Restart service
brew services restart ollama
```

### Linux

```bash
# Re-run install script (will update)
curl -fsSL https://ollama.ai/install.sh | sh

# Restart service
sudo systemctl restart ollama
```

---

## Uninstalling (if needed)

### macOS

```bash
# If installed via Homebrew
brew uninstall ollama

# Remove models and data
rm -rf ~/.ollama
```

### Linux

```bash
# Stop service
sudo systemctl stop ollama
sudo systemctl disable ollama

# Remove Ollama
sudo rm $(which ollama)

# Remove models and data
sudo rm -rf /usr/share/ollama
rm -rf ~/.ollama
```

---

## Resources

- **Official Website:** https://ollama.ai
- **Documentation:** https://ollama.ai/docs
- **Model Library:** https://ollama.ai/library
- **GitHub:** https://github.com/ollama/ollama
- **Discord Community:** https://discord.gg/ollama

---

## Next Steps

After setting up Ollama:

1. **Test basic functionality:**
   ```bash
   ollama run mistral:7b "Hello!"
   ```

2. **Test API access:**
   ```bash
   curl http://localhost:11434/api/tags
   ```

3. **Test from Docker:**
   ```bash
   docker exec -it selene-n8n sh -c "wget -qO- http://host.docker.internal:11434/api/tags"
   ```

4. **Return to LLM-PROCESSING-SETUP.md** to complete workflow setup

5. **Activate the LLM processing workflow** in n8n and process your first note!
