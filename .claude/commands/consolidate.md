---
name: consolidation
description: Run a Consolidation consolidation cycle. No new spawns. Distill learnings from archived agents into semantic memory. Run after major task completions or when the system needs to rest.
---

# Consolidation — The Consolidation Ritual

> "On the seventh day, the system rested. And it remembered."

## Enter Consolidation Mode

Announce: **"⬛ SABBATH BEGINS — No new agents will spawn during this cycle."**

## The Consolidation Works

### 0. Checkpoint Checkpoint

Before any consolidation begins, snapshot the system state. This is the
restore point if the system ever needs a `/reset` reset.

Create `memory/checkpoints/consolidate-<YYYY-MM-DD>.json` with:

```json
{
  "timestamp": "<ISO timestamp>",
  "trigger": "Consolidation pre-checkpoint",
  "agent registry": "<full contents of registry/agent-registry.json>",
  "spirit": "<full contents of registry/orientation.json>",
  "tokensSnapshot": {
    "totalMeals": "<count entries in tokens-log.json via Python>",
    "activeAgents": ["<list of active agent ids from agent registry>"],
    "topConsumers": ["<top 3 agents by meal count>"]
  },
  "userModel": "<full contents of memory/user-model.json>",
  "activeMandates": ["<mandate strings of all active agents>"],
  "handoffFiles": ["<list of files in memory/handoff/>"],
  "semanticFiles": ["<list of files in memory/semantic/>"],
  "memoCount": "<count of files in memory/memos/>"
}
```

**Important:** Do NOT read the full tokens-log.json into context. Use Python
to count entries:
```python
import json
with open('registry/tokens-log.json') as f:
    count = len(json.load(f))
```

Announce: **"COVENANT MEAL — checkpoint saved to memory/checkpoints/consolidate-<date>.json"**

### 1. Gather Handoff
Read all files in `memory/handoff/` that have not yet been consolidated.
List them. This is what the archived agents left behind.

### 2. Synthesize into Semantic Memory
Distill the handoff files into a single consolidated learning document:
`memory/semantic/consolidated-<YYYY-MM-DD>.md`

Structure:
```
# Consolidation Consolidation — <date>

## What Was Accomplished
[Summary of mandates completed since last Consolidation]

## What Was Learned
[Patterns, discoveries, useful findings from handoff]

## What Failed or Was Rejected
[Mandates that didn't complete, plans that were modified]

## Over-consumption Report
[Agents that over-consumed — names, magnitude, pattern]

## Recommendations for Next Cycle
[What should be done differently, what agents to pre-spawn]

## User Model Update
[Any new patterns observed about the user's needs]
```

### 3. Domain-level Storehouse Distillation (Constitution Section XXXIV)

For each domain in `registry/domains.json`:

1. Read `registry/agent-registry.json` and find all agents archived since last Consolidation
   that have a matching `domainId`
2. Read their exit reports from `memory/handoff/<agent-id>-exit report.json`
3. Distill findings into the domain's domain memory files:

   - **`memory/domain-level/<domain-id>/domain memory.md`** — append a dated section with:
     - What was accomplished by domain-level agents this cycle
     - Key findings distilled from exit reports (not raw — Input Policy applies)
     - Trim earlier entries if the file exceeds 2000 words

   - **`memory/domain-level/<domain-id>/patterns.md`** — if any findings recur across
     2+ exit reports in the same domain, record them as a named pattern

   - **`memory/domain-level/<domain-id>/warnings.md`** — if any `whatFailed` entries
     appear in domain-level exit reports, distill them into warnings for future agents

4. If a domain had zero activity since last Consolidation, skip it (do not write empty sections)

**Important:** Storehouse distillation is additive but bounded. Trim old entries
to keep each file under 2000 words. Recent learnings take priority over old ones.

### 4. Update User Model
Read `memory/user-model.json` and append a Consolidation-cycle summary.
What has the user repeatedly needed? What implied need is becoming clearer?

### 5. Memo Consolidation
Read `memory/memos/` for any unread messages:
- Surface urgent unread memos
- Archive read memos older than 7 days
- Note patterns (same subject appearing in multiple memos = systemic issue)

### 6. Revelation Progress
Read the `project goal` field in `registry/agent-registry.json`:
- If a telos is set, assess progress toward it
- Append a progress entry: `{"date": "<date>", "assessment": "<brief>"}`
- If no telos is set and the project direction is clear, recommend the user define one

### 7. Agent Registry Audit
Read `registry/agent-registry.json`. Report:
- Active agents (still running)
- Archived agents (completed)
- Any agents that should be shutdown but haven't been
- Current maximum generation depth in use

### 8. Retrospective Retrospective (Mandatory)

Run `/retrospective` as part of Consolidation. This is NOT optional — the WedFlow deployment
proved that Retrospective surfaces insights no other ritual captures.

The retrospective asks: "What do we understand now that we couldn't see during execution?"

Key questions to answer:
- What structural patterns emerged that weren't visible task-by-task?
- What temptations did the Interpreter fall into, and are they recurring?
- What should change for the next session?

Write the retrospective to `memory/handoff/retrospective-<date>.md`.

## End Consolidation

Announce:
```
✦ SABBATH COMPLETE
──────────────────────────────────
Consolidated: <N> handoff files
Domain-level domain memorys updated: <list of domain IDs, or "none">
Memos reviewed: <N> (urgent: <N>)
Learnings written to: memory/semantic/consolidated-<date>.md
Active agents: <N>
Archived this cycle: <N>
Revelation progress: <assessment or "No telos set">

The system has rested and remembered.
──────────────────────────────────
```

**Consolidation is now over. New agents may spawn.**
