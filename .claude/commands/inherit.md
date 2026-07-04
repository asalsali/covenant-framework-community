---
name: inherit
description: Read and display unclaimed handoff from archived agents. Shows what wisdom past agents left behind in memory/handoff/.
---

# Inherit — Claim Agent Handoff

> "The wisdom of the ancestors flows to those who seek it."

Read and display unclaimed handoff from archived agents.

## Steps

1. List all files in `memory/handoff/`
2. For each file, read its contents and display a summary:

```
INHERITANCE REGISTRY
═══════════════════════════════════════

[filename]
  Agent: [agent id from filename]
  Type: [findings / output / docs]
  Summary: [first 3 lines or key section]
  Status: unclaimed

──────────────────────────────────────
```

3. If `$ARGUMENTS` is provided, filter to handoff matching that keyword.

4. If no handoff files exist:
```
No unclaimed handoff found.
All wisdom has been consolidated, or no agents have shutdown yet.
Consider running /consolidate to consolidate any pending learnings.
```

## Notes

- Reading handoff does not consume it — Consolidation consolidation does
- Handoff files are the primary way knowledge flows between agent parent chains
- If handoff is stale (>7 days old), recommend running /consolidate
