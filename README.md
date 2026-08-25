<p align="center">
  <img src="assets/banner.png" alt="Covenant Framework" width="100%%" />
</p>

<h1 align="center">Covenant Framework</h1>

<p align="center">
  <strong>A governance framework for multi-agent AI systems.</strong>
</p>

---

The Covenant Framework provides structure, lifecycle management, and quality controls for AI agent orchestration. It solves the coordination problems that emerge when multiple agents work together: who follows what rules, how they communicate, when they stop and reflect, and how the system recovers from failure.

Runs inside Claude Code or OpenAI Codex CLI with no external dependencies.

## Quick Start

The fastest path -- describe what you want, get a governed project:

```bash
pip install covenant-cli
covenant create "A research app that searches papers and writes reviews"
```

This scaffolds a complete project with real agent code, typed I/O, exit reports, and memory inheritance.

**Or install the framework directly:**

```bash
# New project
git clone https://github.com/asalsali/covenant-framework-community.git my-project
cd my-project && claude

# Existing project (Claude Code)
curl -sL https://raw.githubusercontent.com/asalsali/covenant-framework-community/main/install.sh | bash

# Via npm
npm i covenant-framework
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

## The Covenant Ecosystem

The framework is the governance layer. These tools build on top of it:

| Project | What it does | Install |
|---|---|---|
| **covenant-cli** | Scaffold governed apps from a description. Exit reports, typed I/O, memory inheritance. | `pip install covenant-cli` |
| **crewai-governance** | Add governance to existing CrewAI projects. Two lines of code. | `pip install crewai-governance` |
| **covenant-hedge-fund** | Production example: AI hedge fund with constitutional governance. | `git clone` |
| **synthex** | Multi-generational code synthesis through governed agent generations. | `pip install synthex` |
| **mandate** | Agent-native programming language with intent, verify, synthesize, handoff. | `pip install mandate-lang` |

All projects at github.com/asalsali.

## What's inside

| Component | Description |
|---|---|
| **Constitution** | 36 sections of immutable rules every agent inherits |
| **12 Agent types** | Interpreter, Analyst, Writer, Synthesist, Guardian, Shepherd, Scribe, Stress Tester, Futility Review, Goal Challenge, James, Executor |
| **16 Commands** | `/spawn`, `/consolidate`, `/checkpoint`, `/audit`, `/remember`, and 11 more |
| **4 Runtime hooks** | Agent gate, token logging, shutdown orchestration, session checks |
| **Memory system** | Exit reports, structured memos, semantic memory, consolidation cycles |

## Architecture

```
         YOU
          |
    [Interpreter]          -- the only agent that talks to you
      /    |    \
 [Analyst] [Writer] [...]  -- spawned agents, scoped mandates
```

## Agent lifecycle

```
SPAWN  -->  GENESIS PHASE  -->  EXECUTE  -->  SHUTDOWN
  |              |                 |              |
  Three gates:   Read mandate,    Work within    Write exit report,
  overlap,       Constitution,    mandate        archive, notify
  scope,         prior learnings  boundaries     parent
  memory
```

## Hello World

See `examples/quickstart/` for a minimal example that demonstrates governance in under 30 seconds.

## Integrations

- **CrewAI** -- see `docs/integrations/crewai.md`
- **Claude Code** -- native support, install and go
- **OpenAI Codex CLI** -- full support via `--runtime codex`

## Community vs Network

This is the **Community Edition** -- free and fully functional.

| | Community | Network |
|---|:---:|:---:|
| Constitution (36 sections) | Full | Full |
| Agent definitions (all 12) | Yes | Yes |
| Core commands (16) | Yes | Yes |
| Advanced commands (+22) | -- | Yes |
| Core hooks (4) | Yes | Yes |
| Advanced hooks (+7) | -- | Yes |

## Benchmark

Terminal-Bench 2.0, 89 tasks: **67.4%%** no-retry, vs 42%% ad-hoc baseline.

## License

Covenant Public License v1.0 -- see LICENSE.
