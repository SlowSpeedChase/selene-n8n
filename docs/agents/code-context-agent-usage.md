# Code Context Agent - Usage Guide

## Overview

The **code-context-agent** maintains CLAUDE.md files and minimal inline comments throughout the Selene-n8n codebase to prevent context rot as the project scales. It provides AI-navigable context building blocks for better code comprehension.

## Quick Start

### ✨ Automatic Updates (Git Hook)

**The code-context-agent now runs automatically on every commit!**

When you commit changes, the git hook will:
1. ✅ Detect if your staged files require CLAUDE.md updates
2. 💬 Prompt you to update if needed
3. ⏸️ Pause the commit so you can run `/update-context`
4. 📦 Include the updates in the same commit

**Example workflow:**
```bash
# 1. Make changes to code
vim workflows/01-ingestion/workflow.json

# 2. Stage and commit
git add workflows/01-ingestion/workflow.json
git commit -m "feat: Add new validation node"

# 3. Hook detects change and prompts:
#    "CLAUDE.md Updates Recommended"
#    "Update CLAUDE.md files? [y/n/c]:"

# 4. Choose [y], then:
/update-context

# 5. Review changes, stage CLAUDE.md, retry commit
git add workflows/01-ingestion/CLAUDE.md
git commit -m "feat: Add new validation node"
```

**Trigger Files** (auto-detected):
- `workflows/*/workflow.json` → Updates workflow CLAUDE.md
- `database/schema.sql` → Updates database/CLAUDE.md
- `SeleneChat/Package.swift` → Updates SeleneChat/CLAUDE.md
- `SeleneChat/Sources/*/*.swift` → Updates respective CLAUDE.md
- `docker-compose.yml`, `.env.example` → Updates root CLAUDE.md
- New workflow directories → Proposes new CLAUDE.md
- `test-with-markers.sh`, `cleanup-tests.sh` → Updates component CLAUDE.md

**You can skip updates** by choosing `[n]` if you're in a hurry - just remember to run `/update-context` later!

### Initial Setup

The agent has already generated 14 CLAUDE.md files across the codebase:

```
✓ CLAUDE.md                                    (150 lines) - Root project context
✓ workflows/CLAUDE.md                          (184 lines) - n8n workflow patterns
✓ workflows/01-ingestion/CLAUDE.md            (140 lines) - Ingestion workflow
✓ workflows/02-llm-processing/CLAUDE.md       (126 lines) - LLM processing
✓ workflows/03-pattern-detection/CLAUDE.md    (120 lines) - Pattern analysis
✓ workflows/04-obsidian-export/CLAUDE.md      (127 lines) - Obsidian export
✓ workflows/05-sentiment-analysis/CLAUDE.md   (225 lines) - Sentiment tracking
✓ workflows/06-connection-network/CLAUDE.md   (192 lines) - Note connections
✓ SeleneChat/CLAUDE.md                        (172 lines) - macOS app overview
✓ SeleneChat/Sources/Services/CLAUDE.md       (311 lines) - Service layer
✓ SeleneChat/Sources/Views/CLAUDE.md          (383 lines) - UI components
✓ database/CLAUDE.md                          (315 lines) - Schema patterns
✓ scripts/CLAUDE.md                           (367 lines) - Bash utilities
```

**Total:** 2,812 lines of AI-focused context

### Usage Commands

Update context files on-demand:

```bash
# Update all CLAUDE.md files
/update-context

# Update specific component
/update-context workflows/01-ingestion

# Check for stale files
/update-context --check-staleness

# Validate all files
/update-context --validate

# Full refresh
/update-context --full
```

## When to Update CLAUDE.md Files

### Automatic Triggers (Future Implementation)

The agent will eventually run via git hooks to detect:
- New directories created
- workflow.json files modified
- Package.swift or package.json changed
- database/schema.sql updated
- New test patterns added

### Manual Update Scenarios

Run `/update-context` when:

1. **After Major Refactoring** - Code structure changed significantly
2. **New Component Added** - New workflow, service, or module
3. **Pattern Changes** - New coding conventions established
4. **Significant Feature** - Large feature affecting multiple files
5. **Documentation Drift** - CLAUDE.md feels outdated

## File Structure and Content

### Standard Template

Each CLAUDE.md follows this structure:

```markdown
# [Component Name] Context

## Purpose
[1-2 sentences: what and why]

## Tech Stack
- [Languages, frameworks, tools]

## Key Files
- [file.ext] ([line count]) - [description]

## Architecture/Data Flow
[How component works internally]

## Common Patterns
- [Pattern]: [implementation details]

## Testing
- Run: [test command]
- Coverage: [current status]

## Do NOT
- [Explicit anti-patterns]

## Related Context
@[path/to/related/doc.md]
```

### What Goes in CLAUDE.md vs. README.md

| CLAUDE.md | README.md |
|-----------|-----------|
| AI-specific operational details | Project overview and purpose |
| Runtime environment variables | Getting started guide |
| Modified test commands | Installation instructions |
| Repository conventions | Basic usage examples |
| AI-relevant warnings | Architecture overview |
| Development workflow automation | Contribution guidelines |

**Key Principle:** If it helps a human, it goes in README. If it guides AI behavior, it goes in CLAUDE.md.

## Validation and Quality

### File Size Guidelines

- **Target:** 100-150 lines per file
- **Maximum:** <10,000 words (hard limit)
- **Current Status:** All files within acceptable range

**Line Counts:**
- 5 files: 120-150 lines ✓ (ideal)
- 4 files: 160-225 lines ✓ (acceptable)
- 4 files: 300-383 lines ⚠️ (detailed but still under 10k words)

### @Import References

CLAUDE.md files use `@imports` to reference other documentation:

```markdown
## Related Context
@README.md                      # Import root README
@workflows/01-ingestion/README.md
@database/schema.sql
```

**Benefits:**
- Avoids duplication
- Maintains single source of truth
- Reduces file size

### Validation Checklist

Run `/update-context --validate` to check:
- [ ] File size <10k words
- [ ] Valid markdown syntax
- [ ] @import paths exist
- [ ] No README content duplication
- [ ] All required sections present
- [ ] Consistent terminology

## Inline Comment Strategy

The agent adds **minimal comments** to code:

### When Comments ARE Added

✓ Complex algorithms (non-trivial logic)
✓ Workarounds for bugs/limitations
✓ Edge case handling
✓ Trade-off decisions
✓ External dependency assumptions

### When Comments are NOT Added

✗ Self-documenting code (clear function/variable names)
✗ Standard language patterns
✗ Obvious logic
✗ Redundant descriptions

### Language-Specific Examples

**Swift:**
```swift
/// Fetches related notes based on concept overlap
/// Uses cosine similarity (threshold: 0.7) for ADHD high-confidence needs
func fetchRelatedNotes(for note: Note) -> [Note] {
    // Implementation
}
```

**JavaScript (n8n):**
```javascript
// Generate SHA256 hash for duplicate detection
// Using n8n's built-in crypto (MD5 not available)
const contentHash = crypto.createHash('sha256')
    .update(content)
    .digest('hex');
```

**SQL:**
```sql
CREATE TABLE raw_notes (
    content_hash TEXT UNIQUE NOT NULL,  -- SHA256 for deduplication
    test_run TEXT,  -- Marker for test isolation (NULL = production)
);
```

**Bash:**
```bash
# Test ingestion workflow with unique markers
# Generates test-run-YYYYMMDD-HHMMSS for cleanup tracking
TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"
```

## Integration with doc-maintainer

### Clear Separation

| Agent | Scope | Files |
|-------|-------|-------|
| **doc-maintainer** | Markdown documentation | README.md, STATUS.md, architecture docs |
| **code-context-agent** | AI context | CLAUDE.md files, inline comments |

### Coordination

Both agents may update when:
- workflow.json changes
- database/schema.sql changes
- New components added

They coordinate to:
- Avoid duplication
- Maintain consistency
- Commit changes together

## Maintenance Schedule

### Recommended Frequency

- **Weekly:** Run staleness check (`/update-context --check-staleness`)
- **After Features:** Update relevant CLAUDE.md files
- **Monthly:** Full validation (`/update-context --validate`)
- **Quarterly:** Review and optimize file sizes

### Staleness Indicators

A CLAUDE.md file is "stale" if:
- Last modified >30 days ago
- >10 commits to component since update
- Component LOC increased >50%
- >3 new undocumented files
- Broken @import references

## Best Practices

### 1. Keep Files Concise

Each CLAUDE.md should be a **quick reference**, not comprehensive documentation.

**Good:** "Use better-sqlite3 (no credentials needed)"
**Bad:** Full tutorial on SQLite configuration

### 2. Use @Imports

Reference existing docs instead of duplicating:

```markdown
## Setup
See @workflows/01-ingestion/docs/DRAFTS-SETUP.md for Drafts integration.
```

### 3. Focus on AI Guidance

Include patterns that help AI agents:
- Explicit anti-patterns ("NEVER use Switch node for null checks")
- Common pitfalls ("Use host.docker.internal, not localhost")
- Key decisions ("Why Cron trigger instead of webhook")

### 4. Update Proactively

Don't wait for staleness warnings. Update CLAUDE.md when:
- Adding new files to component
- Changing common patterns
- Fixing bugs that reveal edge cases
- Establishing new conventions

## Troubleshooting

### File Too Large (>10k words)

**Solution:** Split into smaller files or use more @imports

### Broken @Import References

**Solution:** Verify file paths are relative from CLAUDE.md location

### Context Feels Outdated

**Solution:** Run `/update-context <component>` to refresh

### Agent Suggests Wrong Updates

**Solution:** Review and reject updates, then manually refine CLAUDE.md

## Success Metrics

### Coverage

✓ 100% component coverage (14/14 CLAUDE.md files created)

### Freshness

Target: <7 days average staleness

**Check:** `/update-context --check-staleness`

### Quality

Target: 95% files within size limits

**Current:** 100% under 10k words limit ✓

### Impact

Monitor:
- Reduction in repeated AI questions
- Faster AI onboarding to codebase
- Developer satisfaction with AI assistance

## Related Documentation

- [Agent Definition](../../.claude/agents/code-context-agent.md)
- [Update Context Command](../../.claude/commands/update-context.md)
- [ADHD Principles](../../.claude/ADHD_Principles.md)
- [Project Status](../../.claude/PROJECT-STATUS.md)
