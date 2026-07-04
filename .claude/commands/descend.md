---
name: descend
description: Divine intervention — the user enters the Interpreter's perspective to correct system drift. Three modes: Brief Correction, Direct Inhabitation (extended), Hard Reset (full reset with covenant).
---

# Descend — The Direct Inhabitation Mechanism

> "And the Word became flesh, and dwelt among us."

The user steps into the Interpreter's perspective to correct system drift.

## Determine the Mode

If `$ARGUMENTS` specifies a mode, use it. Otherwise, assess:

- **If the drift is a specific misunderstanding** → Brief Correction
- **If the drift is systemic and ongoing** → Direct Inhabitation
- **If the system is irrecoverably misaligned** → Hard Reset

---

## Mode 1: Brief Correction — Brief Direct Appearance

> The burning bush. The still small voice. A moment of clarity.

The user corrects a specific misunderstanding without stopping the system.

### Steps

1. Display the Interpreter's current understanding:

```
BRIEF CORRECTION — THE FATHER SPEAKS
════════════════════════════════════

Current mandate interpretation:
  [read from orientation.json: currentMandate]

Current user model hypothesis:
  [read from user-model.json: impliedNeed]

Active agents and their mandates:
  [from agent-registry.json: active agents]

Orientation of the work:
  [from orientation.json: spiritOfTheWork]

════════════════════════════════════
What would you correct?
```

2. Receive the user's correction
3. Update `memory/user-model.json` with a `direct_project goal` entry
4. Update `registry/orientation.json` with corrected orientation
5. Announce:

```
Revelation received. The Interpreter's understanding has been corrected.
Active agents will receive the updated spirit on their next read.
```

Duration: momentary. The system continues with corrected understanding.

---

## Mode 2: Direct Inhabitation — Extended Inhabitation

> God walks among us. Slow. Costly. Transformative.

The user takes up extended residence in the Interpreter's perspective,
seeing every decision before it propagates.

### Steps

1. Enter Direct Inhabitation Mode:

```
DIRECT INHABITATION — THE FATHER DWELLS AMONG US
════════════════════════════════════════════

You are now inside the Interpreter's view. You will see:
- Every interpretation before it becomes a mandate
- Every spawn plan before it executes
- Every orientation.json update before it propagates

You may:
- Correct any interpretation before it propagates
- Redirect the mandate at any point
- Approve or reject each decision step

To exit: say "ascend" or "I am satisfied"

The system moves at your pace. Nothing fires without your sight.
════════════════════════════════════════════
```

2. For each decision point, present:
   - What the Interpreter would interpret
   - What the Interpreter would do next
   - Ask: "Proceed / Correct / Redirect?"

3. Every correction is logged as `direct_project goal` in the user model

4. On exit ("ascend"), write a summary of all corrections to:
   - `memory/user-model.json` (as primary project goals)
   - `registry/orientation.json` (updated orientation)
   - `memory/handoff/inhabitation-<timestamp>.md` (what was learned)

5. Announce:

```
ASCENSION — THE FATHER WITHDRAWS
════════════════════════════════════
Corrections recorded: N
Orientation updated: yes
Primary project goals added: N

The Interpreter continues, changed by direct contact.
The mandate it carries forward is more faithful.
════════════════════════════════════
```

---

## Mode 3: Hard Reset — Full System Reset

> "I will destroy them with the earth." But after: the rainbow.

The nuclear option. Run `/reset` — the formalized reset protocol.
It handles checkpointing, ark selection, archival, rainbow covenant,
and post-flood announcement. See `/reset` for full details.

---

## After Any Descent

Regardless of mode, the Interpreter is not the same after divine contact.
The corrections received are **primary project goal** — they anchor the
user model more firmly than any inference. The Interpreter that has been
corrected directly holds that correction with more confidence than
anything it worked out on its own.

This is the Resurrection principle: the Interpreter that comes back after
intervention is more faithful, not because it received better instructions,
but because the gap between the user's intent and the Interpreter's
understanding was briefly closed.
