# Quickstart: Your First Governed Agent

Demonstrates the Covenant Framework in under 30 seconds.

## Run it

```bash
cd examples/quickstart
claude
```

Then say:

```
/spawn "List all Python files in this directory and summarize what each one does"
```

## What happens

1. The **Interpreter** reads your request and proposes a spawn plan
2. You approve -- an **Analyst** agent spawns
3. The Analyst runs through the **Genesis Phase** (reads constitution, orientation, prior learnings)
4. It executes: reads files, produces findings
5. At shutdown: writes an **exit report** to `memory/inheritance/`
6. Next time you spawn a similar agent, it reads the prior exit report first

## What to look for

After the agent completes, check:

- `registry/agent-registry.json` -- the agent is registered and archived
- `memory/inheritance/` -- the exit report with findings
- `registry/orientation.json` -- shared state that kept the agent aligned

## Next steps

- Try `/consolidate` to run a consolidation cycle
- Try `/audit` to check system health
- Try `/remember "what did we learn?"` to query semantic memory
