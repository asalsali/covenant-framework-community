#!/bin/bash
# ============================================================
# SPAWN GATE — PreToolUse Hook (Agent tool only)
# Enforces Constitution agent registry rules before any agent
# is spawned. Runs spawn checks, auto-registers, generates
# genesis briefing.
#
# Exit 2 = block the spawn with a message.
# Exit 0 = allow the spawn to proceed.
# ============================================================

# Python detection
if command -v cygpath >/dev/null 2>&1 || [ -n "$MSYSTEM" ]; then
  PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
else
  PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
fi
if [ -z "$PYTHON" ]; then
  echo "SPAWN GATE: python not found — cannot enforce agent_registry limits." >&2
  exit 2
fi

# Env setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
export _CF_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
command -v cygpath >/dev/null 2>&1 && _CF_PROJECT_DIR="$(cygpath -m "$_CF_PROJECT_DIR")"
export _CF_PROJECT_DIR
export _CF_ERR_LOG="$_CF_PROJECT_DIR/registry/hook-errors.log"

# Run module — captures stdout for result code routing
RESULT=$( cat | (cd "$SCRIPT_DIR" && "$PYTHON" -m lib.agent_gate) 2>>"$_CF_ERR_LOG" )

# Route on result code
case "$RESULT" in
  BLOCK:REINIT_REQUIRED*)
    echo "SPAWN GATE — RE-INITIALIZATION REQUIRED" >&2
    echo "   Constitution Section XXII: System has been dormant >24h." >&2
    echo "   Run /reinit before spawning new agents. Stale state is dangerous." >&2
    exit 2
    ;;
  BLOCK:CONSOLIDATION*)
    echo "SPAWN GATE — CONSOLIDATION ACTIVE" >&2
    echo "   Constitution Section V: No new agents spawn during Consolidation." >&2
    exit 2
    ;;
  BLOCK:BINDING_ACTIVE*)
    echo "SPAWN GATE — GRACEFUL ABORT ACTIVE" >&2
    echo "   Constitution Section XXI: The system is shutting down gracefully." >&2
    exit 2
    ;;
  BLOCK:SYNTHESIS_INVALID:*)
    REASON="${RESULT#BLOCK:SYNTHESIS_INVALID:}"
    echo "SPAWN GATE — SYNTHESIS VALIDATION FAILED" >&2
    echo "   Constitution Section XIV: $REASON" >&2
    exit 2
    ;;
  BLOCK:GENERATION:*)
    IFS=':' read -r _ _ GEN CAP <<< "$RESULT"
    echo "SPAWN GATE — GENERATION CAP REACHED" >&2
    echo "   Active agents at generation $GEN (limit: $CAP)." >&2
    exit 2
    ;;
  BLOCK:SIBLING:*)
    IFS=':' read -r _ _ PARENT COUNT LIMIT <<< "$RESULT"
    echo "SPAWN GATE — SIBLING LIMIT REACHED" >&2
    echo "   Parent '$PARENT' has $COUNT children (limit: $LIMIT)." >&2
    exit 2
    ;;
  BLOCK:COMPLEXITY:*)
    IFS=':' read -r _ _ COUNT THRESHOLD <<< "$RESULT"
    echo "SPAWN GATE — COMPLEXITY THRESHOLD REACHED" >&2
    echo "   $COUNT agents active (threshold: $THRESHOLD)." >&2
    exit 2
    ;;
  WARN:*|INFO:*|PASS:*)
    # Non-blocking results — log details and proceed
    case "$RESULT" in
      WARN:SYNTHESIS:*)
        echo "SYNTHESIS VALIDATED: Dual-parent spawn approved." >>"$_CF_ERR_LOG"
        ;;
      WARN:NO_CHARTER:*)
        CHARTER_COUNT="${RESULT#WARN:NO_CHARTER:}"
        echo "CHARTER ADVISORY: $CHARTER_COUNT agents spawned without an active covenant." >>"$_CF_ERR_LOG"
        ;;
      WARN:TRIBAL_BABEL:*)
        echo "TRIBAL BABEL WARNING: $RESULT" >>"$_CF_ERR_LOG"
        ;;
      WARN:OVERLAP:*)
        echo "OVERLAP DETECTION WARNING: $RESULT" >>"$_CF_ERR_LOG"
        ;;
      INFO:TRIBAL_OVERLAP:*)
        echo "TRIBAL COLLABORATION: $RESULT" >>"$_CF_ERR_LOG"
        ;;
      INFO:MEMORY_RETRIEVAL:*)
        _MR_PAYLOAD="${RESULT#INFO:MEMORY_RETRIEVAL:}"
        _MR_MODE="${_MR_PAYLOAD%%:*}"
        _MR_FILES="${_MR_PAYLOAD#*:}"
        echo "MEMORY RETRIEVAL (mode: $_MR_MODE): $_MR_FILES" >>"$_CF_ERR_LOG"
        ;;
      INFO:TELOS:*)
        TELOS="${RESULT#INFO:TELOS:}"
        echo "PROJECT TELOS: $TELOS" >>"$_CF_ERR_LOG"
        ;;
    esac
    exit 0
    ;;
  *)
    echo "SPAWN GATE: Unexpected result: $RESULT" >>"$_CF_ERR_LOG"
    exit 0
    ;;
esac
