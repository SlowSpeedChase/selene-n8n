# Claude Context Files

This directory contains context and documentation for future Claude Code sessions.

## Files Overview

### 🗺️ ROADMAP.md (PROJECT ROOT)
**Purpose:** High-level project roadmap and phase tracking
**Location:** `/Users/chaseeasterling/selene-n8n/ROADMAP.md` (project root)
**When to update:** **IMMEDIATELY** after completing any feature
**Contents:**
- Overall project phases and status
- Feature completion tracking
- Success criteria for each phase
- Timeline and priorities
- **MUST BE UPDATED** when features are completed

### 📊 PROJECT-STATUS.md
**Purpose:** Complete project status and current state
**When to read:** Start of every session
**Contents:**
- Completed workflows status
- Next workflows to build
- Technical architecture
- Important patterns & decisions
- Database schema
- Docker configuration
- Common commands
- Questions for next session

### ⚡ QUICK-REFERENCE.md
**Purpose:** Fast lookups and common commands
**When to read:** During active development
**Contents:**
- Essential commands (Docker, database, testing)
- Key file locations
- Common issues & solutions
- Useful SQL queries
- Network configuration
- Troubleshooting quick fixes

### 🏗️ DECISIONS-LOG.md
**Purpose:** Architecture decision record (ADR)
**When to read:** When making similar decisions
**Contents:**
- Why we chose certain approaches
- Rejected alternatives
- Trade-offs and consequences
- Future decisions needed
- Decision guidelines

## Usage Guide

### Starting a New Session

1. **Read PROJECT-STATUS.md** (5 min)
   - Get current state
   - Understand what's complete
   - See what's next

2. **Keep QUICK-REFERENCE.md open** (ongoing)
   - Quick command lookups
   - Common patterns
   - Troubleshooting

3. **Check DECISIONS-LOG.md** (as needed)
   - When making architecture decisions
   - When encountering similar problems
   - To understand why things are done a certain way

### During Development

**Quick lookups:**
```bash
# Commands
cat .claude/QUICK-REFERENCE.md | grep -A5 "Docker"

# Check status
cat .claude/PROJECT-STATUS.md | grep "Next Session"

# Find decision
cat .claude/DECISIONS-LOG.md | grep -A10 "better-sqlite3"
```

### After Significant Changes

**Update PROJECT-STATUS.md:**
- Mark workflows as complete
- Update "Next Session Priorities"
- Add new achievements
- Update questions

**Update ROADMAP.md (REQUIRED):**
- Mark completed tasks with ✅
- Update phase status when all tasks complete
- Add completion dates
- Update success criteria to reflect actual implementation
- Note any deviations from original plan

**Update DECISIONS-LOG.md:**
- Document any architecture decisions
- Explain why you chose an approach
- Note consequences and trade-offs

## File Maintenance

### When to Update

**PROJECT-STATUS.md:**
- After completing a workflow
- When discovering new issues
- When configuration changes
- End of each session

**ROADMAP.md (CRITICAL):**
- **IMMEDIATELY** after completing any feature or task
- When a phase is completed
- When adding new phases or features
- When changing priorities or scope
- End of each significant work session

**QUICK-REFERENCE.md:**
- When adding new common commands
- When solving a recurring issue
- When network config changes

**DECISIONS-LOG.md:**
- When making any significant technical decision
- When choosing between alternatives
- When establishing new patterns

### What NOT to Include

- Detailed code (belongs in workflow files)
- Temporary notes (use scratch file)
- Personal reminders (use TODO lists)
- Duplicate information (link instead)

## Quick Navigation

```
selene-n8n/
├── ROADMAP.md                      # 🗺️ Project phases & feature tracking (UPDATE FIRST!)
└── .claude/
    ├── README.md                   # This file - Directory guide
    ├── PROJECT-STATUS.md           # 📊 Complete project state
    ├── QUICK-REFERENCE.md          # ⚡ Fast command reference
    └── DECISIONS-LOG.md            # 🏗️ Architecture decisions
```

## Related Documentation

### Workflow-Specific
- `workflows/01-ingestion/INDEX.md` - Ingestion workflow reference
- `workflows/01-ingestion/docs/STATUS.md` - Testing results

### Technical
- `database/schema.sql` - Database structure
- `docker-compose.yml` - Container configuration
- `Dockerfile` - Custom image definition

### Integration
- `workflows/01-ingestion/docs/DRAFTS-SETUP.md` - Drafts app setup
- `workflows/01-ingestion/docs/TEST-DATA-MANAGEMENT.md` - Test cleanup

## Best Practices

### For Future Claude Sessions

1. **Always read PROJECT-STATUS.md first**
   - Prevents duplicate work
   - Understands current state
   - Gets context immediately

2. **Update ROADMAP.md IMMEDIATELY after completing features**
   - Mark tasks complete with ✅
   - Update phase status
   - Add completion dates
   - This is CRITICAL for project tracking

3. **Update files before ending session**
   - Future you will be grateful
   - Maintains continuity
   - Preserves knowledge

4. **Document decisions immediately**
   - Context is fresh
   - Reasoning is clear
   - Alternatives are remembered

5. **Keep files concise**
   - Link to detailed docs
   - Avoid duplication
   - Focus on high-level info

### For the User

These files help Claude:
- Resume work without explanation
- Understand past decisions
- Avoid repeating mistakes
- Work more efficiently

**To prepare for next session:**
- Read PROJECT-STATUS.md yourself
- Update any priorities
- Add questions you have
- Note any new context

## Emergency Recovery

If these files are lost or corrupted:

1. **Workflow Status:** Check `workflows/*/docs/STATUS.md` files
2. **Database Schema:** `sqlite3 data/selene.db ".schema"`
3. **Configuration:** `docker-compose.yml` and `Dockerfile`
4. **Test Status:** Run tests: `./workflows/*/scripts/test-with-markers.sh`

## Version History

- **2025-10-30:** Initial creation
  - PROJECT-STATUS.md created
  - QUICK-REFERENCE.md created
  - DECISIONS-LOG.md created
  - This README created

---

**Note:** These files are specifically for Claude Code sessions. They're optimized for AI context and quick recovery between sessions.
