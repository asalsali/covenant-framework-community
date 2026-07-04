<p align="center">
  <img src="assets/banner.png" alt="Covenant Framework" width="100%">
</p>

<h1 align="center">Covenant Framework</h1>

<p align="center">
  <strong>A governance framework for multi-agent AI systems.</strong>
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/covenant-framework"><img src="https://img.shields.io/npm/v/covenant-framework?style=flat-square&color=cb3837" alt="npm"></a>
  <a href="https://github.com/asalsali/covenant-framework-community/releases"><img src="https://img.shields.io/github/v/release/asalsali/covenant-framework-community?style=flat-square" alt="GitHub release"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-Covenant%20Public%20License-blue?style=flat-square" alt="License"></a>
  <a href="https://buymeacoffee.com/alexsalsali"><img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow?style=flat-square&logo=buy-me-a-coffee" alt="Buy Me A Coffee"></a>
</p>

<p align="center">
  Structure, lifecycle management, and quality controls for AI agent orchestration.<br>
  Runs inside <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a> or <a href="https://github.com/openai/codex">OpenAI Codex CLI</a> with no external dependencies.
</p>

---

## Install

```bash
npx covenant-framework init
```

Or with curl:

```bash
curl -sL https://raw.githubusercontent.com/asalsali/covenant-framework/master/install.sh | bash
```

Then start working:

```bash
claude
# "I want to build a REST API for user management"
```

The Interpreter reads your request, proposes a plan with specific agents, and waits for your approval. Agents spawn, execute, write exit reports, and shut down. The system remembers what it learned for next time. No configuration files to write, no SDK to learn.

---

## How it works

<table>
<tr><td width="33%">

### Three roles
The **User** provides intent. The **Interpreter** translates it into agent plans. The **Orientation** keeps every agent aligned on current focus, risks, and project state.

</td><td width="33%">

### Agent lifecycle
Every agent follows the same arc: register, boot (Genesis Phase), execute its mandate, write an exit report, and shut down cleanly.

</td><td width="33%">

### Spawn gates
Before any agent is created, the system checks for overlapping mandates, excessive complexity, and prior learnings. Nothing spawns blindly.

</td></tr>
</table>

---

## Agents

| Agent | Role |
|---|---|
| **Interpreter** | The only agent that talks to you. Interprets intent, proposes plans, routes communication. |
| **Analyst** | Researches and investigates. Produces findings, never final output. |
| **Writer** | Builds things -- code, docs, structured output. |
| **Executor** | Deploys and ships. Git push, build commands, production operations. |
| **Synthesist** | Research and output in one context. Used when splitting would lose critical context. |
| **Guardian** | Audits system health. Detects Constitution violations. |
| **Shepherd** | Monitors for drift, quiet failures, stale state. |
| **Scribe** | Documents what exists. |
| **Stress Tester** | Stress-tests plans before execution. Finds weaknesses, proposes remedies. |
| **Futility Review** | Analyzes failures. Distinguishes execution errors from wrong goals. |
| **Goal Challenge** | The dissenting voice. Asks "should we be doing this at all?" |
| **Mediator** | Mediates when sibling agents disagree. Synthesizes without taking a side. |

---

## Architecture

```
SPAWN ──> GENESIS PHASE ──> EXECUTE ──> SHUTDOWN
  │         Read mandate,      Work within       Write exit report.
  │         Constitution,      mandate            Archive. Notify
  │         Orientation,       boundaries.        parent. Do not
  │         prior learnings.                      linger.
  │
  └── Three gates fire: overlap detection,
      scope validation, memory retrieval.
```

Periodically, the system runs a **consolidation cycle**: no new agents spawn, no new tasks begin. The system distills memory, archives completed lineages, and measures progress toward the project goal.

---

## Commands

| Category | Commands |
|---|---|
| **Spawning** | `/spawn`, `/synthesize` |
| **Observation** | `/genealogy`, `/lineage`, `/tithe`, `/audit`, `/inherit`, `/remember` |
| **Planning** | `/foresee`, `/stress-test`, `/preflight`, `/mediate`, `/assess` |
| **Communication** | `/memo` |
| **Lifecycle** | `/consolidate`, `/checkpoint`, `/binding`, `/acknowledge-loss`, `/retrospective` |
| **Intervention** | `/descend`, `/reset`, `/reinit` |
| **Onboarding** | `/genesis` |
| **Governance** | `/governance`, `/compliance`, `/amend`, `/reconcile` |

---

## Failure handling

The framework has a graduated response to problems:

1. **Acknowledge** the loss before trying to fix it (`/acknowledge-loss`)
2. **Analyze** whether it was an execution error or a wrong goal (Futility Review)
3. **Challenge** the premise if the goal itself may be misguided (Goal Challenge)
4. **Abort** gracefully if the user says stop (`/binding` -- preserves partial work)
5. **Signal** when the system cannot proceed without your input (Uncertainty Protocol)
6. **Reset** as a last resort (`/reset` -- full reset with mandatory post-mortem)

---

## Community vs Network

The Covenant Framework ships as an open-core project. The **Community Edition** is free and fully functional. The **Network Edition** adds advanced runtime enforcement for teams and production deployments.

| Capability | Community | Network |
|---|:---:|:---:|
| Constitution (all 36 sections) | Yes | Yes |
| Agent definitions (all 12) | Yes | Yes |
| Core hooks (4) | Yes | Yes |
| Advanced hooks (+9) | -- | Yes |
| Core commands (16) | Yes | Yes |
| Advanced commands (+22) | -- | Yes |
| Input policy enforcement | -- | Yes |
| World model enforcement | -- | Yes |
| Health scoring | -- | Yes |
| Hotspot detection | -- | Yes |
| Progressive trust | -- | Yes |
| Domain system (tribes) | -- | Yes |

**The tier boundary is at the hook level, not the agent level.** Agent definitions are markdown files with zero runtime cost -- they all ship free. Hooks are runtime enforcement -- that is the paid value.

---

## Project structure

```
covenant-framework/
  CLAUDE.md                 # The Constitution (36 sections)
  COMPLIANCE.md             # Project-specific policy layer
  install.sh                # Install into existing projects
  .claude/
    agents/                 # 12 agent definitions
    commands/               # 16 slash commands (community)
    hooks/                  # 4 lifecycle hooks (community)
    settings.json           # Hook wiring
  registry/
    agent-registry.json     # Census of all agents
    orientation.json        # Shared orientation state
  memory/
    inheritance/            # Exit reports from finished agents
    semantic/               # Consolidated learnings
    memos/                  # Structured memos between agents
    covenants/              # Project agreements
    checkpoints/            # State snapshots
```

---

## Extending

**Add an agent:** Create `.claude/agents/<name>.md` with a description of when to use it and what tools it needs.

**Add a command:** Create `.claude/commands/<name>.md`.

**Add a hook:** Create `.claude/hooks/<name>.sh`, wire it in `settings.json`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI, desktop, or IDE extension) or [OpenAI Codex CLI](https://github.com/openai/codex)
- Python 3.x (for hooks)
- bash (native on macOS/Linux, Git Bash on Windows)

---

## License

Dual-licensed under the [Covenant Public License v1.0](./LICENSE).

- **Tier 1 (Public):** Free to use, modify, and distribute.
- **Tier 2 (Covenant Network):** Advanced enforcement available via the [Covenant Network](https://covenant.foundation/network).

---

<p align="center">
  <a href="https://covenant.foundation">covenant.foundation</a> &nbsp;&middot;&nbsp;
  <a href="https://buymeacoffee.com/alexsalsali">Buy Me a Coffee</a> &nbsp;&middot;&nbsp;
  <a href="https://github.com/sponsors/asalsali">Sponsor</a>
</p>
