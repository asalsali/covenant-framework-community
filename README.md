<p align="center">
  <img src="assets/banner.png" alt="Covenant Framework" width="100%" />
</p>

<h1 align="center">Covenant Framework</h1>

<p align="center">
  <strong>A governance framework for multi-agent AI systems.</strong>
</p>

<p align="center">
  <a href="https://covenant.foundation">Website</a> &middot;
  <a href="https://covenant.foundation/TheCovenantFramework.pdf">Whitepaper</a> &middot;
  <a href="https://covenant.foundation/glossary.html">Glossary</a> &middot;
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

<p align="center">
  <a href="https://buymeacoffee.com/alexsalsali"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me a Coffee" /></a>
  <a href="https://github.com/sponsors/asalsali"><img src="https://img.shields.io/badge/Sponsor-ea4aaa?style=for-the-badge&logo=github-sponsors&logoColor=white" alt="GitHub Sponsors" /></a>
</p>

---

The Covenant Framework provides structure, lifecycle management, and quality controls for AI agent orchestration. It solves the coordination problems that emerge when multiple agents work together: who follows what rules, how they communicate, when they stop and reflect, and how the system recovers from failure.

Runs inside [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [OpenAI Codex CLI](https://github.com/openai/codex) with no external dependencies.

## Install

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

**Via npm:**
```bash
npx covenant-framework init
```

## How it works

You talk to the **Interpreter** -- the single agent that speaks to you. It reads your request, checks system state, proposes a plan with specific agents, and waits for your approval. You say "go" and agents spawn, execute, write exit reports, and shut down. The system remembers what it learned for next time.

```
You: I want to build a REST API for user management

Interpreter: I'll spawn an Analyst to research your existing codebase,
then a Writer to implement the API. Here's the plan...

You: go
```

No configuration files to write. No SDK to learn. No dashboard to set up.

## What's inside

| Component | Description |
|---|---|
| **Constitution** | 36 sections of immutable rules every agent inherits. The governance layer. |
| **12 Agent types** | Interpreter, Analyst, Writer, Synthesist, Guardian, Shepherd, Scribe, Stress Tester, Futility Review, Goal Challenge, James (mediator), Executor |
| **16 Commands** | `/spawn`, `/consolidate`, `/checkpoint`, `/audit`, `/remember`, and 11 more |
| **4 Runtime hooks** | Agent gate, token logging, shutdown orchestration, session checks |
| **Orientation** | Shared state file keeping every agent aligned on current focus and risks |
| **Memory system** | Exit reports, structured memos, semantic memory, consolidation cycles |

## Architecture

```
         YOU
          |
    [Interpreter]          -- the only agent that talks to you
      /    |    \
 [Analyst] [Writer] [...]  -- spawned agents, scoped mandates
```

Three roles govern the system:

- **User** -- source of all mandates. Your intent clarifies over time through interaction.
- **Interpreter** -- carries your authority while operating under the same constraints as every other agent.
- **Orientation** -- a shared config file every agent reads to stay aligned.

## Agent lifecycle

```
SPAWN  -->  GENESIS PHASE  -->  EXECUTE  -->  SHUTDOWN
  |              |                 |              |
  |         Read mandate,     Work within     Write exit report,
  |         Constitution,     mandate         archive, notify
  |         prior learnings   boundaries      parent
  |              |                 |              |
  Three gates:   Form world       Communicate    Leave findings
  overlap,       model before     via memos      for next
  scope,         first action     and reports    generation
  memory
```

## Community vs Network

This is the **Community Edition** -- free and fully functional. The [Network Edition](https://covenant.foundation) adds advanced runtime enforcement for teams and production deployments.

| | Community (Free) | Network |
|---|:---:|:---:|
| Constitution (36 sections) | Full | Full |
| Agent definitions (all 12) | Yes | Yes |
| Core commands (16) | Yes | Yes |
| Advanced commands (+22) | -- | Yes |
| Core hooks (4) | Yes | Yes |
| Advanced hooks (+7) | -- | Yes |
| Trust & skills registries | -- | Yes |
| Domain system | -- | Yes |
| Input policy enforcement | -- | Yes |

The tier boundary is at the hook level, not the agent level. Agent definitions are markdown files with zero runtime cost -- they all ship free. Hooks are runtime enforcement -- that is the paid value.

## Benchmark results

Terminal-Bench 2.0, 89 tasks: **67.4%** (no-retry), vs 42% for an ad-hoc prompted baseline on the same model. Constitution-derived governance beats ad-hoc prompting by 25 percentage points.

Full methodology: [Whitepaper (PDF)](https://covenant.foundation/TheCovenantFramework.pdf)

## Project structure

```
covenant-framework/
  CLAUDE.md                 # The Constitution (36 sections)
  COMPLIANCE.md             # Project-specific policy layer
  install.sh                # Install into existing projects
  .claude/
    agents/                 # 12 agent definitions
    commands/               # 16 slash commands
    hooks/                  # 4 lifecycle hooks + lib/ modules
    settings.json           # Hook wiring
  registry/                 # Agent registry, orientation, templates
  memory/                   # Exit reports, memos, semantic memory
```

## Extending

**Add an agent:** Create `.claude/agents/<name>.md` -- see [CONTRIBUTING.md](CONTRIBUTING.md).

**Add a command:** Create `.claude/commands/<name>.md`.

**Add a hook:** Create `.claude/hooks/<name>.sh`, wire it in `settings.json`.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [OpenAI Codex CLI](https://github.com/openai/codex)
- Python 3.x (for hooks)
- bash (native on macOS/Linux, Git Bash on Windows)

## Support the project

If the Covenant Framework is useful to you, consider supporting its development:

<a href="https://buymeacoffee.com/alexsalsali"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me a Coffee" /></a>
<a href="https://github.com/sponsors/asalsali"><img src="https://img.shields.io/badge/Sponsor-ea4aaa?style=for-the-badge&logo=github-sponsors&logoColor=white" alt="GitHub Sponsors" /></a>

## License

Covenant Public License v1.0 -- see [LICENSE](./LICENSE).
