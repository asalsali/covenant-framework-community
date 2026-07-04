---
name: agent registry
description: Display the full agent parent chain tree, tokens consumption report, and system health status.
---

# Agent Registry — The Census of Agents

Read `registry/agent-registry.json` and `registry/tokens-log.json`, then render:

## Lineage Tree

```
ROOT ORCHESTRATOR (generation 0)
│
├── [agent name] (gen N) ● active — mandate: [mandate]
│   ├── [child] (gen N+1) ● active — mandate: [mandate]
│   └── [child] (gen N+1) ✓ archived — mandate: [mandate]
│
└── [agent name] (gen N) ✓ archived — mandate: [mandate]
```

Legend: ● active  ✓ archived  ⚠ over-consuming  ✗ failed

## Token Report

For each active agent, calculate average token consumption from tokens-log.json.
Flag any agent consuming >150% of expected as ⚠ GLUTTONOUS.

| Agent | Mandate | Meals | Avg Consumption | Status |
|-------|---------|-------|-----------------|--------|
| ...   | ...     | ...   | ...             | ...    |

## System Health

- Total active agents: N
- Deepest generation: N  
- Agents near sibling limit (>6 siblings): list them
- Last Consolidation: <date or "Never">
- Handoff awaiting consolidation: N files
- Constitutional violations detected: list any

## Recommendations

Based on the above, what does the system need?
(Consolidation? Shutdown overdue agents? Spawn gaps?)
