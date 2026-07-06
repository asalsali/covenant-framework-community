#!/bin/bash
# ============================================================
# TOKEN LOG — PostToolUse Hook
# Logs completed tool calls, checks over-consumption, evaluates
# termination conditions (Constitution Section VI-C).
#
# Exit 2 = over-consumption critical or termination condition block.
# Exit 0 = normal operation.
# ============================================================

# Python detection
if command -v cygpath >/dev/null 2>&1 || [ -n "$MSYSTEM" ]; then
  PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
else
  PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
fi
if [ -z "$PYTHON" ]; then
  echo "TOKEN LOG: python not found — token tracking disabled. Install python3." >&2
  exit 0
fi

# Env setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
export _CF_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
command -v cygpath >/dev/null 2>&1 && _CF_PROJECT_DIR="$(cygpath -m "$_CF_PROJECT_DIR")"
export _CF_PROJECT_DIR
export _CF_ERR_LOG="$_CF_PROJECT_DIR/registry/hook-errors.log"

# Run module (cd to hooks dir for lib package resolution)
cat | (cd "$SCRIPT_DIR" && "$PYTHON" -m lib.token_log) 2>>"$_CF_ERR_LOG"
exit $?
