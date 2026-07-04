# Contributing to the Covenant Framework

Thank you for your interest in contributing. This document covers how to add agents, commands, and hooks while respecting the Constitution.

> **A note on terminology:** As of May 2026, the framework uses secular
> terminology in its external-facing code and documentation. You may encounter
> older biblical terms (Canon, Prophet, Sabbath, Manna, Testament, etc.) in
> git history and memory files. See `GLOSSARY.md` for the complete mapping
> between old and new terms.

---

## The one rule

**Read `CLAUDE.md` first.** It is the Constitution -- the absolute rules that every agent, hook, and command must follow. Your contribution cannot violate it.

---

## Adding an agent

Create `.claude/agents/<name>.md` with YAML frontmatter:

```markdown
---
name: agent-name
description: >
  When to invoke this agent. Be specific -- Claude Code uses this
  to decide when to delegate. Include what the agent does and
  what it does NOT do.
tools: Read, Write, Grep, Glob, ...
---

# Agent Name

System prompt and behavioral rules.

## Your Mandate
What this agent is responsible for.

## Token Discipline
How much this agent should consume (max files to read, etc).

## Shutdown
How this agent archives itself when done.
```

**Checklist:**
- [ ] Agent has a clear, bounded mandate
- [ ] Tools are minimal -- only what the mandate requires
- [ ] Token discipline section defines consumption limits
- [ ] Shutdown section describes how the agent archives itself
- [ ] Agent does not violate the Agent Registry Law (generation 4 max, 8 siblings max)

---

## Adding a command

Create `.claude/commands/<name>.md`:

```markdown
---
name: command-name
description: One-line description of what this command does
---

# Command Name

Instructions. Use $ARGUMENTS to access user input.
```

**Checklist:**
- [ ] Description is clear enough for the user to know when to use it
- [ ] Command references system files by their actual paths
- [ ] Output format is defined (use fenced code blocks for structured output)

---

## Adding a hook

1. Create `.claude/hooks/<event>-<name>.sh`
2. Add it to `.claude/settings.json` under the correct event

**Events:**
- `PreToolUse` -- runs before every tool call. Exit 2 to block.
- `PostToolUse` -- runs after every tool call. For logging/monitoring.
- `SubagentStop` -- runs when a subagent completes. For archival.

**Hook rules:**
- Auto-detect python: `PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)`
- Use python for timestamps instead of `date -u` (cross-platform)
- Never depend on `jq` -- use python for JSON parsing
- If python is missing, `exit 0` with a warning -- never block silently
- Single responsibility -- one hook, one job

---

## Testing hooks locally

```bash
# Test input policy enforcement
echo '{"tool_name":"Read","tool_input":{"file_path":"test.md"}}' | bash .claude/hooks/pre-tool-input-policy.sh

# Test token logging
echo '{"tool_name":"Read","agent_id":"test","session_id":"test-session"}' | bash .claude/hooks/post-tool-token-log.sh

# Check the log
cat registry/token-log.json
```

---

## Key terminology for contributors

These are the terms you will encounter most often:

| Term | What It Means |
|---|---|
| **Constitution** | The ruleset in `CLAUDE.md` -- absolute, cannot be overridden |
| **Mandate** | An agent's task assignment -- one agent, one mandate |
| **Interpreter** | The orchestrator agent that talks to the user |
| **Orientation** | Shared state file (`registry/orientation.json`) |
| **Consolidation** | Periodic pause for memory distillation -- no new work |
| **Shutdown** | Agent lifecycle completion -- write exit report, archive, stop |
| **Exit Report** | Structured findings an agent writes at shutdown |
| **Tokens** | Token/cost consumption tracking |
| **Input Policy** | Rules about what context agents may consume |
| **Domain** | Horizontal grouping of agents by subject area |

For the full glossary, see `GLOSSARY.md`.

---

## Constitution rules for contributors

1. Agents must have mandates -- no open-ended agents
2. Agents must shutdown when done -- no eternal processes
3. Context must be distilled before passing to children
4. Hooks must fail gracefully -- never block silently
5. Commands must produce structured output
6. No agent spawns beyond generation 4
7. No parent may have more than 8 children
8. The Interpreter is the only agent that speaks to the user

---

## Pull request guidelines

- One agent or command per PR (unless they are tightly coupled)
- Include the agent/command checklist in your PR description
- Test hooks on both macOS/Linux and Windows (Git Bash) if possible
- Update the README project structure section if you add new files
- Use current terminology (see `GLOSSARY.md`) -- avoid old biblical terms in new code
