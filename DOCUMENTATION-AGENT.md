# Documentation Agent - Quick Reference

**Status:** ✅ Ready to use
**Created:** 2025-10-31
**Location:** `.claude/agents/documentation-agent.md`

---

## What Is It?

An autonomous Claude Code agent that monitors your Selene project and automatically keeps all documentation up to date as code changes occur.

---

## Quick Start

### Run the Agent

```bash
# From project root
./scripts/run-doc-agent.sh
```

Or in Claude Code CLI:
```
Run the documentation agent
```

### First-Time Setup

```bash
# Setup Git hooks (optional)
./scripts/setup-git-hooks.sh
```

That's it! You're ready to go.

---

## What It Does

✅ **Monitors** workflow files, database schema, and configuration
✅ **Detects** when documentation needs updating
✅ **Proposes** specific changes with clear rationale
✅ **Waits** for your approval before making changes
✅ **Updates** documentation automatically
✅ **Reports** what was changed and why

---

## When to Use It

**After these changes:**
- Modified workflow JSON files
- Updated database schema
- Changed configuration (docker-compose.yml, .env)
- Added/removed features

**Regular maintenance:**
- Weekly documentation health checks
- Before version releases
- After major development sprints

**Quick check:**
```bash
./scripts/run-doc-agent.sh --force
```

---

## How It Works

```
Code Changes → Detection → Analysis → Proposal → Approval → Update → Report
```

1. You change code (or agent detects changes)
2. Agent scans affected files
3. Agent identifies outdated documentation
4. Agent proposes specific updates
5. **You review and approve**
6. Agent makes changes
7. Agent reports what was done

---

## Example Workflow

```bash
# 1. Make a change to a workflow
vim workflows/02-llm-processing/workflow.json

# 2. Commit the change
git add workflows/02-llm-processing/workflow.json
git commit -m "Add word count calculation"

# 3. Git hook reminds you about docs
# 📝 Documentation update recommended

# 4. Run the agent
./scripts/run-doc-agent.sh

# 5. Review proposals
# Agent proposes:
#   - Update README (node count 11→12)
#   - Add feature to feature list
#   - Update timestamp

# 6. Approve changes
# Type: yes

# 7. Agent updates docs and reports
# ✅ Updated 3 files successfully

# 8. Commit doc updates
git add workflows/ docs/
git commit -m "Update docs for word count feature [doc-agent]"
```

---

## Common Commands

```bash
# Run agent (checks for changes)
./scripts/run-doc-agent.sh

# Force run (even if no changes detected)
./scripts/run-doc-agent.sh --force

# Setup Git hooks
./scripts/setup-git-hooks.sh

# View agent log
cat .claude/doc-agent.log

# In Claude Code CLI
"Run the documentation agent"
"Check if documentation needs updating"
"Update docs for workflow 02"
```

---

## What It Updates

**Files the agent can modify:**
- `README.md` (all levels)
- `STATUS.md` (all levels)
- `docs/**/*.md`
- Architecture diagrams
- Configuration examples
- Timestamps and versions

**What it won't change:**
- Code files
- Configuration files (.env, docker-compose.yml)
- User-written commentary
- Design decisions
- Roadmap plans

---

## Files Created

```
.claude/agents/
  └── documentation-agent.md           # Agent definition

scripts/
  ├── run-doc-agent.sh                # Agent runner
  └── setup-git-hooks.sh              # Git hook installer

docs/agents/
  ├── README.md                        # Agent system overview
  └── documentation-agent-guide.md    # Comprehensive guide

.git/hooks/
  ├── post-commit                     # Notification after commits
  └── pre-push                        # Warning before pushes

.claude/
  ├── .doc-agent-last-run            # Timestamp tracker
  └── doc-agent.log                  # Execution log
```

---

## Troubleshooting

### "No changes detected"

```bash
# Force run anyway
./scripts/run-doc-agent.sh --force
```

### Git hooks not working

```bash
# Reinstall hooks
./scripts/setup-git-hooks.sh

# Test manually
.git/hooks/post-commit
```

### Agent making wrong updates

1. Revert: `git checkout -- affected-file.md`
2. Tell the agent what was wrong
3. Run again with more specific instructions

---

## Full Documentation

- **Complete Guide:** `docs/agents/documentation-agent-guide.md`
- **Agent Definition:** `.claude/agents/documentation-agent.md`
- **Agent System Overview:** `docs/agents/README.md`

---

## Benefits

**Before Documentation Agent:**
- ❌ Update code, forget to update docs
- ❌ Documentation slowly becomes outdated
- ❌ New developers confused by wrong info
- ❌ Examples stop working
- ❌ Manual doc updates take time

**With Documentation Agent:**
- ✅ Code and docs stay synchronized
- ✅ Documentation always current
- ✅ Consistent formatting everywhere
- ✅ Examples match current code
- ✅ Automatic maintenance

---

## Next Steps

1. **Try it now:**
   ```bash
   ./scripts/run-doc-agent.sh --force
   ```

2. **Make a small change** and run the agent

3. **Review the proposals** to see how it works

4. **Read the full guide:** `docs/agents/documentation-agent-guide.md`

5. **Set up Git hooks** for automatic reminders

---

## Questions?

**In Claude Code, ask:**
- "How do I use the documentation agent?"
- "Run the documentation agent to check for updates"
- "Update documentation for [specific workflow]"

**Read the guides:**
- `docs/agents/documentation-agent-guide.md` - Comprehensive documentation
- `docs/agents/README.md` - Agent system overview

---

**The Documentation Agent: Your autopilot for keeping docs up to date!** 🚀
