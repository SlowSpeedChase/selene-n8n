# Stop and Research Skill Design

**Date:** 2025-11-30
**Status:** Approved

---

## Purpose

Interrupt problem-solving loops by researching community solutions before continuing implementation. Prevents Claude from "chasing its tail" with workarounds when a standard solution exists.

---

## Triggers

### 1. Workaround Detection

When Claude catches itself thinking:
- "workaround"
- "pass data through"
- "work around this behavior"
- "hack to make this work"
- Fighting/forcing something instead of working with it

### 2. Second Failure

After one approach doesn't work cleanly, STOP and research before trying a second approach.

### When in the Workflow

- During planning (before writing the plan)
- Before implementation (when about to write code)
- When hitting resistance (mid-implementation)

---

## Research Process

### Priority Order

1. **Official documentation** - Check the technology's docs first (n8n docs, Swift docs, library READMEs)
2. **Community patterns** - Stack Overflow, GitHub discussions, official forums, Discord channels
3. **General web search** - Blog posts, tutorials, "best practice" articles

### How Research is Performed

Spawn a Task agent (`subagent_type: general-purpose`) with web access to:
- Search for "[technology] + [specific problem]"
- Search for "[technology] + best practice + [what you're trying to do]"
- Read 2-3 relevant sources thoroughly
- Synthesize findings

### Agent Returns Structured Report

```
## Problem Researched
[Exact problem statement that was searched]

## Approaches Found
1. [Approach name] - [Brief description]
   Source: [link]

2. [Approach name] - [Brief description]
   Source: [link]

3. [Approach name] - [Brief description] (if found)
   Source: [link]

## Recommended Approach
[Which approach and why it fits this situation]

## Key Sources
- [Link 1]
- [Link 2]
```

---

## Presenting Findings to User

After research completes, Claude presents options transparently:

```
I found a common solution for this. Here are the approaches:

**Option 1: [Name]** (Recommended)
[Brief description]
Source: [link]

**Option 2: [Name]**
[Brief description]
Source: [link]

**Option 3: [Name]** (if applicable)
[Brief description]
Source: [link]

I recommend Option 1 because [reasoning that accounts for your specific context].

Which approach should we use?
```

---

## Integration

- **Standalone skill** - not embedded in other skills
- Claude invokes it when triggers are detected
- After user chooses approach, Claude continues with planning or implementation using the community-validated solution
- If no relevant findings, Claude states that and proceeds with best judgment

### Announcing Usage

When triggered, Claude says:
> "I'm noticing [workaround thinking / this is the second approach that isn't working cleanly]. Let me stop and research how the community handles this before continuing."

---

## Skill File Structure

**Location:** `~/.claude/plugins/cache/superpowers/skills/stop-and-research/stop-and-research.md`

### Content Structure

```markdown
---
name: stop-and-research
description: Use when noticing workaround-thinking or after first approach fails -
spawns research agent to find community solutions before continuing
---

# Stop and Research

## When to Use This Skill

[Trigger conditions - workaround detection, second failure]

## The Process

[Step-by-step: detect trigger → announce → spawn agent → present findings → user chooses]

## Research Agent Prompt Template

[Exact prompt to send to the Task agent]

## Output Format

[Structured report format]

## Presenting to User

[How to show options with sources]

## Common Rationalizations to Reject

[List of thoughts that mean you should use this skill]
```

---

## Problem This Solves

Example from n8n workflow development:

**What happened:** HTTP Request nodes replace input data with response. Claude spent time creating complex workarounds (modifying wrappers, passthrough fields, $input.first() references).

**What community knows:** Add an "Edit Fields" node after HTTP with "Include Other Input Fields: All fields" enabled. Standard pattern, well-documented.

**With this skill:** Claude would have detected "workaround" thinking, researched "n8n HTTP node preserve input data", found the Edit Fields solution immediately.

---

## Design Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Trigger type | Workaround detection + second failure | Catches both the "smell" and the evidence of a bad path |
| Research method | Task agent with web access | Thorough research without cluttering main conversation |
| Output format | Structured report | Claude needs to integrate findings with codebase context |
| Presentation | Options with sources | Transparent, user chooses, sources for verification |
| Skill integration | Standalone | Modular, can be invoked from any context |
