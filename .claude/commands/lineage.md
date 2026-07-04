---
name: parent chain
description: Show the current agent's ancestors and descendants — a lightweight view of where you are in the agent tree. Lighter than /agent registry.
---

# Lineage — Where Am I?

> "Know your fathers. Know your children."

Display the current agent's position in the agent registry tree.

## Steps

1. Read `registry/agent-registry.json`
2. Identify the current agent (from context or default to "root")
3. Trace upward to find all ancestors
4. Trace downward to find all descendants
5. Display:

```
LINEAGE
═══════════════════════════════════════

You are: [agent id] (generation N)
Mandate: [your mandate]

Ancestors:
  root (gen 0) — Orchestrate the Covenant Framework
  └── [parent] (gen 1) — [mandate]
      └── YOU (gen N) — [mandate]

Descendants:
  ├── [child] (gen N+1) ● active — [mandate]
  └── [child] (gen N+1) ✓ archived — [mandate]

Siblings: N active, N archived
Generation depth remaining: [4 - current gen]
Sibling slots remaining: [8 - current siblings]

═══════════════════════════════════════
```

## Notes

- This is a focused view. For the full tree, use `/agent registry`
- Generation depth remaining tells you how many more levels you can spawn
- Sibling slots remaining tells you how many peers your parent can still create
