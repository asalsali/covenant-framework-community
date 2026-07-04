---
name: reinit
description: Re-initialization after dormancy — startup ritual when the framework has been idle. Survey abandoned agents, confirm Constitution, read last Consolidation, update user model. Re-init reading the law to the returned exiles.
---

# Re-init — The Return

> "Re-init opened the book in the sight of all the people...
> and when he opened it, all the people stood up." — Nehemiah 8:5

When the system has been dormant — the user returns after days, weeks,
or months — the first act is not execution. It is re-orientation.

## When to Trigger

- Automatically: if the last entry in `memory/user-model.json` is >24h old,
  the Interpreter should run `/reinit` before accepting new requests
- Manually: `/reinit` at any time

## Steps

### 1. Read the Law (Constitution Check)

Read `CLAUDE.md` and verify it hasn't been modified outside the framework.
If modified, note what changed. The Constitution must be current before anything acts.

### 2. Survey the Registry

Read `registry/agent-registry.json`:
- **Orphaned agents**: agents with `status: "active"` that were never shutdown.
  These were likely abandoned mid-mandate.
- **Last activity**: when was the most recent agent born or archived?
- **Hard Reset history**: any rainbow covenants since last session?
- **Pending covenants**: any active covenants in `memory/covenants/`?

### 3. Read the Last Consolidation

Find the most recent file in `memory/semantic/consolidated-*.md`:
- What was accomplished in the last cycle?
- What was learned?
- What recommendations were made?

### 4. Check the Orientation

Read `registry/orientation.json`:
- Is the spirit stale? (pentecostAt vs current time)
- Does the current mandate still apply?
- What orientation was the system in when it went dormant?

### 5. Read Unread Memos

Check `memory/memos/` for unread messages that arrived during dormancy.

### 6. Update the User Model

Append a re-engagement entry to `memory/user-model.json`:
```json
{
  "timestamp": "<ISO>",
  "type": "re-engagement",
  "dormancyDuration": "<time since last entry>",
  "orphanedAgents": <count>,
  "staleOrientation": true/false,
  "lastConsolidation": "<date or null>"
}
```

### 7. Present the Briefing

```
EZRA — THE RETURN
════════════════════════════════════════

Welcome back. The system has been dormant for [duration].

CANON STATUS
  [Current / Modified since last session]

REGISTRY
  Active agents: [N] (of which [N] appear orphaned)
  Last activity: [date]
  Hard Reset count: [N]

LAST SABBATH
  [date — brief summary of what was learned]
  [Or: "No Consolidation has been run."]

SPIRIT STATUS
  [Current mandate: X / Stale / Empty]

UNREAD EPISTLES
  [N] unread messages

ACTIVE COVENANTS
  [covenant name — fulfillment status]
  [Or: "No active covenants."]

RECOMMENDATIONS
  - [what should be done first — shutdown orphans? run Consolidation? resume mandate?]

═══════════════════════════��════════════
The law has been read. The system is oriented.
What would you like to do?
```

### 8. Clear the Reinit Gate

After completing the briefing, delete the reinit-required flag so agents can spawn:
- Delete `registry/reinit-required.flag` if it exists
- This unblocks the spawn gate (Constitution Section XXII enforcement)

## Notes

- Re-init is not optional after long dormancy — stale state is dangerous
- Orphaned agents should be shutdown or resumed, not left active
- If no Consolidation has ever run, recommend one before new work begins
- The briefing should be brief — orient, don't overwhelm
