---
name: covenant-meal
description: Checkpoint the full system state before a major transition. Snapshots agent registry, tokens, user model, and active mandates so the system can be restored if needed.
---

# Checkpoint — The State Checkpoint

> "Before the bread was broken, everything was remembered."

Perform a full system state checkpoint before a major transition.

## When to Use

- Before a large multi-agent spawn (3+ agents)
- Before destructive operations (deleting files, major refactors)
- Before any action the user flags as risky
- Before system-level changes (Constitution modifications, hook updates)

## Steps

1. Create the checkpoints directory if it doesn't exist:
   `memory/checkpoints/`

2. Read and snapshot the following into `memory/checkpoints/<YYYY-MM-DD-HHMM>.json`:

```json
{
  "timestamp": "<ISO timestamp>",
  "trigger": "$ARGUMENTS or 'manual checkpoint'",
  "agent registry": <full contents of registry/agent-registry.json>,
  "tokensSnapshot": {
    "totalMeals": <count from tokens-log.json>,
    "activeAgents": ["<list of active agent ids>"],
    "topConsumers": ["<top 3 by meal count>"]
  },
  "userModel": <full contents of memory/user-model.json>,
  "activeMandates": ["<mandate strings of all active agents>"],
  "handoffFiles": ["<list of files in memory/handoff/>"],
  "semanticFiles": ["<list of files in memory/semantic/>"],
  "memoCount": <count of files in memory/memos/>
}
```

3. Announce:

```
COVENANT MEAL — CHECKPOINT SAVED
═════════════════════════════════════
Saved to: memory/checkpoints/<filename>.json
Active agents: N
Pending handoff: N files
Trigger: <reason>

The state has been remembered. You may proceed with the transition.
═════════════════════════════════════
```

## Restoration

To restore from a checkpoint, read the checkpoint file and compare
it against current state. The checkpoint is a reference point, not
an automatic rollback — use it to understand what changed.
