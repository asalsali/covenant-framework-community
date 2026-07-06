#!/bin/bash
# ============================================================
# SESSION START — Fires once when Claude Code session begins.
# Checks: spirit staleness, dormancy, permission mode, charter,
#          hook-errors.log rotation, spawn requests, dream cycle.
# All checks are advisory — always exits 0.
# ============================================================

# Python detection
if command -v cygpath >/dev/null 2>&1 || [ -n "$MSYSTEM" ]; then
  PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
else
  PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
fi
[ -z "$PYTHON" ] && exit 0

# Env setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
export _CF_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
command -v cygpath >/dev/null 2>&1 && _CF_PROJECT_DIR="$(cygpath -m "$_CF_PROJECT_DIR")"
export _CF_PROJECT_DIR
export _CF_ERR_LOG="$_CF_PROJECT_DIR/registry/hook-errors.log"

# Run module (cd to hooks dir for lib package resolution)
(cd "$SCRIPT_DIR" && "$PYTHON" -m lib.session_checks) 2>>"$_CF_ERR_LOG"
exit 0
