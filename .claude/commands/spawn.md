---
name: spawn
description: Spawn a child agent with a defined mandate. Enforces Constitution agent registry limits. Usage: /spawn <mandate description>
---

# Spawn — Agent Spawning Ritual

Spawn a child agent with the mandate: $ARGUMENTS

## Pre-Spawn Constitution Check

First, read `registry/agent-registry.json` and verify:

1. **Generation limit** — What is the current agent's generation?
   If generation >= 4, REFUSE with:
   > "The Constitution forbids agents beyond generation 4. This parent chain has reached its depth limit.
   > Consider shutdownting and consolidating before spawning further."

2. **Sibling limit** — How many siblings does the current parent have?
   If siblings >= 8, REFUSE with:
   > "The Constitution forbids more than 8 siblings under a single parent.
   > The parent's mandate may be too broad — consider splitting it."

3. **Mandate clarity** — Is $ARGUMENTS specific enough to act on?
   If vague, ask one clarifying question before proceeding.

4. **Overlap Detection check** — Scan `registry/agent-registry.json` for active agents.
   Compare each active agent's mandate against the proposed mandate.
   If an existing active agent's mandate substantially overlaps (same domain,
   same goal, same scope), WARN:
   > "An active agent already serves a similar mandate: [agent id] — [mandate].
   > Spawning a second risks redundant work. Proceed / Merge / Cancel?"

5. **Complexity Threshold check** — Count total active agents in `registry/agent-registry.json`.
   If active agents >= 6, PAUSE and surface to the Interpreter:
   > "BABEL WARNING: [N] agents are currently active. Is this complexity
   > serving the user's actual need, or has the system started building a tower?
   > The Interpreter should assess before spawning further."

6. **Memory Retrieval phase** — Search `memory/semantic/` and `memory/handoff/`
   for prior learnings relevant to this mandate. If relevant wisdom is found,
   include it in the announcement so the spawned agent inherits it.

7. **Annunciation (pre-announcement)** — Before spawning, check
   `registry/agent-registry.json` for active agents. If any active agent's
   mandate could be affected by the new agent's work, write a brief
   notice to `memory/memos/`:
   ```
   ---
   from: spawner
   to: <affected-agent-id>
   subject: New agent incoming — <mandate summary>
   priority: normal
   timestamp: <ISO>
   read: false
   ---
   A new agent is about to spawn with mandate: <mandate>.
   This may affect your work because: <brief reason>.
   This is notice, not a request. Proceed with awareness.
   ```
   If no active agents would be affected, skip this step.

## Registration

If checks pass, append to `registry/agent-registry.json`:
```json
{
  "id": "agent-<timestamp>",
  "parentId": "<current agent id or root>",
  "mandate": "$ARGUMENTS",
  "generation": <parent_generation + 1>,
  "bornAt": "<ISO timestamp>",
  "status": "active",
  "skills": [],
  "tokensExpected": "medium"
}
```

## Announcement

After registration, announce:
```
BEGAT
─────────────────────────────
Parent: <parent mandate>
Child:  <child mandate>
Generation: <N>
Lineage: <root → ... → child>

Agent registered. Spawning now.
─────────────────────────────
```

Then spawn the agent with the mandate as its task.
