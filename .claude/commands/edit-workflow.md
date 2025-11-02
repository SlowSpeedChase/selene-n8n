# Edit Workflow Command

When the user asks to edit, modify, or update any n8n workflow:

## CRITICAL PRE-FLIGHT CHECKS

Before making ANY changes to workflow files, you MUST:

1. **Check for workflow-test.json**
   ```bash
   ls workflows/[workflow-name]/workflow-test.json
   ```

2. **Reference the protocol**
   - Read `/workflows/CLAUDE-WORKFLOW-INSTRUCTIONS.md` lines 133-213
   - Follow the Test/Production Workflow Process EXACTLY

3. **Create TodoWrite checklist**
   ```
   - Check if workflow-test.json exists
   - Make changes to workflow-test.json FIRST
   - Wait for user testing and approval
   - Only then modify workflow.json
   ```

## WORKFLOW MODIFICATION PROTOCOL

### Phase 1: Development (TEST)
1. **ALWAYS** make changes in `workflow-test.json` files FIRST
2. **NEVER** modify `workflow.json` directly during development
3. Test thoroughly with test data
4. Verify changes work as expected

### Phase 2: User Testing
1. User tests with real data on test endpoint
2. User validates functionality
3. User provides **explicit approval** with phrase like:
   - "Looks good, deploy to production"
   - "Ready for production"
   - "Deploy to prod"

### Phase 3: Deployment (PROD)
**ONLY after explicit user approval:**
1. Apply the same changes to `workflow.json`
2. Document the changes in commit message
3. User deploys via n8n

## WHAT TO DO IF workflow-test.json DOESN'T EXIST

If `workflow-test.json` is missing:
1. **Ask the user** if they want you to create it from production
2. If approved:
   ```bash
   cp workflows/[name]/workflow.json workflows/[name]/workflow-test.json
   ```
3. Then proceed with modifications to test version

## RED FLAGS - STOP IMMEDIATELY IF:

- User didn't explicitly request workflow changes
- You're about to modify `workflow.json` without testing first
- workflow-test.json exists but you're editing workflow.json
- User hasn't approved deployment to production

## SUCCESS CRITERIA

You've followed the protocol correctly if:
- ✅ You modified workflow-test.json FIRST
- ✅ You used TodoWrite to track the process
- ✅ You waited for user approval before touching workflow.json
- ✅ You referenced CLAUDE-WORKFLOW-INSTRUCTIONS.md

## EXAMPLES

### ❌ BAD - Don't do this:
```
User: "Change the database field to use created_at"
Claude: *Immediately edits workflow.json*
```

### ✅ GOOD - Do this instead:
```
User: "Change the database field to use created_at"
Claude:
1. Creates TodoWrite checklist
2. Checks for workflow-test.json
3. Edits workflow-test.json FIRST
4. Tells user: "I've updated workflow-test.json. Please test and let me know when ready for production."
5. WAITS for approval
6. Only then touches workflow.json
```

## ENFORCEMENT

This protocol is enforced by:
1. Git pre-commit hook (warns on workflow.json changes)
2. This command file (reminds you of the process)
3. CLAUDE-WORKFLOW-INSTRUCTIONS.md (detailed instructions)

**Remember: Test first, production second. Always.**
