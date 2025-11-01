# Selene Knowledge Management System - Documentation

**Version:** 1.0.0
**Last Updated:** October 29, 2025
**Author:** Chase Easterling

Welcome to the complete documentation for the Selene Knowledge Management System - an n8n-based note processing pipeline with LLM integration for ADHD-friendly knowledge organization.

---

## 📚 Documentation Index

### Getting Started

- **[Quick Start Guide](guides/quickstart.md)** - Get up and running in 15 minutes
- **[Setup Guide](guides/setup.md)** - Complete installation and configuration
- **[Package Requirements](guides/packages.md)** - All dependencies and installation

### Architecture

- **[System Architecture](architecture/overview.md)** - High-level system design
- **[Database Schema](architecture/database.md)** - SQLite table structures
- **[Migration Roadmap](architecture/roadmap.md)** - Python to n8n migration guide
- **[Design Decisions](architecture/decisions.md)** - Why we built it this way

### Workflows

- **[Workflow Overview](workflows/overview.md)** - All 6 workflows explained
- **[01: Ingestion](workflows/01-ingestion.md)** - Note intake from Drafts app
- **[02: LLM Processing](workflows/02-llm-processing.md)** - Concept & theme extraction
- **[03: Pattern Detection](workflows/03-pattern-detection.md)** - Theme trend analysis
- **[04: Obsidian Export](workflows/04-obsidian-export.md)** - Markdown vault export
- **[05: Sentiment Analysis](workflows/05-sentiment-analysis.md)** - Emotional tone detection
- **[06: Connection Network](workflows/06-connection-network.md)** - Note relationship mapping

### API & Integration

- **[Webhook API](api/webhooks.md)** - Sending notes to Selene
- **[Drafts Integration](api/drafts.md)** - iOS/Mac app integration
- **[Ollama Configuration](api/ollama.md)** - LLM model setup
- **[Obsidian Integration](api/obsidian.md)** - Vault configuration

### Troubleshooting

- **[Common Issues](troubleshooting/common-issues.md)** - Solutions to frequent problems
- **[Docker Issues](troubleshooting/docker.md)** - Container and networking problems
- **[Database Issues](troubleshooting/database.md)** - SQLite errors and fixes
- **[Workflow Debugging](troubleshooting/workflows.md)** - n8n workflow errors
- **[FAQ](troubleshooting/faq.md)** - Frequently asked questions

---

## 🎯 Project Overview

Selene is a personal knowledge management system designed specifically for ADHD minds. It automatically processes your notes using local AI (Ollama) to:

- Extract key concepts and themes
- Detect patterns in your thinking over time
- Analyze sentiment and emotional tone
- Discover connections between ideas
- Export everything to Obsidian for visual exploration

**Key Features:**

- ✅ **Visual Workflows** - See your entire note processing pipeline
- ✅ **Local AI** - All processing happens on your machine with Ollama
- ✅ **Privacy First** - Your notes never leave your computer
- ✅ **ADHD-Friendly** - Automatic organization, no manual tagging required
- ✅ **Obsidian Integration** - Export to your existing knowledge vault
- ✅ **Mobile Capture** - Send notes from Drafts app on iOS

---

## 🚀 Quick Start

If you're new to Selene, start here:

1. **[Prerequisites](guides/setup.md#prerequisites)** - Install Docker and Ollama
2. **[Installation](guides/setup.md#installation-steps)** - Set up the environment
3. **[First Note](guides/quickstart.md#sending-your-first-note)** - Test the system
4. **[Import Workflows](guides/setup.md#step-7-import-workflows)** - Load all 6 workflows
5. **[Configure Drafts](api/drafts.md)** - Connect your iOS/Mac app

**Total setup time:** ~15-30 minutes

---

## 🏗️ System Architecture

```
┌─────────────┐
│  Drafts App │ (iOS/Mac)
└──────┬──────┘
       │ HTTP POST
       ▼
┌─────────────────────────────────────────┐
│           n8n Workflows                 │
│  ┌──────────────────────────────────┐  │
│  │ 01: Ingestion → Database         │  │
│  │ 02: LLM Processing → Concepts    │  │
│  │ 03: Pattern Detection → Trends   │  │
│  │ 04: Obsidian Export → Markdown   │  │
│  │ 05: Sentiment → Emotional Tone   │  │
│  │ 06: Network → Connections        │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
       │                    │
       ▼                    ▼
┌─────────────┐      ┌──────────────┐
│  SQLite DB  │      │ Ollama (LLM) │
└─────────────┘      └──────────────┘
       │
       ▼
┌─────────────┐
│  Obsidian   │
│    Vault    │
└─────────────┘
```

**See:** [Detailed Architecture](architecture/overview.md)

---

## 📦 Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Workflow Engine** | n8n | Visual automation and orchestration |
| **Database** | SQLite | Note storage and query |
| **LLM Processing** | Ollama (Mistral 7B) | Concept extraction, sentiment analysis |
| **Container** | Docker | Isolated environment with all dependencies |
| **Knowledge Vault** | Obsidian | Visual note exploration and linking |
| **Mobile Capture** | Drafts | iOS/Mac quick note entry |

**See:** [Package Documentation](guides/packages.md)

---

## 📊 Database Schema

Selene uses 8 main tables:

1. **raw_notes** - Incoming notes from Drafts
2. **processed_notes** - LLM analysis results
3. **sentiment_history** - Emotional tone tracking
4. **detected_patterns** - Theme trends over time
5. **pattern_reports** - Daily pattern analysis summaries
6. **network_analysis_history** - Note connection data
7. **note_connections** - Relationship mappings (future)
8. **test_table** - Development/testing (can be ignored)

**See:** [Database Schema Details](architecture/database.md)

---

## 🔄 Workflow Pipeline

### Real-Time Processing

1. **Note arrives** via webhook from Drafts
2. **Duplicate check** against content hash
3. **Store in raw_notes** with pending status
4. **LLM processing** (every 30 seconds)
   - Extract 3-5 key concepts
   - Identify primary & secondary themes
   - Mark as processed
5. **Sentiment analysis** (every 45 seconds)
   - Detect emotional tone
   - Identify ADHD markers
   - Track energy levels

### Scheduled Processing

- **Daily @ 6am**: Pattern detection across theme trends
- **Daily @ 7am**: Export processed notes to Obsidian
- **Every 6 hours**: Calculate note connection networks

**See:** [Workflow Details](workflows/overview.md)

---

## 🔧 Configuration

### Environment Variables

Key settings in `.env`:

```bash
# Authentication
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_secure_password

# Timezone
TIMEZONE=America/Chicago

# Paths
SELENE_DATA_PATH=./data
OBSIDIAN_VAULT_PATH=./vault

# AI Model
OLLAMA_MODEL=mistral:7b
```

**See:** [Configuration Guide](guides/setup.md#step-2-configure-environment)

---

## 🤝 Integration Points

### Input Sources

- **Drafts App** - Primary note capture (iOS/Mac)
- **Webhook API** - Direct HTTP POST to `/webhook/api/drafts`
- **Future**: Obsidian, Apple Notes, Bear, etc.

### Output Destinations

- **SQLite Database** - Structured storage with full search
- **Obsidian Vault** - Markdown files with backlinks
- **Future**: Notion, Roam, LogSeq, etc.

### LLM Integration

- **Ollama** - Local AI processing (recommended)
- **Future**: OpenAI API, Claude API, local models

**See:** [API Documentation](api/webhooks.md)

---

## 🐛 Troubleshooting

**Most Common Issues:**

1. **Container won't start** → [Docker Issues](troubleshooting/docker.md)
2. **Ollama connection fails** → [Ollama Configuration](api/ollama.md#troubleshooting)
3. **SQLite locked errors** → [Database Issues](troubleshooting/database.md)
4. **Workflows fail** → [Workflow Debugging](troubleshooting/workflows.md)

**See:** [Complete Troubleshooting Guide](troubleshooting/common-issues.md)

---

## 📈 Performance & Limits

| Metric | Limit/Performance |
|--------|------------------|
| **Note Size** | Up to 10,000 characters recommended |
| **Processing Time** | 10-30 seconds per note (with Mistral 7B) |
| **Database Size** | Tested with 10,000+ notes |
| **Concurrent Processing** | 1 note at a time (sequential) |
| **Export Speed** | ~50 notes per minute to Obsidian |

**See:** [Performance Tuning](guides/performance.md)

---

## 🛠️ Development

### Project Structure

```
selene-n8n/
├── docs/                    # Documentation (you are here)
├── data/                    # SQLite database
│   └── selene.db
├── vault/                   # Obsidian export destination
│   └── Selene/
├── database/                # Database schema
│   └── schema.sql
├── docker-compose.yml       # Container orchestration
├── Dockerfile               # Custom n8n image
├── .env                     # Configuration
└── *.json                   # n8n workflow files (01-06)
```

### Contributing

This is a personal project, but if you'd like to:
- Report bugs → Create an issue
- Suggest features → Start a discussion
- Submit improvements → Open a pull request

---

## 📝 Changelog

### Version 1.0.0 (October 29, 2025)

**Initial Release:**

- ✅ 6 complete workflows operational
- ✅ Drafts app integration working
- ✅ Ollama LLM processing functional
- ✅ Obsidian export pipeline ready
- ✅ Sentiment analysis implemented
- ✅ Connection network detection active
- ✅ Complete documentation suite
- ✅ Docker containerization complete

**Migration from Python codebase:**
- Simplified from 10,000+ lines of Python to ~3,000 lines of n8n workflows
- Reduced setup complexity by 90%
- Visual debugging instead of log diving
- No more virtual environments or dependency hell

---

## 🎓 Learning Resources

### n8n Documentation
- [Official n8n Docs](https://docs.n8n.io)
- [Community Nodes](https://docs.n8n.io/integrations/community-nodes/)
- [Function Node Examples](https://docs.n8n.io/code-examples/)

### Ollama Resources
- [Ollama Documentation](https://ollama.ai/docs)
- [Available Models](https://ollama.ai/library)
- [API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)

### SQLite References
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [Better-sqlite3 Wiki](https://github.com/WiseLibs/better-sqlite3/wiki)

### Obsidian Help
- [Obsidian Documentation](https://help.obsidian.md/)
- [Markdown Syntax](https://help.obsidian.md/Editing+and+formatting/Basic+formatting+syntax)

---

## 📧 Support

**Documentation Questions:**
- Check [FAQ](troubleshooting/faq.md) first
- Review [Common Issues](troubleshooting/common-issues.md)
- Search existing documentation

**Technical Issues:**
- Enable debug logging: `docker-compose logs -f n8n`
- Check workflow execution history in n8n UI
- Review [Troubleshooting Guide](troubleshooting/common-issues.md)

---

## 📄 License

This project is provided as-is for personal use. Feel free to modify and adapt to your needs.

**Dependencies:**
- n8n: [Sustainable Use License](https://docs.n8n.io/reference/license/)
- better-sqlite3: MIT License
- SQLite: Public Domain

---

## 🙏 Acknowledgments

- **n8n team** - For the amazing workflow automation platform
- **Ollama team** - For making local AI accessible
- **Obsidian team** - For the best knowledge management tool
- **Drafts team** - For seamless note capture on iOS

Built with ❤️ for ADHD brains who think in networks, not hierarchies.

---

**Ready to get started?** → [Quick Start Guide](guides/quickstart.md)
