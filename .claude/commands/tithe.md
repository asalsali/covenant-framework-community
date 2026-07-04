---
name: tithe
description: Export a tokens consumption summary report. Shows token usage per agent, per session, and overall system cost patterns.
---

# Tithe — Token Consumption Report

> "A tenth of all you consume, rendered visible."

Generate a structured tokens consumption report from `registry/tokens-log.json`.

## Steps

1. Read `registry/tokens-log.json`
2. If the log is empty:
   ```
   No tokens consumed yet. The system is fasting.
   ```

3. Otherwise, compute and display:

```
TITHE — MANNA REPORT
═══════════════════════════════════════

Report generated: [ISO timestamp]
Total meals logged: N

BY AGENT
────────────────────────────────────
| Agent        | Meals | Avg Size | Total Size | Status     |
|--------------|-------|----------|------------|------------|
| [agent-id]   | N     | N chars  | N chars    | ● healthy  |
| [agent-id]   | N     | N chars  | N chars    | ⚠ glutton  |

BY SESSION
────────────────────────────────────
| Session (short) | Agents | Meals | Duration      |
|-----------------|--------|-------|---------------|
| [first 8 chars] | N      | N     | [first-last]  |

BY TOOL
────────────────────────────────────
| Tool    | Calls | Avg Input Size |
|---------|-------|----------------|
| [tool]  | N     | N chars        |

GLUTTONY FLAGS
────────────────────────────────────
[List agents with >20 meals/session or avg input >6000 chars]
[Or: "None — all agents within tokens discipline"]

═══════════════════════════════════════
```

## Aggregate Accounting (Numbers / Census)

If tokens-log has entries across multiple mandates, also compute:

```
AGGREGATE ACCOUNTING
────────────────────────────────────
BY MANDATE TYPE
| Mandate Type     | Mandates | Total Token | Avg per Mandate |
|------------------|----------|-------------|-----------------|
| [research]       | N        | N chars     | N chars         |
| [code generation]| N        | N chars     | N chars         |

BY AGENT TYPE
| Agent Type | Times Spawned | Total Token | Avg per Spawn |
|------------|---------------|-------------|---------------|
| analyst    | N             | N chars     | N chars       |
| writer     | N             | N chars     | N chars       |

COST INSIGHTS
────────────────────────────────────
- Most expensive mandate type: [type] at [avg] per mandate
- Most expensive agent type: [type] at [avg] per spawn
- Most efficient: [type] — lowest tokens per completed mandate
────────────────────────────────────
```

This enables cost attribution: knowing that Analyst agents cost 3x
what Writer agents cost for a given mandate type.

## Options

- If `$ARGUMENTS` contains a session ID prefix, filter to that session only
- If `$ARGUMENTS` contains an agent name, filter to that agent only
- If `$ARGUMENTS` contains "aggregate", show only the aggregate section
