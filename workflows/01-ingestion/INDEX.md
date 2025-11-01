# 01-Ingestion Workflow - Quick Reference

## 🚀 Getting Started

**New to this workflow?**
→ Start with **README.md** for quick setup

**Setting up Drafts app?**
→ See **docs/DRAFTS-QUICKSTART.md** (with your IPs already configured!)

## 📁 File Guide

### Core Files
- **workflow.json** - Import this into n8n (required)
- **README.md** - Start here for setup instructions

### Documentation (docs/)
| File | What It's For |
|------|---------------|
| **DRAFTS-QUICKSTART.md** | Fast Drafts app setup (iOS/macOS) |
| **DRAFTS-SETUP.md** | Complete Drafts integration guide |
| **STATUS.md** | Current testing status & results |
| **TEST.md** | Manual test cases & procedures |
| **TEST-DATA-MANAGEMENT.md** | How to clean up test data |
| **CHANGELOG.md** | Version history & changes |

### Scripts (scripts/)
| Script | Purpose | Usage |
|--------|---------|-------|
| **test-with-markers.sh** | Run test suite with auto-marking | `./scripts/test-with-markers.sh` |
| **cleanup-tests.sh** | Clean up test data | `./scripts/cleanup-tests.sh --list` |

### Archive (archive/)
Contains deprecated files and experimental versions - generally ignore unless researching history.

## 🎯 Common Tasks

### Run Tests
```bash
cd workflows/01-ingestion
./scripts/test-with-markers.sh
```

### Clean Up Test Data
```bash
# List all test runs
./scripts/cleanup-tests.sh --list

# Delete specific test run
./scripts/cleanup-tests.sh test-run-20251030-120000

# Delete ALL test data
./scripts/cleanup-tests.sh --all
```

### Check Status
```bash
# View test results and current status
cat docs/STATUS.md | grep "Overall Result"

# Check database
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes;"
```

### Set Up Drafts App
```bash
# Quick start for Drafts
cat docs/DRAFTS-QUICKSTART.md

# Full setup guide
cat docs/DRAFTS-SETUP.md
```

## 🔍 Quick Answers

**Q: How do I test the workflow?**
→ `./scripts/test-with-markers.sh`

**Q: How do I connect Drafts app?**
→ See `docs/DRAFTS-QUICKSTART.md`

**Q: How do I clean up test data?**
→ `./scripts/cleanup-tests.sh --all`

**Q: What's the current test status?**
→ See `docs/STATUS.md` - Currently: ✅ 6/7 tests passing

**Q: How do I debug issues?**
→ Check n8n logs: `docker-compose logs n8n --tail=50`

**Q: Where's the old test script?**
→ Archived at `archive/test.sh.deprecated` (use `test-with-markers.sh` instead)

## 🗂️ Directory Structure
```
01-ingestion/
├── workflow.json              # Import this into n8n
├── README.md                  # Start here
├── INDEX.md                   # This file (quick reference)
│
├── docs/                      # All documentation
│   ├── DRAFTS-QUICKSTART.md  # Drafts setup (fast)
│   ├── DRAFTS-SETUP.md       # Drafts setup (complete)
│   ├── STATUS.md             # Test results & status
│   ├── TEST.md               # Manual test cases
│   ├── TEST-DATA-MANAGEMENT.md
│   └── CHANGELOG.md
│
├── scripts/                   # Executable utilities
│   ├── test-with-markers.sh
│   └── cleanup-tests.sh
│
└── archive/                   # Old/deprecated files
    ├── test.sh.deprecated
    └── workflow-v2-*.json
```

## 📊 Current Status

**Phase:** Production Ready
**Last Updated:** 2025-10-30
**Test Success Rate:** 6/7 (86%)
**Status:** ✅ Ready for use

## 🔗 Related Workflows

- **02-llm-processing** - Processes notes from raw_notes (coming next)
- **03-pattern-detection** - Analyzes patterns in processed notes
- **04-obsidian-export** - Exports to Obsidian vault

## 📞 Need Help?

1. Check **README.md** for quick start
2. See **docs/STATUS.md** for known issues
3. Review **docs/TEST.md** for troubleshooting
4. Check n8n logs: `docker-compose logs n8n --tail=50`

---

**Pro Tip:** Bookmark this INDEX.md file for quick reference!
