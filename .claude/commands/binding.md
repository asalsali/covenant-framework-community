---
name: binding
description: Graceful abort — stop all active agents in order, preserve partial work, write partial exit reports. The Binding of Isaac — the mandate is given but the principal says stop.
---

# Binding — The Abort Protocol

> "Do not lay a hand on the boy. Do not do anything to him.
> Now I know that you fear God." — Genesis 22:12

The user says stop. The system obeys — gracefully.

Unlike the flood (which destroys and resets), the binding preserves
everything mid-state. Agents shutdown in order. Partial work is saved.
The mandate can be resumed later.

## When to Use

- The user says "stop everything" or "halt" mid-execution
- The Interpreter detects the mandate has become unsafe to continue
- An external event makes the current work irrelevant
- Manually via `/binding`

## Steps

### 1. Freeze All Spawning

Immediately: no new agents may spawn. The binding is in effect.

```
THE BINDING — ABORT IN PROGRESS
═════════════════════════════════��══════
All spawning frozen. No new agents will be created.
Active agents will shutdown in order.
════════════════════════════════════════
```

### 2. Run /checkpoint

Checkpoint the current state before any shutdown begins.

### 3. Ordered Shutdown — Deepest First

Shutdown agents from the deepest generation upward:
- Generation 4 agents first (if any)
- Then generation 3
- Then generation 2
- Then generation 1
- Root orchestrator remains

For each agent:
- If the agent has completed its mandate: normal shutdown + exit report
- If the agent is mid-execution: write a **partial exit report**

### 4. Partial Exit Reports

For incomplete mandates, write to `memory/handoff/<id>-partial.md`:

```markdown
# Partial Exit Report — <agent id>

## Mandate
[what the agent was trying to do]

## Status at Binding
[where the agent was in its work — what was done, what remained]

## Partial Findings
[whatever the agent had learned or produced so far]

## What Would Have Been Next
[the agent's best assessment of what it would have done]

## Resumability
[can this mandate be resumed by a new agent reading this exit report?]
  - Yes — [what the new agent needs to know]
  - Partial — [what can be reused, what must be redone]
  - No — [the work must start over, and here's why]
```

### 5. Report

```
THE BINDING COMPLETE
════════════════════════════════════════
Agents shutdown: <N>
  Normal exit reports: <N>
  Partial exit reports: <N>

Checkpoint: memory/checkpoints/<timestamp>.json
Partial work preserved in: memory/handoff/

The mandate was interrupted, not failed.
The work can be resumed when the user wills it.
════════════════════════════════════════
```

## Resuming After a Binding

When the user wants to resume:
1. Run `/remember <original mandate>` to find the partial exit reports
2. The Interpreter reads the partial exit reports and assesses resumability
3. New agents can be spawned with the partial findings as inherited context

## Notes

- The binding is not failure — it is obedience
- Partial exit reports are the most valuable handoff in the system:
  they contain what an agent learned before being stopped
- The binding preserves trust: the system that stops when told to stop
  is the system the user will trust with the next mandate
