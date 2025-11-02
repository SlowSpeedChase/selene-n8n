# Workflow Modification Protocol

**CRITICAL:** This protocol MUST be followed for ALL n8n workflow modifications.

## The Rule

**ALWAYS modify `workflow-test.json` FIRST, NEVER modify `workflow.json` directly.**

## Why This Matters

1. **Safety**: Production workflows are live and processing real data
2. **Testing**: Test workflows allow safe experimentation
3. **Validation**: User can verify changes before production deployment
4. **Rollback**: Easy to revert if something goes wrong

## The Process

### Before ANY workflow modification:

1. **Check TodoWrite** - Create a checklist:
   ```
   - Verify workflow-test.json exists
   - Make changes to workflow-test.json
   - Test changes
   - Wait for user approval
   - Apply to workflow.json (only after approval)
   ```

2. **Check for test file**:
   ```bash
   ls workflows/[workflow-name]/workflow-test.json
   ```

3. **If missing, ask user**:
   > "I notice workflow-test.json doesn't exist. Should I create it from the production workflow before making changes?"

### During modification:

1. **Edit workflow-test.json ONLY**
2. **Test thoroughly**
3. **Document changes**
4. **Inform user**: "Changes applied to workflow-test.json. Please test before production deployment."

### Deployment to production:

1. **WAIT for explicit user approval** with phrases like:
   - "Looks good, deploy to production"
   - "Ready for prod"
   - "Apply to production workflow"

2. **Only then** apply same changes to workflow.json

3. **Verify** changes were applied correctly

## Enforcement Mechanisms

### 1. Git Pre-Commit Hook
Located at `.git/hooks/pre-commit`, warns when modifying production workflow files.

### 2. Slash Command
Use `/edit-workflow` command to be reminded of this protocol.

### 3. TodoWrite Pattern
Always create a todo checklist for workflow modifications that includes:
- Checking for workflow-test.json
- Making changes to test first
- Waiting for approval
- Deploying to production

## Quick Reference

| File | Purpose | When to Edit |
|------|---------|--------------|
| `workflow-test.json` | Testing | During development, ALWAYS |
| `workflow.json` | Production | After user approval ONLY |

## Related Documentation

- Full details: `/workflows/CLAUDE-WORKFLOW-INSTRUCTIONS.md` (lines 133-213)
- Slash command: `.claude/commands/edit-workflow.md`
- Git hook: `.git/hooks/pre-commit`

## Exceptions

There are **NO exceptions** to this rule. Even for "small" or "trivial" changes:
- Test first
- Get approval
- Then deploy

## What If I Forget?

The git pre-commit hook will catch it and warn you. But by then, you've already made a mistake.

**Prevention is better than detection. Follow this protocol EVERY time.**

---

**Last Updated**: 2025-11-01
**Status**: Active - Strictly Enforced
