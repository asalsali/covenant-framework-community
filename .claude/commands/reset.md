---
name: flood
description: Full system reset — archive everything, clear the registry, write a mandatory post-mortem with rainbow covenant. Noah's flood. Last resort after Brief Correction and Direct Inhabitation fail.
---

# Hard Reset — The Reset Protocol

> "I am going to bring floodwaters on the earth to destroy every living
> creature under the heavens. But I will establish my covenant with you." — Genesis 6:17-18

The nuclear option. Everything stops. Everything is archived.
Only used when Brief Correction and Direct Inhabitation have both failed.

## Pre-Hard Reset Requirements

1. **Confirm this is necessary:**
```
FLOOD WARNING
═══════════════���════════════════════════
This will:
  - Archive ALL active agents
  - Reset the agent registry to root only
  - Clear orientation.json
  - Preserve all memory and handoff

Have you tried:
  /descend brief-correction  — brief correction?
  /descend inhabitation — extended inhabitation?

A flood destroys what Brief Correction and Direct Inhabitation could not fix.

Proceed? (yes / step back)
════════════════════════════════════════
```

2. **Run /checkpoint first** — checkpoint before destruction.

3. **Select the Ark** — the user chooses up to 3 learnings to carry forward
   explicitly. These are marked as "ark" items and given priority in the
   next cycle's memory.

## The Hard Reset

1. Mark ALL active agents as `archived` in `registry/agent-registry.json`
2. Reset orientation.json to empty state
3. Preserve all `memory/` contents (handoff, semantic, memos, covenants)

## The Rainbow Covenant

Write a mandatory post-mortem to `memory/semantic/reset-<YYYY-MM-DD>.md`:

```markdown
# Rainbow Covenant — Post-Hard Reset Record

## Date: <ISO timestamp>
## Hard Reset Number: <N> (from agent-registry.json flood count)

## Why the Hard Reset Was Necessary
[What drifted beyond correction — be specific]

## What Was Preserved (The Ark)
1. [User-selected learning 1]
2. [User-selected learning 2]
3. [User-selected learning 3]

## What Was Lost
[Mandates that were incomplete, agents mid-execution]

## The Covenant — What Will Be Done Differently
[Specific commitments about what changes in the next cycle]
[These are binding — the next Interpreter must read this before acting]

## The Promise
The system will not flood again for the same reason.
If this pattern recurs, the root cause was not addressed here.
```

## Post-Hard Reset

1. Increment `floodCount` in `registry/agent-registry.json`
2. Announce:

```
THE WATERS RECEDE
════════════════════════════════════════
All agents archived. Orientation cleared.
Rainbow covenant: memory/semantic/reset-<date>.md
Checkpoint: memory/checkpoints/<timestamp>.json
Ark items: <3 learnings carried forward>
Hard Reset count: <N>

The system is empty but not erased.
The covenant has been written.
Begin again with the Interpreter.
════════════════════════════════════════
```

## Notes

- The flood is irreversible for the current cycle
- All memory persists — only the active agent tree is cleared
- The rainbow covenant is mandatory — no flood without a post-mortem
- The next Interpreter that activates MUST read the rainbow covenant first
- The ark items get priority loading in the next cycle's Memory Retrieval phase
