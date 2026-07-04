---
name: remember
description: Search long-horizon memory for relevant prior learnings. Memory Retrieval's gift — dormant wisdom made accessible. Usage: /remember <query>
---

# Remember — Memory Retrieval's Long-Horizon Memory

> "Memory Retrieval stored up grain during the seven years of abundance...
> and when the famine came, Memory Retrieval opened the domain memorys." — Genesis 41

Search accumulated wisdom across all memory stores for learnings
relevant to the current mandate or query.

## Why This Exists

Every new mandate currently starts from scratch — agents only read current
handoff. But `memory/semantic/` contains consolidated Consolidation learnings,
`memory/handoff/` contains agent findings, and `memory/case studies/` contains
teaching examples. Memory Retrieval makes all dormant wisdom accessible before new work begins.

## Steps

### 1. Gather the Query

If `$ARGUMENTS` is provided, use it as the search query.
If empty, use the current mandate or spawn plan context.

### 2. Search All Memory Stores

Read and scan for relevance:

- `memory/semantic/*.md` — Consolidation consolidations (highest value)
- `memory/handoff/*.md` — archived agent learnings
- `memory/case studies/*.md` — teaching examples
- `memory/covenants/*.md` — project covenants (if any exist)
- `memory/memos/*.md` — unread lateral messages

For each file, assess: does this contain information relevant to the query?

### 3. Distill and Present

```
JOSEPH'S STOREHOUSES — MEMORY RETRIEVAL
════════════════════════════════════════

Query: [the search query]

RELEVANT FINDINGS
────────────────────────────────────────
[For each relevant memory, ordered by relevance:]

  Source: [filename]
  Type: [semantic / handoff / case study / covenant / memo]
  Summary: [2-3 line distillation of what's relevant]
  Applicability: [how this applies to the current mandate]

────────────────────────────────────────

TOTAL: [N] relevant memories found across [N] stores.

[If nothing found:]
The domain memorys are empty for this query.
No prior wisdom applies — this mandate enters unexplored territory.
════════════════════════════════════════
```

### 4. Token Discipline

Memory retrieval is inherently expensive — you're scanning many files.
- Read file names and first 5 lines before reading full files
- Stop searching a store once you've found 3+ relevant entries
- Never read more than 20 files total

## When This Fires Automatically

The `/spawn` and `/synthesize` commands run a Memory Retrieval Phase before
registration — automatically searching for relevant prior learnings
about the proposed mandate. You can also invoke `/remember` directly
at any time.
