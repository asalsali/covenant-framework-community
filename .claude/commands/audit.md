---
name: audit
description: Run a Guardian health audit on the Covenant Framework. Checks agent registry, tokens consumption, input policy compliance, handoff status, and Constitutional violations.
---

# Audit — Guardian Health Check

> "The Guardian watches so the system may rest in peace."

Invoke the Guardian agent to perform a full system health audit.

## Steps

1. Read `registry/agent-registry.json` — check for:
   - Agents beyond generation 4 (Constitutional violation)
   - Parents with >8 children (Constitutional violation)
   - Active agents with no recent tokens log entries (orphan risk)
   - Agents that should have shutdown but remain active

2. Read `registry/tokens-log.json` — check for:
   - Average consumption per agent
   - Any agent consuming >6000 tokens per task (over-consumption)
   - Most expensive tool calls
   - Top 3 tokens consumers

3. Check `memory/handoff/` — look for:
   - Unclaimed handoff files
   - Recurring patterns suggesting unsolved problems

4. Check Constitution compliance across all hooks and settings:
   - Are all hooks wired in `.claude/settings.json`?
   - Do any hooks have silent failure modes?

5. Produce the Guardian Audit Report in the standard format.

## Output

Print the audit report directly. Do not write to a file unless
the user requests a persistent record.

If violations are found, recommend specific corrective actions
ordered by urgency.
