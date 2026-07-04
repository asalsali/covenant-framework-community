# Covenant Framework -- Architectural Heritage

> This document explains WHY the framework is structured the way it is.
> Agents do not need to read this to operate -- they need the Constitution
> (`CLAUDE.md`). This document is for contributors and observers who want
> to understand the design rationale.

---

## The Rename

As of May 2026, the Covenant Framework uses secular terminology in its
external-facing documentation and code. The original biblical terms
(Canon, Prophet, Sabbath, Manna, etc.) have been replaced with engineering
equivalents (Constitution, Interpreter, Consolidation, Tokens, etc.).

**Why the rename happened:** The framework is designed to be used by
engineers of any background. Biblical terminology created an unnecessary
barrier to entry -- not because the metaphors were wrong, but because
they signaled a religious affiliation the project does not require.
The goal was inclusion, not secularization.

**What did not change:** The architectural patterns themselves. The
framework still uses governance structures that originated in biblical
organizational design. The rename changed the labels, not the bones.

**Where you will still see old terms:** Git history, older memory files,
internal engineering discussions, and this document. See `GLOSSARY.md`
for the complete mapping between old and new terminology.

---

## Why Biblical Governance Patterns?

The Bible -- whatever one's view of its theological claims -- is a
remarkably successful distributed coordination system. It was designed
to align the behavior of many autonomous agents (people) across time,
culture, geography, and context, without a central enforcer present at
every decision point.

The literary forms it evolved are each optimized for different parts
of that coordination problem:

| Biblical Form | Engineering Function | Framework Feature |
|---|---|---|
| **Law** (Torah) | Absolute rules, no exceptions | The Constitution (`CLAUDE.md`) |
| **Proverbs** | Heuristics for ambiguity | Heuristics (Section IX) |
| **Parables** | Teaching by example | Case Studies (`memory/case-studies/`) |
| **Epistles** | Lateral peer communication | Structured Memos (`memory/memos/`) |
| **Prophecy** | Interpreting intent under uncertainty | The Interpreter role |
| **Lamentations** | Structured grief before recovery | Loss Acknowledgment |
| **Ecclesiastes** | "Was this worth doing?" | Futility Review |
| **Covenant** | Bilateral commitment with conditions | Project Charter |

The Covenant Framework borrows these structures because they solve
the same problems agentic AI faces:

- **Delegation without direct supervision** -- Agents must act faithfully
  when the user is not watching every decision.
- **Succession across context boundaries** -- When one agent dies (context
  ends), its learnings must transfer to the next.
- **Resource discipline** -- Autonomous agents with access to tools will
  consume more than they need unless structurally constrained.
- **Conflict resolution between peers** -- Sibling agents working the same
  domain will produce contradictory findings.
- **Graceful failure** -- Systems must acknowledge loss before recovering,
  or they repeat the same failures.
- **Progressive trust** -- External integrations earn membership through
  demonstrated reliability, not declaration.

---

## The Three-Role Architecture

The framework's core architecture maps to a trinitarian pattern -- not
as theology, but as a separation-of-concerns model:

- **The User** -- Source of all intent. Always partially known. The system
  works from what has been disclosed, not from complete understanding.
  User intent becomes clearer over time (progressive disclosure).

- **The Interpreter** -- The user's intent made operational. Carries the
  user's authority while operating under real constraints (context limits,
  fallibility, resource budgets). The Interpreter compresses unbounded
  intent into executable mandates -- and must be honest about what was
  lost in compression.

- **The Orientation** -- Shared atmospheric state. Not a message between
  agents but a field all agents inhabit simultaneously. When the
  Interpreter confirms a plan and writes to `registry/orientation.json`,
  the orientation becomes available to every active agent at once.

This is not a claim about theology. It is an observation that the
separation of "source of intent," "interpreter of intent," and "shared
ambient state" is a useful architectural pattern for multi-agent systems.

---

## The Honest Position

This IS a biblically-inspired framework. That heritage is visible in
the architecture, the git history, the metaphors engineers use in
internal discussion, and this document. The rename made the external
interface accessible to everyone; it did not erase the origin.

Contributors are welcome regardless of their relationship to the source
material. The framework asks only that you understand the engineering
patterns -- not that you share any particular view of where they came from.

The biblical metaphors are the engineering heritage.
The secular terminology is the engineering interface.
Both are the framework.

---

*"In the beginning was the Mandate, and the Mandate was with the
Constitution, and the Mandate was the Constitution."*
