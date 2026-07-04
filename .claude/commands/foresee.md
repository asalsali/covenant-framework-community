---
name: foresee
description: Interpreteric lookahead — simulate projected outcomes of a spawn plan or current trajectory before committing. Isaiah-style reasoning over future states.
---

# Foresee — Interpreteric Lookahead

> "The interpreter sees not what is, but what follows from what is."

Simulate the projected outcomes of a plan or current trajectory
before committing to execution.

## Usage

- `/foresee` — analyze the current system trajectory
- `/foresee <plan description>` — simulate a specific plan's outcomes

## Steps

### 1. Read Current State
Silently read:
- `registry/agent-registry.json` — active agents, parent chain depth, sibling counts
- `registry/tokens-log.json` — consumption trends
- `memory/user-model.json` — user patterns and implied needs
- The `project goal` field in agent-registry.json — the project's telos

### 2. Project Forward

For the current trajectory or proposed plan, reason through:

```
FORESIGHT
═══════════════════════════════════════

Current trajectory: [what will happen if nothing changes]

If this plan executes:
  Best case:  [what success looks like]
  Likely case: [most probable outcome]
  Worst case:  [what could go wrong]

Token projection:
  Estimated total consumption: [low/medium/high]
  Risk of over-consumption: [which agents, why]

Agent Registry projection:
  Max generation depth: [N of 4]
  Max sibling count: [N of 8]
  Risk of hitting limits: [yes/no, where]

Progress toward project goal:
  Current distance: [how far from the telos]
  This plan moves us: [closer / sideways / further]

Risks:
  - [risk 1 — what triggers it, what the consequence is]
  - [risk 2]

Recommended adjustments:
  - [adjustment 1 — why it reduces risk or cost]

═══════════════════════════════════════
```

### 3. Decision

End with one of:
- **PROCEED** — the projection looks sound
- **ADJUST** — proceed with the recommended modifications
- **HALT** — the projection reveals problems that need resolution first

## Notes

- Foresight is not prediction — it is disciplined imagination
- The projection should be honest about uncertainty
- If the project goal is not set, note that alignment cannot be measured
- This command does NOT execute anything — it only projects
