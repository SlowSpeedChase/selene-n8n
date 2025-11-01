# Selene Agent System

This directory contains autonomous Claude Code agents for the Selene project.

## Available Agents

### Documentation Agent

**Purpose:** Automatically maintains and updates all project documentation

**Location:** `.claude/agents/documentation-agent.md`

**Guide:** `docs/agents/documentation-agent-guide.md`

**Quick Start:**
```bash
# Run the agent
./scripts/run-doc-agent.sh

# Or in Claude Code CLI
"Run the documentation agent"
```

**What it does:**
- Monitors workflow files, database schema, and configuration for changes
- Analyzes impact on documentation
- Proposes updates to keep docs synchronized
- Maintains consistency across all documentation
- Reports changes clearly

**When to use:**
- After modifying workflow JSON files
- After database schema changes
- After configuration updates
- Weekly for maintenance
- Before version releases

**Learn more:** See [Documentation Agent Guide](documentation-agent-guide.md)

---

## Agent Philosophy

Agents in the Selene project follow these principles:

1. **Autonomous but Collaborative** - Agents work independently but seek approval for significant changes
2. **Proactive** - Agents identify issues before they become problems
3. **Transparent** - Agents clearly report what they're doing and why
4. **Respectful** - Agents preserve user intent and ask when uncertain
5. **Consistent** - Agents maintain project standards and conventions

---

## How Agents Work

### Agent Definition

Each agent is defined in `.claude/agents/{agent-name}.md` with:
- Purpose and responsibilities
- Execution guidelines
- Decision-making criteria
- Interaction protocols

### Agent Invocation

Agents can be triggered:

1. **Manually** - User explicitly asks Claude Code to run an agent
2. **Automatically** - Git hooks or cron jobs detect conditions and suggest running agent
3. **On-Demand** - Scripts generate prompts for agent execution

### Agent Workflow

```
Trigger → Agent Loads Instructions → Analyzes Situation → Proposes Actions → Waits for Approval → Executes → Reports
```

---

## Creating New Agents

To add a new agent to the Selene project:

1. **Define the agent** in `.claude/agents/your-agent-name.md`
   - Clear purpose statement
   - Specific responsibilities
   - Decision-making guidelines
   - Boundaries (what NOT to do)

2. **Create triggering mechanism**
   - Manual invocation instructions
   - Optional: automation scripts
   - Optional: Git hooks

3. **Document the agent** in `docs/agents/your-agent-name-guide.md`
   - What it does
   - How to use it
   - Examples
   - Troubleshooting

4. **Test thoroughly**
   - Run in various scenarios
   - Verify it asks for approval appropriately
   - Ensure it reports clearly

5. **Update this README** to list the new agent

---

## Agent Ideas (Future)

Potential agents that could be added to Selene:

### Testing Agent
- Automatically runs tests when code changes
- Updates test results in STATUS.md files
- Identifies missing test coverage
- Suggests new test cases

### Performance Agent
- Monitors workflow execution times
- Identifies slow queries or bottlenecks
- Suggests optimizations
- Updates performance metrics in docs

### Security Agent
- Scans for sensitive data in notes
- Validates that private information isn't logged
- Checks environment variable usage
- Ensures secure configurations

### Quality Agent
- Reviews code consistency
- Checks for best practices
- Validates naming conventions
- Suggests improvements

### Backup Agent
- Schedules database backups
- Verifies backup integrity
- Manages retention policies
- Alerts on backup failures

---

## Best Practices

### Working with Agents

1. **Trust but Verify** - Review agent proposals before approving
2. **Provide Feedback** - Tell agents when they get something wrong
3. **Be Specific** - Give clear instructions for what you want
4. **Use Regularly** - Agents are most effective when run consistently
5. **Maintain Agents** - Update agent definitions as project evolves

### Agent Etiquette

When invoking agents:
- **Be clear** about what you want
- **Provide context** if the situation is unusual
- **Review proposals** before approving
- **Give feedback** to help agents improve

When creating agents:
- **Define boundaries** clearly
- **Ask before significant changes**
- **Report actions** transparently
- **Preserve user work** always
- **Be helpful** not intrusive

---

## Troubleshooting

### Agent Not Found

```bash
# Verify agent exists
ls -la .claude/agents/

# Check agent definition
cat .claude/agents/documentation-agent.md
```

### Agent Behavior Unexpected

1. Review the agent definition file
2. Check recent changes to the agent
3. Provide specific feedback to the agent
4. Update agent instructions if needed

### Automation Not Working

```bash
# Check Git hooks
ls -la .git/hooks/
./scripts/setup-git-hooks.sh

# Check cron jobs
crontab -l

# Review logs
cat .claude/doc-agent.log
```

---

## Resources

- **Claude Code Documentation:** [docs.claude.com/claude-code](https://docs.claude.com/claude-code)
- **Agent Definition Template:** `.claude/agents/documentation-agent.md` (use as reference)
- **Project Documentation:** `docs/README.md`

---

## Summary

The Selene agent system provides **autonomous assistants** that handle routine maintenance tasks, allowing you to focus on building features instead of maintaining documentation and infrastructure.

**Current Agents:**
- ✅ **Documentation Agent** - Keeps all docs synchronized with code

**Future Possibilities:**
- Testing Agent
- Performance Agent
- Security Agent
- Quality Agent
- Backup Agent

**Getting Started:**
1. Read the [Documentation Agent Guide](documentation-agent-guide.md)
2. Run `./scripts/run-doc-agent.sh`
3. Experience autonomous documentation maintenance
4. Consider what other agents would be helpful

---

**Questions?** See individual agent guides or ask in Claude Code: "How do I use the documentation agent?"
