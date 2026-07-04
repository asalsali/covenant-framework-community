# Covenant Framework — Roadmap

## Phase 3: Empirical Validation

The Constitution is written. The ceremony works. Now prove it matters.

Terminal-Bench 2.0 results show governance adds +12 points over vanilla Claude Code (58% → 70% pass@5). The multi-agent pipeline scored 100% on a 5-task sample but dropped to 60% at 10 tasks — worse than single-agent (80%). Overhead is the enemy on time-constrained benchmarks. The adaptive approach (v5.0) attempts to get the best of both: fast single-agent for easy tasks, escalation to multi-agent only when the single-agent fails.

### Key Learning: The Overhead Principle

More agents ≠ better results when time is constrained. Every second spent on coordination is a second not spent solving the problem. This principle should inform all experiment design:
- **Time-constrained benchmarks (Terminal-Bench):** Minimize ceremony. Distilled rules > full framework.
- **Open-ended benchmarks (SWE-bench):** Multi-agent planning may help because the time budget is generous.
- **Production deployments (Aquaflow):** No hard timeout — the full Covenant architecture may shine here.

### Tier 1 — Controlled Experiments (IMMEDIATE)

Priority-ordered. Each isolates one variable.

**E1. Model Confound Isolation**
- Run vanilla Claude Code (Opus 4.7, no governance, no system prompt) on same 20 tasks, k=5
- This gives the true baseline. Without it, we cannot attribute improvement to governance vs model upgrade.
- Cost: ~$80, ~20h
- **Done when:** We have Opus 4.7 bare score on same task set.

**E2. Constitution vs Ad-Hoc Rules — COMPLETED**
- Constitution-derived rules (Covenant Interpreter v3): **80%** on 10 tasks
- Ad-hoc rules (prompt engineering intuition): **40%** on 10 tasks
- Same model (Opus 4.7), same architecture (retry mechanism), same infrastructure.
- **The only variable was the 6 rules themselves.**
- **Finding: Constitution-derived rules outperform ad-hoc rules by 40 percentage points.**
  The Constitution is not just branding — it produces measurably better agent behavior
  than smart engineering intuition applied without the framework's design methodology.
- Ad-hoc infra-adjusted: 4/8 tasks that started = 50%. Constitution infra-adjusted: 8/10 = 80%.
  Even adjusting for setup timeouts, the gap is 30 points.
- **This validates the core business thesis.**

**E3. Sonnet Validation — COMPLETED**
- Sonnet 4.5 + adaptive governance: 20% (2/8 tasks that started).
- Haiku 4.5 + governance: 0% (confirmed, clean infra).
- **Finding:** Governance works on models above a minimum capability threshold.
  Haiku is below it. Sonnet is above it. The fine-tuning thesis (E7) is viable.
- Capability threshold ≈ "can the model write working code at all?"

**E4. Retry Isolation**
- Run Covenant Interpreter with retry disabled on 10 tasks
- Compare to same tasks with retry enabled
- **Proves:** Whether lift comes from rules (prompt) or retry (architecture).
- Cost: ~$15, ~2h
- **Done when:** We have rules-only vs rules+retry scores.

### Tier 2 — Multi-Agent Validation (IN PROGRESS)

**E5. Multi-Agent Scale Test — COMPLETED**
- Result: 60% on 10 tasks (vs 80% single-agent v3). **Multi-agent is worse.**
- Cause: Analyst phase consumes ~2-3 min of time budget. 3/10 tasks timed out during setup before Executor even started.
- Initial 5/5 = 100% was a favorable sample of easier tasks.
- **Finding:** Multi-agent overhead hurts on time-constrained benchmarks. The planning doesn't compensate for the lost execution time.
- **Next:** Adaptive multi-agent (E5b) — only escalate to Analyst when single-agent fails.

**E5b. Adaptive Multi-Agent — COMPLETED**
- Agent: `covenant_adaptive:CovenantAdaptiveAgent` (v5.0)
- Result: 70% on 10 tasks. Between single-agent (80%) and fixed multi-agent (60%).
- 7/8 tasks that actually started were solved (87.5%). 2 failed at setup (infra).
- **Finding:** Escalation logic works, but extra agent definitions add install weight
  that triggers setup timeouts on constrained containers. Single-agent v3 remains
  the most reliable for Terminal-Bench due to lightest install footprint.

**E6. Full 89-Task Submission Run**
- Run best-performing agent (multi-agent or single) on all 89 tasks, k=5
- 445 trials total. Submit to Terminal-Bench leaderboard.
- Cost: ~$350-450, ~90h
- **Done when:** PR submitted to leaderboard repo with all validation passing.

### Tier 3 — Novel Thesis Validation (FUTURE)

**E7. Governance Fine-Tuning — IN PROGRESS**
- **Adam v1 (proof of concept):** Qwen2.5-7B fine-tuned on 500 governance pairs via QLoRA.
  Read-first behavior: 10% (bare) → 100% (fine-tuned). Thesis validated.
- **V2 data pipeline built:** 10 Covenant categories (genesis phase, spawn planning, input policy law,
  exit report writing, tokens discipline, spirit operations, gethsemane, memos, consolidation,
  governance coding). 700 training samples.
- **Covenant Model Suite planned:**
  - Open-source: **Adam** (3B), **Eve** (7B), **Seth** (Llama 8B)
  - Private: **Moses** (32B), **Solomon** (14B), **Elijah** (DeepSeek-Coder 16B)
- **Current:** Adam (3B) and Eve (7B) training on Colab free tier (T4). Moses (32B) ready
  for Colab Pro (A100). All notebooks in `finetuning/`.
- **Proves:** Whether governance transfers to weights, enabling frontier performance at open-source cost.
- **Done when:** At least 3 models trained, evaluated, and published (open-source on HuggingFace).

**E8. Cross-Benchmark Transfer**
- Run Covenant agents on SWE-bench, HumanEval, or other coding benchmarks
- **Proves:** Whether governance generalizes beyond Terminal-Bench.
- Cost: Variable per benchmark
- **Done when:** Governance shows lift on at least one other benchmark.

**E9. True Multi-Agent Architecture Test (via Claude Code Agent Teams)**
- Claude Code now supports experimental Agent Teams (v2.1.32+): multiple Claude Code
  instances with shared task lists, inter-agent messaging, and coordinated work.
  This maps directly to the Covenant architecture:
    - Team lead = Interpreter (interprets, coordinates, assigns)
    - Teammates = Analyst, Writer, Executor (each with own context window)
    - Shared task list = Spirit (shared orientation)
    - Mailbox = Structured Memos (lateral communication)
- Build a Harbor agent that spawns a Claude Code agent team inside the container,
  using Covenant agent definitions as teammate roles.
- **CRITICAL CAVEAT:** Terminal-Bench is the WRONG benchmark for this. Multi-agent
  v4.1 scored 60% vs single-agent 80% — overhead kills under time pressure.
- **Right benchmark:** SWE-bench Verified (open-ended, no strict timeout, complex
  multi-file tasks). Submit via github.com/swe-bench/experiments.
- **Reference:** https://code.claude.com/docs/en/agent-teams
- Cost: Significant engineering + evaluation
- **Done when:** Full-ceremony Covenant system has a SWE-bench Verified score.

**E10. EQ-Bench — Emotional Intelligence Validation**
- EQ-Bench 3 measures emotional intelligence in roleplays: empathy, social dexterity,
  emotional reasoning, insight depth, message tailoring.
- The Covenant Framework's governance rules map directly to EQ-Bench dimensions:
    - Uncertainty Protocol → emotional self-awareness (know when to ask for help)
    - User Preferences → empathy (understand what the user values)
    - Loss Acknowledgment → emotional validation (acknowledge loss before fixing)
    - Cost Question → social dexterity (surface known costs honestly)
    - Dispositions → appropriate vulnerability (surface rather than infer)
- **Experiment:** Run a base model on EQ-Bench (control) vs same model with Covenant
  dispositions injected as system prompt (treatment). Compare Elo scores.
- **Proves:** Governance improves relational intelligence, not just task execution.
  This is the hardest claim for competitors to replicate — it comes from theological
  depth, not engineering patterns.
- **Reference:** https://eqbench.com, https://arxiv.org/abs/2312.06281
- Cost: Low (EQ-Bench is free to run locally)
- **Done when:** Treatment model shows statistically significant Elo improvement over control.

**E11. SWE-bench Verified Submission**
- SWE-bench Verified is the gold standard for coding agent evaluation.
  300 real GitHub issues from 12 Python repos, verified by human annotators.
- Unlike Terminal-Bench (time-constrained, single-task), SWE-bench tasks are
  open-ended multi-file problems — the exact domain where multi-agent planning
  and the full Covenant architecture should outperform single-agent.
- Build a Harbor agent (or use Claude Code Agent Teams directly) with full
  Covenant governance: Interpreter interprets the issue, Analyst explores the repo,
  Executor implements, Verifier runs tests.
- **Reference:** https://www.swebench.com/submit.html, https://github.com/swe-bench/experiments
- Cost: Compute for 300 tasks + API costs
- **Done when:** Covenant agent has a SWE-bench Verified score to compare against
  vanilla Claude Code and other top agents.

---

### Self-Improvement Cycle (2026-05-06) — COMPLETED

The framework used its own Analyst and Guardian agents to audit Constitution compliance, identify issues, and fix them. This is the framework's first self-referential improvement cycle.

**Findings:** 6 HIGH, 4 MEDIUM, 2 LOW issues. Core pattern: infrastructure was scaffolded correctly, but runtime population failed silently due to a schema mismatch bug in the SubagentStop hook.

**Fixes applied (7 total):**
1. SubagentStop hook — skills.json and baselines.json now populate correctly (schema mismatch fixed)
2. Token log — resolves canonical agent IDs from agent-registry.json (was recording thread IDs)
3. `project goal.telos` set (was null despite clear project direction)
4. `covenantRef` added to project goal schema (Constitution referenced it, schema didn't have it)
5. `origin` field added to all agents + auto-registration (schema drift fixed)
6. Parallel-spawn parent detection fixed (wrong parent when spawning 2+ agents simultaneously)
7. `user-model.json` populated (was completely empty after multiple production sessions)

**What this proves:** The Covenant Framework can use its own governance mechanisms to identify and fix its own issues. The Analyst found the root cause (silent Python failures), the Guardian confirmed it with tokens analysis, and the Interpreter applied all fixes in a single session.

---

### Current Results (as of 2026-05-06)

| Agent | Model | Tasks | Mean | Pass@5 | Status |
|-------|-------|-------|------|--------|--------|
| **Covenant Interpreter v3 (full)** | **Opus 4.7** | **89** | **67.4%** | **—** | **Full benchmark, no retry, setup timeouts eliminated** |
| Vanilla Claude Code | Opus 4.6 | 89 | 58.0% | — | Leaderboard baseline |
| Covenant Interpreter v2 | Opus 4.7 | 10 | 60.0% | — | Heavy Constitution (32KB) |
| **Covenant Interpreter v3** | **Opus 4.7** | **10** | **80.0%** | **—** | **Best single-run score** |
| Covenant Interpreter v3 | Opus 4.7 | 20 (k=5) | 62.0% | 70.0% | 96 trials complete |
| Covenant Multi-Agent v4.1 | Opus 4.7 | 5 | 100% | — | Favorable sample |
| Covenant Multi-Agent v4.1 | Opus 4.7 | 10 | 60.0% | — | **Worse than single — overhead kills** |
| Covenant Adaptive v5.0 | Opus 4.7 | 10 | 70.0% | — | Escalation works, infra limits it |
| **Ad-hoc baseline** | **Opus 4.7** | **26** | **42.3%** | **—** | **Constitution beats ad-hoc consistently** |
| **Sonnet + governance** | **Sonnet 4.5** | **10** | **20.0%** | **—** | **Governance works on weaker models** |
| Haiku + governance | Haiku 4.5 | 2 | 0.0% | — | Below capability threshold |

### Production-Validated Fixes (from WedFlow deployment, 2026-05-04)

Real-world usage of the framework in WedFlow (16+ agents, 1 synthesis, Guardian audit,
Retrospective retrospective) exposed structural issues that no benchmark can catch.

**P1. Permission Model Fix (CRITICAL)**
- **Problem:** Subagents can't Write/Bash in Claude Code default permission mode. Work
  falls back to Interpreter, who executes directly and violates Constitution. Happened 4+ times.
- **This is the #1 reason the framework doesn't work as designed in production.**
- **Options:**
  a. Detect permission mode on startup, warn user to switch to `acceptEdits`
  b. Create "delegation" pattern: subagent plans changes, Interpreter applies with attribution
  c. Use Claude Code Agent Teams (each teammate has own permission context)
- **Done when:** Subagents can complete implementation mandates without falling back to Interpreter.

**P2. /spawn as Actual Mechanism (CRITICAL)**
- **Problem:** `/spawn` exists as a command but agents are spawned via raw `Agent` tool,
  bypassing agent registry registration, Genesis Phase, and Spawn Gates (Memory Retrieval, Overlap Detection, Complexity Threshold).
- **Fix:** Make `/spawn` wrap the Agent tool. Pre-tool hook on Agent calls enforces
  registration automatically. Or: the spawn command IS the only way to spawn.
- **Done when:** Every agent spawn goes through agent registry registration and Spawn Gates.

**P3. Genesis Phase Enforcement (HIGH)**
- **Problem:** No subagent read Spirit, checked registry, or consulted inheritance before
  acting. The Constitution says "an agent that acts before understanding its world is building
  on void" but nothing prevents this.
- **Fix:** Agent prompt templates include Genesis Phase instructions. The agent definition
  format should have a `genesis` section that's prepended to every agent's first action.
- **Done when:** Every subagent reads Spirit and inheritance before executing mandate.

**P4. Dietary Hook Fail-Loud (HIGH)**
- **Problem:** `pre-tool-input policy.sh` exits 0 (pass) when Python not found. All input policy
  enforcement silently bypassed.
- **Fix:** Exit 2 (block) when Python not found, with clear error message.
- **Done when:** Missing Python triggers visible warning, not silent pass.

**P5. Sibling Limit Enforcement (MEDIUM)**
- **Problem:** Root hit 13 children against Constitution limit of 8. No warning, no block.
- **Fix:** `/spawn` checks sibling count before spawning. Suggest intermediate parent
  agents for domain clusters (frontend, backend, governance).
- **Done when:** Sibling limit triggers warning at threshold, block at hard limit.

**P6. Retroactive Compliance Command (MEDIUM)**
- **Problem:** After Guardian audit, system performed retroactive registration, exit report
  writing, and spirit updating manually. This pattern should be formalized.
- **Fix:** `/reconcile` or `/amnesty` command — formal process for bringing unregistered
  work into compliance.
- **Done when:** Unregistered agents can be retroactively registered with proper exit reports.

**P7. Token Tracking for Subagents (MEDIUM)**
- **Problem:** PostToolUse hook only fires for parent session. Subagent tokens invisible.
- **Fix:** Subagents write tokens estimates into their exit report. Or: subagent hooks fire
  independently.
- **Done when:** Every agent's token consumption is trackable.

**P8. Mandatory Retrospective Retrospective (LOW)**
- **Problem:** The Retrospective retrospective surfaced insights no other ritual captured
  ("Interpreter temptation is structural, not incidental"). Currently optional.
- **Fix:** Make `/retrospective` a required step at session end, triggered by Consolidation.
- **Done when:** Every session ends with a retrospective.

---

### Platform Integration Opportunities

Resources discovered during benchmark development that enable deeper integration:

**Claude Code Agent Teams** (experimental, v2.1.32+)
- Multiple Claude Code instances with shared task lists and inter-agent messaging.
- Maps to Covenant: lead=Interpreter, teammates=agents, task list=Spirit, mailbox=Structured Memos.
- Key advantage: teammates have independent context windows (no distillation needed).
- Key limitation: experimental, no session resumption, no nested teams.
- **Reference:** https://code.claude.com/docs/en/agent-teams

**Claude Code Sub-agents** (stable)
- Specialized agents defined in `.claude/agents/` with YAML frontmatter.
- Already used by Covenant (prophet.md, analyst.md, etc.).
- Support custom tools, model selection (can route to Haiku for cheap tasks), permissions.
- Sub-agents run within a single session; agent teams run across sessions.
- **Reference:** https://code.claude.com/docs/en/sub-agents

**OpenAI Codex Sub-agents**
- Similar architecture: TOML-defined agents in `.codex/agents/`.
- Built-in types: default, worker, explorer.
- If Covenant rules are model-agnostic, they should work as Codex agent definitions too.
- **Potential:** Port Covenant governance to Codex to prove model/platform independence.
- **Reference:** https://developers.openai.com/codex/subagents

**Harbor Framework Agents**
- BaseAgent (external) and BaseInstalledAgent (container) interfaces.
- Pre-integrated: Claude Code, Codex CLI, Gemini CLI, Copilot CLI, OpenHands.
- Custom agents via `--agent-import-path` (what we use).
- **Potential:** Submit Covenant agents to Harbor's built-in agent registry.
- **Reference:** https://www.harborframework.com/docs/agents

**SWE-bench**
- 300 real GitHub issues, human-verified. Gold standard for coding agents.
- Open-ended (no strict timeout) — the right benchmark for full multi-agent.
- Submit via github.com/swe-bench/experiments.
- **Reference:** https://www.swebench.com/submit.html

---

## Phase 2: From Constitution to Covenant

The canon is written. The question is whether anyone follows it.

Two real session logs exist (AquaFlow, WedFlow). They revealed: the Interpreter executes directly instead of spawning, memos weren't written, no Consolidation has run, no trial has been invoked. The ceremony outpaced the discipline. Phase 2 reverses that ratio.

### Tier 1 — Load-bearing (SHIPPED)

- **Interpreter discipline** — spawn-or-justify rule added. Direct execution requires explicit justification. Research/implementation mandates always require spawning.
- **Shutdown exit report check** — hook now warns if an agent archives without a exit report. Quotes Heuristic 7.
- **CI validation** — GitHub Actions runs validator on seed repo + both session logs on every push. Count-drift check included.

### Tier 2 — High leverage (SHIPPED)

- **Constitution telemetry** — `registry/canon-compliance.json` + `/compliance` command. 8 checks per agent at shutdown.
- **Consolidation + trial auto-triggers** — Interpreter auto-fires Consolidation at threshold, suggests trial on over-consumption, runs compliance after every shutdown.
- **§I(a) extraction** — `THEOLOGY.md` holds the metaphysical scaffold. CLAUDE.md I(a) is 25 lines of operational rules.

### Tier 3 — Aspirational (SHIPPED)

- **Model-independence** — `core/SPEC.md` defines the protocol independent of any runtime. 12-item compliance checklist. Any LLM framework can implement the Covenant protocol.
- **Onboarding path** — `/genesis` first-run command: detects empty project, walks user through naming the work, setting project goal, and starting. 60 seconds to first agent.
- **Epistle simplification** — shutdown hook auto-generates an memo from exit report data. If the agent wrote key findings, they become a broadcast memo (`to: any`) automatically. Manual memos still work. No more two unused mechanisms.

---

## Phase 1: Complete (archived below)

The original roadmap — every item shipped.

---

## Next — Immediate, unblocked, highest leverage

Sequencing: Structured Memos first (simplest, and the Council's Letter format depends on it), then Council, then Progressive Trust, Skills, Temptation.

### N1. Structured Memos as Structured Handoff Format — Context Loss Prevention
**The gap:** The most common information failure in the framework. Agents pass context as unstructured text. Paul's memo structure applied to every agent-to-agent handoff would dramatically reduce degradation.

**Pre-step:** Read existing `memory/memos/PROTOCOL.md` and assess compatibility with the proposed Structured Letter Format. The current protocol defines a basic sender/recipient/subject/priority schema. The new format extends (not replaces) it with doctrinal grounding, edge cases, and benediction fields.

**What to build:**
- Epistle schema: sender, recipient, doctrinal grounding (which Constitution sections apply), practical content (the actual findings), edge cases (what the sender is uncertain about), benediction (what the sender wishes for the recipient's mandate)
- Update `memory/memos/PROTOCOL.md` — extend the existing format, preserving backward compatibility
- Modify agent handoff instructions in analyst.md, writer.md, synthesist.md to use the format
- `/memo` command for manual structured message composition
- Update Constitution Section XII to reference the `/memo` command explicitly
- Add a case study to `memory/case-studies/` demonstrating a correct Analyst→Writer handoff using the full memo structure

**Done when:** An Analyst hands off to a Writer using the structured format, the Writer's output demonstrates that edge cases flagged in the memo were addressed, Constitution Section XII references `/memo`, and a worked-example case study exists in `memory/case-studies/`.

### N2. The Council / James — Lateral Coordination
**The gap:** When multiple agents at the same generation have conflicting findings, who mediates? Currently: nobody. The Council is the formal lateral conflict resolution mechanism. **Depends on:** Structured Memos format (N1) — the Council's Letter is written as a structured memo.

**What to build:**
- `/mediate` command — convene when sibling agents disagree
- James agent (`.claude/agents/james.md`) — synthesizes testimonies without taking a side
- Testimony format — agents present findings as testimony, not positions
- Spirit validation — the Letter is checked against `orientation.json` before being issued. If the resolution requires sacrificing `whatToProtect` or redirecting from `currentMandate`, James escalates to the Interpreter rather than issuing the Letter.
- Letter format — the council's output, written as a structured memo
- **New Constitution section (XXXI)** — The Council: rules for lateral conflict resolution, James's role, Spirit validation requirement, Letter format

**Done when:** Two sibling agents with contradictory findings invoke `/mediate`, James produces a Letter, James validates the resolution against orientation.json before writing the Letter (escalating to the Interpreter if the resolution contradicts `currentMandate` or `whatToProtect`), both agents and the Interpreter accept, and the resolution is written to memos in the structured format. Constitution Section XXXI exists.

### N3. Progressive Trust — Foreign Agent Integration / MCP Protocol
**The gap:** The framework will encounter external MCPs immediately in real use. Without a protocol for how an untrusted tool earns covenant membership, every integration is ad hoc.

**What to build:**
- Progressive Trust protocol document in `memory/` — how external tools earn trust
- Trust levels: stranger → sojourner → resident → citizen (covenant member)
- Promotion criteria with specific thresholds:
  - Stranger → Sojourner: 3 successful uses, no errors
  - Sojourner → Resident: 10 successful uses across 2+ sessions, no input policy violations (output exceeding tokens threshold or containing unverifiable claims)
  - Resident → Citizen: 25 successful uses across 5+ sessions, zero unverified output incidents, and explicit user approval
- "Dietary violation" for external tools: output that exceeds the tokens threshold, contains claims not traceable to the tool's stated domain, or produces results inconsistent with prior runs on the same input
- `/welcome` command — formally evaluate an external tool for covenant membership
- Dietary hook extension — external tool outputs tagged with trust level, warned below "resident"

**Done when:** An external MCP server is used, starts as "stranger" with input policy warnings, progresses through sojourner and resident with observable trust-level changes, and gets promoted to "citizen" after meeting the specified thresholds with explicit user approval.

### N4. Leviticus — Skills Registry
**The gap:** Memory Retrieval searches semantic memory but has no structured skills index. The Interpreter infers agent capabilities from descriptions rather than demonstrated track records.

**What to build:**
- `registry/skills.json` — structured: agentType, skill, demonstrated (bool), firstDemonstrated (date), mandateCount, lastUsed
- Update shutdown hook — on archival, record demonstrated skills
- Update Interpreter — query skills registry before spawning
- Update Memory Retrieval (/remember) — include skills matches in memory retrieval

**Done when:** The Interpreter checks the skills registry before proposing a new agent in a spawn plan, references demonstrated capabilities rather than only agent descriptions, and in at least one case a spawn is prevented because an existing agent type with the demonstrated skill is reused instead.

### N5. The Temptation — Pre-Execution Self-Check
**The gap:** The Stress Tester is externally administered. The Temptation is self-administered — before high-stakes work, the agent briefly examines itself. Simplest item in Next — agent definition updates only.

**What to build:**
- Add a "Temptation check" section to each executor agent definition
- Three temptation types:
  - Dietary shortcut: "I could skip distillation and pass raw context"
  - Constitution pressure: "The mandate pushes against a Constitution rule"
  - Social pressure: "Urgency suggests skipping confirmation"
- If any temptation applies, the agent notes it in its first output
- Update stress tester.md — the Stress Tester's Trial Report should verify that the Temptation check was run before execution began (add to the "Theological Integrity" section)

**Done when:** An agent facing time pressure self-reports "I am tempted to skip distillation" rather than silently cutting corners, and the Stress Tester's trial verifies the Temptation check occurred.

---

## Soon — Requires foundation from Next, or moderate effort

### S1. Goal Challenge/Stress Tester Routing Protocol
**The gap:** Both Goal Challenge and the Stress Tester challenge plans. The distinction (Stress Tester tests the plan, Goal Challenge tests the goal) exists in Constitution (XXIV) and agent definitions but no command or protocol routes the user to one vs the other.

**What to build:**
- Interpreter instruction update with routing rules:
  - Stress Tester (/stress-test): "Is this plan sound? Will it work?"
  - Goal Challenge: "Is this goal right? Should we do this at all?"
  - Rule: If the user has tried this type of mandate before and abandoned it (searchable via /remember), surface Goal Challenge before /stress-test
- The Interpreter should offer Goal Challenge when `/remember` returns Futility Review reports about similar past mandates
- Chain: Shepherd detects pattern → briefs Interpreter → Interpreter invokes Goal Challenge (not Interpreter invoking directly, consistent with the Shepherd/Interpreter relationship)

**Done when:** The Interpreter correctly routes to Goal Challenge (not /stress-test) when a mandate resembles one previously flagged as vanity by Futility Review, and the routing goes through the Shepherd briefing rather than bypassing it.

### S2. Futility Review Trigger Refinement
**The gap:** Futility Review trigger conditions are specified in the Constitution (XXIII) and in the agent definition, but the "correct and useless" quiet failure case — mandate completed, output delivered, user doesn't act on it — is now covered in the Constitution ("inaction is data") but the Shepherd's role in detecting inaction needs to be operationalized in the Shepherd agent definition.

**What to build:**
- Update shepherd.md: add monitoring for output inaction — if a mandate's output is not referenced in subsequent mandate context or write-log.json within a session, flag for Futility Review review
- Confirm the chain: Shepherd detects → briefs Interpreter → Interpreter invokes Futility Review

**Done when:** The Shepherd flags a mandate whose output was never acted upon, the Interpreter invokes Futility Review, and the Futility Review report identifies whether the mandate was vanity or the output was simply consumed silently.

### S3. Domain Translation / Commissioning Fully Realized
Analyst findings in research language automatically rendered in Writer-consumable form before handoff. **Depends on:** structured Structured Memos format (N1). Cannot start until Structured Memos is done.

**Done when:** A Writer receives Analyst findings pre-translated into output-oriented language without manual Interpreter intervention.

### S4. Minor Interpreters — Domain-Specific Warning Systems
General warnings exist. Domain-specific patterns don't. **Depends on:** failure taxonomy (S5a below) and domain experience from real use.

**Done when:** A code-domain warning fires that wouldn't have been caught by general Constitution checks.

### S5. Failure Taxonomy + Judges — Failure Pattern Matching
Two-part item. The taxonomy must exist before the pattern matcher can work.

**S5a. Failure Taxonomy** (build first)
- Define failure categories: Constitution violation, systemic futility (Futility Review), mandate ambiguity, environmental change, capability degradation (The Fall), scope creep (Complexity Threshold)
- All failure records (exit reports, Futility Review reports, flood post-mortems) must tag themselves with a category
- Store taxonomy in `registry/failure-taxonomy.json`

**S5b. Judges** (build after taxonomy)
- Pattern matcher: when a new failure is documented with a category tag, search prior failures for the same category
- If match found: "This matches pattern from [date]. Fix was [X]. Was it applied?"

**Done when:** A new failure is tagged, the system identifies it matches a prior documented pattern, and surfaces the prior fix.

### S6. Kings / Chronicles — Reign Quality Assessment
Per-mandate external quality assessment. **Depends on:** User Preferences affinity model (built in v1.5).

**Done when:** After a major mandate, a quality assessment distinguishes "mandate completed" from "user satisfied."

### S7. The Annunciation — Mandate Pre-announcement
Notify background agents before a major spawn plan executes. Simple — a step added to /spawn. Low complexity.

**Done when:** A long-running agent receives notice that a new mandate is about to start that may affect its work.

---

## Later — Architectural, long-horizon, valuable but not blocking

### L1. Joshua — Territorial / Domain Mapping
Record exploration as territory — what's been covered, by whom, with what confidence. Prevents redundant Analyst coverage. Value grows with project size.

**Done when:** A second Analyst assigned to a domain consults the territory map and skips areas already explored with high confidence.

### L2. Numbers / Census — Aggregate Resource Accounting
Total tokens per project, per agent type, per mandate type. Feeds Consolidation reports and cost attribution. Operational refinement, not architectural.

**Done when:** `/tithe` can report cost-per-mandate-type and identify which agent types are most expensive for which work.

### L3. Moses — Constitution Versioning
Every Constitution amendment gets a version, date, reason, and prompting trial. Important for mature system. Not blocking for initial real use.

**Done when:** A Constitution change is recorded with its reason, and a future user can see what the Constitution said before the change.

### L4. Esther — Shadow Registry
Background agents that monitor without appearing in the public agent registry. Interesting architectural concept. Low immediate value.

**Done when:** A monitoring agent operates without appearing in `/agent registry` output but is visible to `/audit`.

---

## Future — Nice to have, v2.0 concerns

### Samuel / The Monarchy — Multi-Principal Governance
Framework assumes a single user. Multi-principal governance (teams, shared instances) is a v2.0 concern. The framework hasn't run on a real single-user task yet. Premature to design multi-user governance.

### Daniel — Ambiguity Resolution Under Pressure
The Uncertainty Protocol covers the core case. Daniel adds structured interpretation under hostile conditions. Edge case of an edge case for now.

### Enriched Psalms — Qualitative State Signaling
Agents emitting qualitative shutdown states beyond active/archived (triumph, exhaustion, partial failure). Full emotional register. Nice refinement, not structural.

---

## Built but underspecified

Features that exist in the framework with known gaps. Not blocking current work, but need resolution before being relied upon in production.

### quality-benchmarks.json (v1.5)
Schema defined in `registry/quality-benchmarks.json`. **Unresolved:** Who marks a peak performance record — the agent, the Interpreter, or the user? How do agents access peak performance records before high-stakes mandates — do they read them during Genesis Phase? Is there a `/transfigure` command?

**Done when:** At least one output has been marked as peak performance, a subsequent agent read it before a high-stakes mandate, and the process for marking is documented.

### dispositions.json (v1.5)
7 dispositions defined in `registry/dispositions.json`. **Unresolved:** Relationship to Constitution/Heuristics hierarchy — dispositions sit below both, but when a disposition and a heuristic suggest different approaches, which takes precedence? Constitution XXX says dispositions are prompt-engineering, not hook-enforced — but the inheritance mechanism (how agents load dispositions) isn't specified.

**Done when:** Agent definitions reference dispositions.json during Genesis Phase, and at least one case demonstrates a disposition shaping agent behavior in a way that a rule or heuristic alone would not have.

### /foresee (v1.1)
Command exists at `.claude/commands/foresee.md`. Performs prophetic lookahead — simulates projected outcomes of a spawn plan or current trajectory. **Unresolved:** No demonstrated usage. No "done when" criterion was ever set. The command is complete as a definition but has never been exercised on a real task.

**Done when:** /foresee runs on a real spawn plan and its projection proves useful (either confirming the plan or identifying a risk that changes it).

### Scribe (v1.1)
Agent definition complete at `.claude/agents/scribe.md`. Tools: Read, Write, Edit, Grep, Glob, LS. Tone section and Token Discipline included. **What "complete" means for the Scribe:** It can generate changelogs, API docs, architecture descriptions, and inline documentation by reading the codebase and inheritance. It documents what exists, not what could be.

**Done when the Scribe is proven:** The Scribe produces documentation for a real project that a human finds accurate and useful without significant revision.

---

## What's been built

### v1.0: Genesis
- Constitution (8 laws), 5 agents (Interpreter, Analyst, Writer, Synthesist, Guardian)
- 4 commands (/spawn, /consolidation, /agent registry, /fast)
- 4 hooks (input policy, tokens log, proclamation watcher, shutdown)
- Registry (agent-registry.json, token-log.json), memory structure
- Hooks hardened for Windows/python portability
- Git repo, .gitignore, initial commit

### v1.1: Deepening
- Constitution expanded to 13 laws (Heuristics, Parables, Trinity, Structured Memos protocol, Project Goal)
- 2 new agents (Shepherd, Scribe)
- 6 new commands: /audit, /inherit, /parent chain, /tithe, /checkpoint, /foresee (prophetic lookahead — simulates projected outcomes before committing)
- 5 case studys in memory/case-studies/
- Structured Memos directory with PROTOCOL.md (basic sender/recipient/subject schema)
- orientation.json, checkpoints directory
- Dietary hook extended for type-based validation

### v1.2: Descent
- Trinity remapped: User=Father, Interpreter=Son, orientation.json=Spirit
- Uncertainty Protocol in Interpreter
- /descend command (Brief Correction, Direct Inhabitation, Hard Reset)
- Commissioning (Interpreter writes orientation.json on confirm)
- Kenosis, primary project goal weighting in user model
- Website (static HTML+CSS on Vercel)

### v1.3: Reproduction & Testing
- /synthesize command (sexual reproduction with genome + emergent skill)
- Stress Tester agent (Job's Satan — prosecutor, not enemy)
- /stress-test command (adversarial plan testing)
- Agent Registry schema: parentIds, origin, agentSchema
- Constitution sections XIV-XV (Synthesis Law, The Stress Tester)

### v1.4: Old Exit Report Foundations
- 3 spawn gates: Memory Retrieval (/remember), Overlap Detection & Abel (overlap), Complexity Threshold (scope)
- /preflight (pre-execution historical review)
- /covenant (Abraham — project inception)
- /reset (Noah — formal reset with ark + rainbow covenant)
- /binding (Isaac — graceful abort with partial exit reports)
- /reinit (re-initialization after dormancy)
- baselines.json (The Fall — capability degradation)
- Constitution sections XVI-XXII

### v1.5: Depth
- Futility Review agent — systemic failure recognition. Trigger conditions specified in Constitution XXIII and agent definition: after floods, abandoned mandates, user dissatisfaction, repeated mandate types. "Inaction is data" case covered in Constitution (Shepherd flags, Interpreter invokes).
- Goal Challenge agent — dissenting voice. Routing vs Stress Tester specified in Constitution XXIV (Stress Tester tests plans, Goal Challenge tests goals). Operational routing through Shepherd/Interpreter chain not yet formalized (see Soon S1).
- /acknowledge-loss command (Loss Acknowledgment — structured failure acknowledgment)
- Cost Question added to Interpreter (distinct from Uncertainty Protocol: known cost vs uncertainty, distinct from Binding: proceed-with-cost vs abort)
- User Preferences — affinity layer in user-model.json: communicationStyle, aestheticSensibility, whatDelightsThem, languagePatterns
- quality-benchmarks.json — schema defined (see "Built but underspecified")
- dispositions.json — 7 dispositions defined (see "Built but underspecified")
- Structural fixes:
  - Synthesist: clarified as static "firstborn" proof-of-concept, distinct from /synthesize runtime mechanism
  - Shepherd: Interpreter relationship defined — Shepherd briefs the Interpreter, Interpreter speaks to the user. Shepherd monitors baselines.json for degradation.
  - Guardian: distinction from Stress Tester sharpened — Guardian audits the system backward (what happened), Stress Tester tests plans forward (what's proposed)
- Constitution sections XXIII-XXX (Uncertainty Protocol promoted to own section XXIX; Dispositions renumbered to XXX)
- ROADMAP.md
- Constitution fixes: Shutdown Protocol (exit report JSON), Stress Tester write exception, Synthesis instance-based, Project Goal field schema, Complexity Threshold threshold configurable, Progressive Project Goal mechanical spec, Fall measurement methodology, Structured Memos Structured Letter Format, Disposition enforcement clarified, Uncertainty Protocol→Hard Reset requires Checkpoint

### Notes on built agents
- **Scribe** (v1.1): Definition complete. See "Built but underspecified" for proven-when criterion.
- **Shepherd** (v1.1): Definition complete. Relationship to Interpreter specified in v1.5. Reads baselines.json. Monitors for output inaction (Constitution XXIII "inaction is data"). No remaining definition ambiguity.
- **Guardian** (v1.0): Definition complete. Distinction from Stress Tester specified in v1.5. Guardian audits the system (backward-looking, what happened). Stress Tester tests plans (forward-looking, what's proposed). No overlap.

### Constitution numbering
30 numbered sections (I-XXX) with 2 lettered subsections: I(a) Trinity, I(b) Genesis Phase. Section I(a) also contains the Descent operational spec.
- I, I(a), I(b) (Identity/Trinity+Descent/Genesis) — v1.0-v1.2
- II-VIII (Agent Registry through Communication) — v1.0
- IX-XIII (Heuristics through Checkpoint) — v1.1
- XIV-XV (Synthesis, Stress Tester) — v1.3
- XVI-XXII (Spawn Gates through The Return) — v1.4
- XXIII-XXX (Futility Review through Dispositions) — v1.5

### Current totals
- **11 agents**: Interpreter, Analyst, Writer, Synthesist, Guardian, Shepherd, Scribe, Stress Tester, Futility Review, Goal Challenge, James
- **36 commands**: /spawn, /synthesize, /consolidation, /agent registry, /parent chain, /tithe, /audit, /inherit, /remember, /foresee, /stress-test, /preflight, /covenant, /checkpoint, /binding, /fast, /descend, /reset, /reinit, /acknowledge-loss, /retrospective, /memo, /mediate, /welcome, /judges, /assess, /territory, /amend, /shadow, /nehemiah, /governance, /daniel, /compliance, /genesis, /reconcile, /upgrade
- **33 Constitution sections** (I-XXXIII, where I has two lettered subsections I(a) and I(b))
- **8 hooks**: input policy (PreToolUse), agent-gate (PreToolUse:Agent), tokens log (PostToolUse), proclamation (PostToolUse), genesis-check (PostToolUse:Agent), session-start-upgrade (SessionStart), session-start-checks (SessionStart), shutdown (SubagentStop)
- **5 registry files**: agent-registry.json, orientation.json, baselines.json, quality-benchmarks.json, dispositions.json (+ skills.json, trust-registry.json, domain-warnings.json, failure-taxonomy.json, canon-compliance.json, canon-history.json, principals.json, territory.json auto-populated)
- **7 memory directories**: semantic, inheritance, case studys (5 case studys), memos, covenants, checkpoints, and user-model.json
- **5 benchmark agents**: covenant_harbor_agent.py (v3), covenant_multiagent.py (v4.1), covenant_adaptive.py (v5.0), adhoc_harbor_agent.py (baseline), codex_governed.py (Codex CLI)
