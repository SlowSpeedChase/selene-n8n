# Workflow 02-06 Standardization Design

**Created:** 2025-12-31
**Status:** Approved
**Scope:** Full production readiness for workflows 02-06

---

## Goal

Bring workflows 02-06 to the same production-ready standard as workflows 01, 07, and 08:
- Verified working in live n8n
- Standard directory structure
- Automated test scripts
- Complete documentation

---

## Approach: Sequential Deep Dive

For each workflow (02 → 03 → 04 → 05 → 06):

1. **Export & Audit** - Export from n8n, compare to repo, identify gaps
2. **Reorganize Structure** - Match standard layout
3. **Create Test Script** - `scripts/test-with-markers.sh`
4. **Live Verification** - Run tests, capture results
5. **Fix Issues** - Address any failures found
6. **Complete Docs** - Update `docs/STATUS.md` with verified results
7. **Commit** - Git commit before moving to next workflow

---

## Standard Directory Structure

```
workflows/XX-name/
├── workflow.json              # Main workflow (source of truth)
├── CLAUDE.md                  # AI context file
├── README.md                  # Quick start guide
├── docs/
│   └── STATUS.md              # Test results and current state
└── scripts/
    └── test-with-markers.sh   # Automated test suite
```

**Cleanup:** Remove redundant files (workflow-test.json, workflow-enhanced.json, etc.)

---

## Workflow Order & Expected Effort

| Order | Workflow | Current State | Expected Work |
|-------|----------|---------------|---------------|
| 1 | 02-llm-processing | Has docs, missing test script | Medium |
| 2 | 03-pattern-detection | STATUS.md in wrong place, no test script | Medium |
| 3 | 04-obsidian-export | Has docs, missing test script | Medium |
| 4 | 05-sentiment-analysis | Missing STATUS.md, has tests/ dir | Medium |
| 5 | 06-connection-network | Very bare, only workflow.json + CLAUDE.md | High |

---

## Success Criteria

For each workflow:
- [ ] workflow.json matches what's in n8n
- [ ] Test script exists and runs successfully
- [ ] STATUS.md documents verified test results
- [ ] README.md has accurate quick start
- [ ] CLAUDE.md has accurate context
- [ ] No redundant files in directory
- [ ] Committed to git

---

## Pipeline Flow Reference

```
01-Ingestion (DONE)
      ↓
02-LLM-Processing → processes pending notes with Ollama
      ↓
03-Pattern-Detection → analyzes patterns across processed notes
04-Obsidian-Export → exports to Obsidian vault
05-Sentiment-Analysis → tracks emotional patterns
06-Connection-Network → builds concept connections
```

---

## Notes

- Docker/n8n is running and healthy
- All test data will use `test_run` markers for cleanup
- Each workflow committed separately for clean history
