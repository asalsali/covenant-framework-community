#!/bin/bash
# ============================================================
# SHUTDOWN HANDLER — SubagentStop Hook
# Triggers handoff archival when a subagent completes.
# Runs: agent ID resolution, exit report validation, registry
#       archival, auto-memo, futility/mediation checks,
#       skills/baselines/trust/compliance updates.
#
# Exit 2 = exit report missing (Constitution Section VI violation).
# Exit 0 = normal shutdown.
# ============================================================

# Python detection
if command -v cygpath >/dev/null 2>&1 || [ -n "$MSYSTEM" ]; then
  PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
else
  PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
fi
if [ -z "$PYTHON" ]; then
  echo "SUNSET HOOK: python not found — shutdown ritual CANNOT run." >&2
  echo "   Install python3 or add it to PATH." >&2
  exit 2
fi

# Env setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
export _CF_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
command -v cygpath >/dev/null 2>&1 && _CF_PROJECT_DIR="$(cygpath -m "$_CF_PROJECT_DIR")"
export _CF_PROJECT_DIR
export _CF_ERR_LOG="$_CF_PROJECT_DIR/registry/hook-errors.log"

# Run module (cd to hooks dir for lib package resolution)
cat | (cd "$SCRIPT_DIR" && "$PYTHON" -m lib.subagent_shutdown) 2>>"$_CF_ERR_LOG"
exit $?
