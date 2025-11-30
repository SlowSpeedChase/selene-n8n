# Selene Workflows

This directory contains all n8n workflows for the Selene note processing system, organized into modular phases.

## Directory Structure

```

workflows/
├── README.md                          # This file
├── 01-ingestion/                      # Note ingestion & storage
│   ├── workflow.json                  # n8n workflow definition
│   ├── README.md                      # Workflow documentation
│   ├── TEST.md                        # Test cases & instructions
│   ├── STATUS.md                      # Testing history & status
│   └── test.sh                        # Automated test script
├── 02-llm-processing/                 # LLM analysis (Coming soon)
├── 03-pattern-detection/             # Pattern & theme detection (Coming soon)
├── 04-obsidian-export/                # Obsidian export (Coming soon)
├── 05-sentiment-analysis/             # Sentiment analysis (Coming soon)
└── 06-connection-network/             # Network analysis (Coming soon)
```

## Workflow Pipeline

```
┌─────────────────┐
│  01-INGESTION   │  Receives notes via webhook
│                 │  Stores in raw_notes table
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 02-LLM-PROCESS  │  Analyzes with LLM (Ollama)
│                 │  Extracts concepts & themes
└────────┬────────┘
         │
         ├─────────────────┐
         ▼                 ▼
┌──────────────────┐  ┌──────────────────┐
│ 03-PATTERN       │  │ 05-SENTIMENT     │
│    DETECTION     │  │    ANALYSIS      │
└────────┬─────────┘  └──────────────────┘
         │
         ▼
┌─────────────────┐
│ 04-OBSIDIAN     │  Exports to Obsidian vault
│    EXPORT       │
└─────────────────┘
```

## Workflow Status

| Phase | Status | Description |
|-------|--------|-------------|
| 01-Ingestion | ⚠️ Ready for Testing | Receives and stores notes |
| 02-LLM-Processing | ⏳ Pending | Analyzes content with LLM |
| 03-Pattern-Detection | ⏳ Pending | Detects themes and patterns |
| 04-Obsidian-Export | ⏳ Pending | Exports to Obsidian |
| 05-Sentiment-Analysis | ⏳ Pending | Analyzes sentiment |
| 06-Connection-Network | ⏳ Pending | Builds connection graphs |

Legend:
- ✅ Production Ready
- ⚠️ Ready for Testing
- 🔧 In Development
- ⏳ Pending
- ❌ Issues Found

## Getting Started

### 1. Import Workflows

**Use CLI commands to import workflows (NEVER use n8n UI):**

```bash
# Import all workflows using the management script
./scripts/import-workflows.sh

# OR import specific workflow
./scripts/manage-workflow.sh import /workflows/01-ingestion/workflow.json

# Verify import
./scripts/manage-workflow.sh list
```

**See:** `@workflows/CLAUDE.md` for the mandatory CLI workflow process

### 2. Test Each Phase

```bash
# Test ingestion
cd workflows/01-ingestion
./test.sh

# Test other phases (when available)
cd workflows/02-llm-processing
./test.sh
```

### 3. Document Results

After testing each workflow, update its `STATUS.md` file with:
- Test results
- Issues found
- Performance observations
- Next steps

## Testing Philosophy

Each workflow phase includes:

1. **TEST.md** - Detailed test cases
   - Purpose of each test
   - Commands to run
   - Expected results
   - Verification steps

2. **test.sh** - Automated test script
   - Runs all test cases
   - Validates results
   - Reports pass/fail

3. **STATUS.md** - Living document
   - Test history
   - Known issues
   - Performance metrics
   - Development notes

## Workflow Standards

All workflows in this directory follow these standards:

### File Structure
```
{phase}/
├── workflow.json       # The actual n8n workflow
├── README.md           # Quick start & documentation
├── TEST.md            # Comprehensive test instructions
├── STATUS.md          # Testing history & current status
└── test.sh            # Automated test script (executable)
```

### Naming Conventions
- Workflows: `{number}-{name}` (e.g., 01-ingestion)
- Node IDs: `{type}-{description}` (e.g., webhook-receive)
- Database fields: `snake_case`
- JSON fields: `camelCase`

### Documentation Requirements
Each workflow must have:
- Clear purpose statement
- Input/output formats
- Database schema used
- Integration points
- Test coverage
- Status tracking

## Database Tables

Workflows interact with these SQLite tables:

### raw_notes
Populated by: **01-ingestion**
Used by: **02-llm-processing**

Stores incoming notes before processing.

### processed_notes
Populated by: **02-llm-processing**
Used by: **03-pattern-detection**, **04-obsidian-export**

Stores LLM-analyzed notes with extracted concepts.

### detected_patterns
Populated by: **03-pattern-detection**
Used by: **04-obsidian-export**

Stores identified patterns and themes.

### sentiment_history
Populated by: **05-sentiment-analysis**
Used by: **04-obsidian-export**

Stores sentiment analysis results.

### network_analysis_history
Populated by: **06-connection-network**
Used by: **04-obsidian-export**

Stores connection network data.

## Quick Reference

### Run All Tests
```bash
# Test each workflow individually
for dir in workflows/*/; do
    if [ -f "$dir/test.sh" ]; then
        echo "Testing $(basename $dir)..."
        cd "$dir"
        ./test.sh
        cd ../..
    fi
done
```

### Check All Status
```bash
# View status of all workflows
for status in workflows/*/STATUS.md; do
    echo "=== $(dirname $status) ==="
    grep "^**Status:**" "$status" || echo "Status not documented"
    echo ""
done
```

### Database Inspection
```bash
# View full pipeline status
sqlite3 data/selene.db <<EOF
SELECT
    'Raw Notes' as stage,
    COUNT(*) as count,
    status
FROM raw_notes
GROUP BY status
UNION ALL
SELECT
    'Processed Notes' as stage,
    COUNT(*) as count,
    'completed' as status
FROM processed_notes;
EOF
```

## Contributing Workflow Changes

**CRITICAL: NEVER edit workflows in n8n UI. Always use CLI.**

**Mandatory 6-step CLI process:**

1. **Export** current version: `./scripts/manage-workflow.sh export <workflow-id>`
2. **Edit** the workflow.json file using Read/Edit tools
3. **Update** workflow: `./scripts/manage-workflow.sh update <workflow-id> <file>`
4. **Test** the workflow: `./workflows/{phase}/scripts/test-with-markers.sh`
5. **Document** changes in `workflows/{phase}/docs/STATUS.md`
6. **Commit** workflow.json and STATUS.md to git

**Why CLI-only:**
- UI changes don't persist in git (breaks version control)
- Professional teams treat workflows as code (immutable, version-controlled)
- CLI ensures testing and documentation happen

**See:** `@workflows/CLAUDE.md` for detailed workflow modification procedures

## Troubleshooting

### Common Issues

**Workflow import fails:**
- Check JSON syntax
- Ensure n8n is running
- Verify file path

**Tests fail:**
- Check n8n container is healthy: `docker-compose ps`
- Verify database exists: `ls -la data/selene.db`
- Check workflow is activated in n8n UI

**Database errors:**
- Reinitialize: `sqlite3 data/selene.db < database/schema.sql`
- Check permissions: `ls -la data/`

## Next Steps

1. **Complete ingestion testing** - Run `workflows/01-ingestion/test.sh`
2. **Document results** - Update `STATUS.md` files
3. **Develop next phase** - Move to 02-llm-processing
4. **Repeat for each workflow** - Test, document, iterate

## Questions?

When documenting questions or observations:
1. Add them to the relevant workflow's STATUS.md
2. Use the "Questions & Observations" section
3. Include date and context
4. Share the STATUS.md file for discussion

## Maintenance

### Weekly Checks
- Review STATUS.md files
- Run test suites
- Check database size and performance
- Update documentation

### Monthly Reviews
- Assess workflow performance
- Review error rates
- Optimize slow queries
- Archive old test data
