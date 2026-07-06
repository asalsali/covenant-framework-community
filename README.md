# Covenant Framework

> A governance framework for multi-agent AI systems.

The Covenant Framework provides structure, lifecycle management, and quality controls for AI agent orchestration. It solves the coordination problems that emerge when multiple agents work together: who follows what rules, how they communicate, when they stop and reflect, and how the system recovers from failure.

The framework runs inside [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [OpenAI Codex CLI](https://github.com/openai/codex) with no external dependencies. Inspired by governance patterns from  institutional traditions, it treats those patterns as engineering architecture.

---

## Community vs Network

The Covenant Framework ships as an open-core project. The **Community Edition** is free and fully functional. The **Network Edition** adds advanced runtime enforcement for teams and production deployments.

| Capability | Community (Free) | Network (Paid) |
|---|:---:|:---:|
| Constitution (CLAUDE.md) | Full | Full |
| Agent definitions (all 12) | Yes | Yes |
| Core commands (16) | Yes | Yes |
| Advanced commands (+22) | -- | Yes |
| Agent gate hook | Yes | Yes |
| Token logging hook | Yes | Yes |
| Shutdown hook | Yes | Yes |
| Session checks hook | Yes | Yes |
| Input policy enforcement | -- | Yes |
| World model enforcement | -- | Yes |
| Health score computation | -- | Yes |
| Hotspot detection | -- | Yes |
| Compliance policy hook | -- | Yes |
| Notification hook | -- | Yes |
| Upgrade hook | -- | Yes |
| Trust registry | -- | Yes |
| Skills registry | -- | Yes |
| Tribes (domain system) | -- | Yes |
| Registry templates | Yes | Yes |

**The tier boundary is at the hook level, not the agent level.** Agent definitions are markdown files with zero runtime cost -- they all ship free. Hooks are runtime enforcement -- that is the paid value.

Install Community:
```bash
curl -sL https://raw.githubusercontent.com/asalsali/covenant-framework-community/main/install.sh | bash
```

Install Network (requires Covenant Network membership):
```bash
curl -sL https://raw.githubusercontent.com/asalsali/covenant-framework/master/install.sh | bash -s -- --tier network
```

---

## Quickstart

**Prerequisites:** [git](https://git-scm.com/), [Node.js](https://nodejs.org/) (v18+), and one of the runtimes below.

### 1. Install a runtime

Claude Code (reference implementation):
```bash
npm install -g @anthropic-ai/claude-code
```

OpenAI Codex CLI:
```bash
npm install -g @openai/codex
```

### 2. Install Covenant

**New project:**
```bash
git clone https://github.com/asalsali/covenant-framework-community.git my-project
cd my-project && claude
```

**Existing project (Claude Code):**
```bash
curl -sL https://raw.githubusercontent.com/asalsali/covenant-framework-community/main/install.sh | bash
```

**Existing project (Codex on Windows):**
```powershell
irm https://raw.githubusercontent.com/asalsali/covenant-framework-community/main/install-codex.ps1 | iex
```

**Existing project (Codex on macOS/Linux):**
```bash
curl -sL https://raw.githubusercontent.com/asalsali/covenant-framework-community/main/install.sh | bash -s -- --runtime codex
```

### 3. Start working

```
I want to build a REST API for user management
```

The Interpreter reads your request, checks system state, proposes a plan with specific agents, and waits for your approval. You say "go" and agents spawn, execute, write exit reports, and shut down. The system remembers what it learned for next time.

That is it. No configuration files to write, no SDK to learn, no dashboard to set up.

---

## Key concepts

- **Constitution** (`CLAUDE.md`) -- 36 sections of immutable rules every agent inherits. No mandate, user request, or child agent can override them.
- **Interpreter** -- The single agent that talks to you. It interprets your intent, proposes plans, spawns other agents, and routes all communication. Nothing executes until you approve.
- **Orientation** (`registry/orientation.json`) -- A shared state file every agent reads to stay aligned: current focus, what to protect, active temptations, where the project stands.
- **Agent lifecycle** -- Every agent follows the same arc: boot (Genesis Phase), execute its mandate, write an exit report, and shut down cleanly.
- **Distillation** -- Agents never pass raw context to each other. All information is summarized to mandate-relevant essentials before handoff.
- **Consolidation** -- Periodic pauses where no new agents spawn. The system distills memory, archives lineages, and measures progress toward the project goal.
- **Three spawn gates** -- Before any agent is created, the system checks for overlapping mandates (overlap detection), excessive complexity (scope validation), and prior learnings (memory retrieval).

---

## Architecture: three roles

| Role | What it does |
|---|---|
| **User** | Source of all mandates. Your intent clarifies over time through interaction (progressive discovery), not all at once upfront. |
| **Interpreter** | The single agent that speaks to you. Carries your authority while operating under the same constraints as every other agent. Can be wrong, can be uncertain, and knows when to stop and ask. |
| **Orientation** | A shared configuration file (`registry/orientation.json`) readable by every agent. Keeps the entire system aligned on current focus, risks, and project state. |

The Interpreter is the framework's central architectural choice. It is fully representative (speaks for you to the system) and fully bounded (follows the Constitution, has a context window, writes exit reports at shutdown like everyone else). When those two natures conflict, it signals the Uncertainty Protocol rather than guessing.

---

## Agent lifecycle

```
SPAWN
  Agent is registered in the agent registry.
  Three gates fire: overlap detection, scope validation, memory retrieval.
      |
      v
GENESIS PHASE (boot sequence)
  Read mandate, Constitution, Orientation, registry, prior exit reports, memos.
  Form a world model before taking any action.
      |
      v
EXECUTE
  Work within mandate boundaries.
  Communicate laterally via structured memos, upward via exit reports.
      |
      v
SHUTDOWN
  Write an exit report (structured JSON: findings, what worked, what failed, recommendations).
  Update status to archived in the agent registry.
  Notify parent. Do not linger.
```

Periodically, the system runs a **consolidation cycle**: no new agents spawn, no new tasks begin. The system distills memory, archives completed lineages, and measures progress toward the project goal.

---

## Agents

| Agent | Role |
|---|---|
| **Interpreter** | Interprets what you need. The only agent that talks to you directly. |
| **Analyst** | Researches and investigates. Produces findings, never final output. |
| **Writer** | Builds things -- code, docs, structured output. |
| **Synthesist** | Both research and output in one context. Expensive; used only when splitting would lose critical context. |
| **Guardian** | Audits system health. Detects Constitution violations. |
| **Shepherd** | Monitors for drift, quiet failures, stale state. Briefs the Interpreter when you return. |
| **Scribe** | Writes documentation about what exists. |
| **Stress Tester** | Stress-tests plans before execution. Finds weaknesses, proposes remedies. |
| **Futility Review** | Analyzes failures. Distinguishes execution errors from wrong goals. |
| **Goal Challenge** | The dissenting voice. Asks "should we be doing this at all?" when evidence warrants it. |
| **James** | Mediates when sibling agents disagree. Synthesizes observations without taking a side. |

---

## Commands (36)

| Category | Commands |
|---|---|
| **Spawning** | `/spawn`, `/synthesize` |
| **Observation** | `/agent-registry`, `/lineage`, `/tithe`, `/audit`, `/inherit`, `/remember`, `/territory` |
| **Planning** | `/foresee`, `/stress-test`, `/preflight`, `/covenant`, `/mediate`, `/assess` |
| **Communication** | `/memo` |
| **Lifecycle** | `/consolidation`, `/checkpoint`, `/binding`, `/fast`, `/acknowledge-loss`, `/retrospective` |
| **Integration** | `/welcome` |
| **Intervention** | `/descend`, `/reset`, `/reinit` |
| **Reconstruction** | `/nehemiah` |
| **Governance** | `/governance` |
| **Ambiguity** | `/daniel` |
| **Onboarding** | `/genesis` |
| **Compliance** | `/reconcile` |
| **Maintenance** | `/upgrade` |
| **System** | `/amend`, `/shadow`, `/judges`, `/compliance` |

---

## How the system handles failure

The framework has a graduated response to problems:

1. **Acknowledge** the loss before trying to fix it (`/acknowledge-loss`)
2. **Analyze** whether it was an execution error or a wrong goal (Futility Review)
3. **Challenge** the premise if the goal itself may be misguided (Goal Challenge)
4. **Abort** gracefully if the user says stop (`/binding` -- preserves partial work)
5. **Signal** when the system cannot proceed without your input (Uncertainty Protocol)
6. **Reset** as a last resort (`/reset` -- full reset with mandatory post-mortem)

---

## Project structure

```
covenant-framework/
  CLAUDE.md                          # The Constitution (33 sections)
  AGENTS.md                          # Compact Codex project instructions
  COMPLIANCE.md                      # Project-specific policy layer
  install.sh                         # Install into existing projects
  install-codex.ps1                  # Native Windows Codex installer
  .claude/
    agents/                          # 11 agent definitions
    commands/                        # 36 slash commands
    hooks/                           # 8 lifecycle hooks
    settings.json                    # Hook wiring
  .codex/
    agents/                          # Codex role definitions
    hooks/                           # Python hook adapter
    config.toml                      # Codex project config
  registry/
    agent-registry.json              # Agent registry (census of all agents)
    orientation.json                 # Shared orientation state
    baselines.json                   # Performance baselines
    quality-benchmarks.json          # Peak performance records
    dispositions.json                # Behavioral orientations
    trust-registry.json              # External tool trust levels
    skills.json                      # Demonstrated capabilities per agent type
  memory/
    user-model.json                  # Longitudinal user model
    semantic/                        # Consolidated learnings
    inheritance/                     # Exit reports from finished agents
    parables/                        # Case studies (teaching examples)
    epistles/                        # Structured memos between agents
    covenants/                       # Project agreements
    checkpoints/                     # State snapshots
```

---

## Extending the framework

**Add an agent:** Create `.claude/agents/<name>.md` with a description of when to use it and what tools it needs. See [CONTRIBUTING.md](CONTRIBUTING.md).

**Add a command:** Create `.claude/commands/<name>.md`.

**Add a hook:** Create `.claude/hooks/<name>.sh`, wire it in `settings.json`.

**Add Codex support:** Update `AGENTS.md`, `.codex/agents/*.toml`, or `.codex/hooks/covenant_hook.py`. Add reusable protocols under `.agents/skills/<name>/SKILL.md`. See [docs/CODEX.md](docs/CODEX.md).

---

## Covenant Model Suite

The framework's governance rules can be fine-tuned into model weights, eliminating long system prompts and making governance resistant to prompt injection.

**Open-source models:**

| Model | Base | Size (Q4) | Purpose |
|---|---|---|---|
| **Adam** | Qwen2.5-3B | ~1.8GB | Entry point. Fast local inference on any laptop. |
| **Eve** | Qwen2.5-7B | ~4.4GB | General-purpose governance. The default recommendation. |
| **Seth** | Llama 3.1-8B | ~4.8GB | Framework-agnostic proof -- same governance, different base. |

**Private models (Covenant Network):**

| Model | Base | Size (Q4) | Purpose |
|---|---|---|---|
| **Moses** | Qwen2.5-32B | ~19GB | Full Constitution internalized for serious deployments. |
| **Solomon** | Qwen2.5-14B | ~8GB | Edge cases, uncertainty handling, futility analysis patterns. |
| **Elijah** | DeepSeek-Coder-V2 16B | ~9GB | Code-specialized for production agentic deployments. |

Adam v1 proved the thesis: read-first behavior went from ~10% (bare model) to 100% (fine-tuned). The v2 pipeline uses 700 samples across 10 governance categories. Training notebooks are in `finetuning/`.

---

## Benchmark results

Terminal-Bench 2.0, 89 tasks: **67.4%** (no-retry), vs 42% for an ad-hoc prompted baseline on the same model. Constitution-derived rules beat ad-hoc prompting by 25 percentage points.

Full methodology and leaderboard comparison in [BENCHMARK-FINDINGS.md](BENCHMARK-FINDINGS.md).

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Hooks not firing | Check `settings.json` wiring. |
| Codex hooks not firing | Check `.codex/hooks.json`. Test with a JSON fixture on stdin. |
| Python not found | Hooks need `python3` or `python` on PATH. |
| Agent will not spawn | Run `/agent-registry` to check limits. Run `/audit` for a health check. |
| Something failed | `/acknowledge-loss` to acknowledge, then Futility Review to analyze. |
| Wrong goal? | Invoke Goal Challenge to challenge the premise. |
| Agents disagree | `/mediate` -- James mediates and writes a resolution. |
| External tool untrusted | `/welcome` to evaluate its trust level. |
| Back after time away | `/reinit` re-orients the system. Auto-triggers after 24h. |
| Need to stop | `/binding` preserves work. `/reset` resets everything. |

---

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI, desktop, or IDE extension) or OpenAI Codex CLI
- Python 3.x (for hooks)
- bash for Claude Code shell hooks (native on macOS/Linux, Git Bash on Windows). Codex hooks are Python-only.

---

## Documentation

- [System Model](docs/system-model.html) -- Interactive architecture diagram showing all 33 Constitution sections, 11 agent types, 8 hooks, and protocol flows.
- [Process Diagram](docs/PROCESS-DIAGRAM.md) -- How the system operates from session start through agent shutdown.
- [Benchmark Findings](BENCHMARK-FINDINGS.md) -- Terminal-Bench 2.0 results and methodology.
- [Glossary](docs/glossary.html) -- Plain-language definitions for every framework term.
- [Roadmap](ROADMAP.md) -- Upcoming work and integration plans.
- [Technical Paper (v2.0)](https://covenant.foundation/TheCovenantFramework.pdf) -- Whitepaper with benchmark evidence and governance primitives.

---

## License

Covenant is dual-licensed under the Covenant Public License v1.0.

- **Tier 1 (Public):** Free to use, modify, and distribute.
- **Tier 2 (Covenant Network):** Enhanced framework available exclusively to ventures onboarded into the Covenant Network via a Revenue Share Agreement with the Covenant Foundation.

See [LICENSE](./LICENSE) for full terms.
