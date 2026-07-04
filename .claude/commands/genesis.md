---
name: genesis
description: First-run onboarding. Detects an empty project and walks you through setting a project goal, writing the first orientation.json, and running your first spawn. The entry point that isn't reading 800 lines of Constitution.
---

# Genesis — First-Run Onboarding

> "In the beginning..." — Genesis 1:1

This command detects a fresh Covenant Framework installation and walks
you through the first three acts: naming your project, setting a goal,
and running your first agent.

## When to Trigger

Automatically on the Interpreter's first interaction if ALL of these are true:
- `memory/user-model.json` has no interactions
- `registry/agent-registry.json` has only the root agent
- `registry/orientation.json` has null currentMandate

Or manually via `/genesis`.

## The Three Acts

### Act 1: Name the Work

```
GENESIS — THE BEGINNING
════════════════════════════════════════

Welcome to the Covenant Framework.

Before anything runs, let's set the foundation.

What is this project? (one sentence)
> [user responds]

════════════════════════════════════════
```

Take the user's response and write it to `registry/orientation.json`:
- `currentMandate` — their answer
- `spiritOfTheWork` — infer from their description
- `whereWeAre` — "Genesis. The first mandate."

### Act 2: Set the Revelation

```
What does success look like for this project?
Not a task list — the condition that means you're done.
> [user responds, or "I don't know yet" which is fine]
```

If they provide a telos, write it to `registry/agent-registry.json`
`project goal.telos`. If they don't know yet, that's honest — set
`telos: null` and note "project goal deferred — will be set when
direction becomes clear."

### Act 3: First Spawn

```
GENESIS COMPLETE
════════════════════════════════════════

Project: [their description]
Revelation: [their telos, or "to be determined"]
Orientation: written

The framework is active. Here's what you can do:

  Just talk to me — I'll interpret what you need
  and propose a plan before anything executes.

  Or try one of these:
    /covenant  — formal project agreement (for big projects)
    /audit     — system health check
    /agent registry — see the agent tree

What would you like to build first?
════════════════════════════════════════
```

Update `memory/user-model.json` with the first interaction:
```json
{
  "timestamp": "<ISO>",
  "type": "genesis",
  "statedRequest": "<their project description>",
  "interpretedNeed": "<your interpretation>",
  "patternsObserved": ["first interaction"],
  "impliedNeed": "<inferred from description>",
  "confirmedPlan": true
}
```

## Notes

- Genesis takes 60 seconds. It replaces "read CLAUDE.md and figure
  it out" with "answer two questions and start working."
- The orientation.json it writes gives every subsequent agent orientation
  before they act — this is Commissioning happening at project inception
  rather than at the first spawn plan.
- If the user runs /genesis on a project that already has state,
  warn them: "This project already has history. Did you mean /reinit
  (re-initialize) or /reset (full reset)?"
