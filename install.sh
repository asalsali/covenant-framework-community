#!/bin/bash
# Copyright (c) 2026 Alex Salsali (d/b/a Covenant Foundation)
# Licensed under the Covenant Public License v1.0
# See LICENSE for details
# ============================================================
# COVENANT FRAMEWORK — Install into an existing project
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/asalsali/covenant-framework/master/install.sh | bash
#   curl -sL https://raw.githubusercontent.com/asalsali/covenant-framework/master/install.sh | bash -s -- --runtime codex
#
# Or run locally:
#   bash install.sh [--runtime claude|codex|both]
#
# This will NOT overwrite existing files. If CLAUDE.md or
# .claude/settings.json already exist, it will guide you
# to merge them manually.
# ============================================================

set -e

RUNTIME="claude"
TIER="community"
while [ $# -gt 0 ]; do
  case "$1" in
    --runtime)
      RUNTIME="${2:-}"
      shift 2
      ;;
    --runtime=*)
      RUNTIME="${1#*=}"
      shift
      ;;
    --tier)
      TIER="${2:-}"
      shift 2
      ;;
    --tier=*)
      TIER="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: bash install.sh [--runtime claude|codex|both] [--tier community|network]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: bash install.sh [--runtime claude|codex|both] [--tier community|network]" >&2
      exit 1
      ;;
  esac
done

case "$RUNTIME" in
  claude|codex|both) ;;
  *)
    echo "Invalid runtime '$RUNTIME'. Expected: claude, codex, or both." >&2
    exit 1
    ;;
esac

case "$TIER" in
  community|network) ;;
  *)
    echo "Invalid tier '$TIER'. Expected: community or network." >&2
    exit 1
    ;;
esac

REPO="https://github.com/asalsali/covenant-framework.git"
TMP_DIR=$(mktemp -d)

if [ "$TIER" = "community" ]; then
  # Community tier: install only MANIFEST-listed files
  FRAMEWORK_FILES=()
  USE_MANIFEST=1
else
  # Network tier: install everything (current behavior)
  USE_MANIFEST=0
  FRAMEWORK_FILES=("registry" "memory")
  if [ "$RUNTIME" = "claude" ] || [ "$RUNTIME" = "both" ]; then
    FRAMEWORK_FILES+=(".claude/agents" ".claude/commands" ".claude/hooks" ".claude/settings.json")
  fi
  if [ "$RUNTIME" = "codex" ] || [ "$RUNTIME" = "both" ]; then
    FRAMEWORK_FILES+=("AGENTS.md" ".codex" ".agents/skills" "docs/CODEX.md" "install-codex.ps1")
  fi
  if [ "$RUNTIME" = "codex" ]; then
    FRAMEWORK_FILES+=("CLAUDE.md" "core")
  fi
fi

echo ""
echo "  COVENANT FRAMEWORK — Installation ($RUNTIME, $TIER tier)"
echo "  ══════════════════════════════════"
echo ""

# Clone into temp directory
echo "  Fetching framework..."
git clone --depth 1 --quiet "$REPO" "$TMP_DIR/covenant"

# Check for prior installation
SENTINEL="# --- COVENANT FRAMEWORK CANON ---"
if [ "$RUNTIME" = "claude" ] || [ "$RUNTIME" = "both" ]; then
  if [ -f "CLAUDE.md" ] && grep -q "$SENTINEL" "CLAUDE.md" 2>/dev/null; then
    echo "  ⚠  Covenant Framework Canon already installed in CLAUDE.md."
    echo "     To reinstall, remove everything below the sentinel line:"
    echo "     $SENTINEL"
    echo "  Skipping CLAUDE.md append."
    SKIP_CANON=1
  fi
fi

# Check for conflicts
CONFLICTS=0

if { [ "$RUNTIME" = "claude" ] || [ "$RUNTIME" = "both" ]; } && [ -f "CLAUDE.md" ] && [ -z "$SKIP_CANON" ]; then
  echo "  ⚠  CLAUDE.md already exists — will append Canon below your existing rules."
  CONFLICTS=1
fi

if { [ "$RUNTIME" = "claude" ] || [ "$RUNTIME" = "both" ]; } && [ -f ".claude/settings.json" ]; then
  echo "  ⚠  .claude/settings.json already exists — you'll need to merge hooks manually."
  echo "     See: https://github.com/asalsali/covenant-framework#if-you-already-have-claudesettingsjson"
  CONFLICTS=1
fi

if { [ "$RUNTIME" = "codex" ] || [ "$RUNTIME" = "both" ]; } && [ -f "AGENTS.md" ]; then
  echo "  ⚠  AGENTS.md already exists — leaving your Codex instructions unchanged."
  CONFLICTS=1
fi

# Copy framework files
if [ "$USE_MANIFEST" = "1" ]; then
  # Community tier: read MANIFEST.json and copy only listed files
  MANIFEST="$TMP_DIR/covenant/open-core/MANIFEST.json"
  if [ ! -f "$MANIFEST" ]; then
    echo "  ERROR: MANIFEST.json not found in repository." >&2
    rm -rf "$TMP_DIR"
    exit 1
  fi

  # Copy individual files from manifest
  if command -v jq >/dev/null 2>&1; then
    # jq available — use it for reliable JSON parsing
    jq -r '.files[].path' "$MANIFEST" | while read -r filepath; do
      src="$TMP_DIR/covenant/$filepath"
      if [ -e "$src" ]; then
        mkdir -p "$(dirname "$filepath")"
        [ ! -f "$filepath" ] && cp "$src" "$filepath"
      fi
    done

    # Create empty directories from manifest
    jq -r '.directories[].path' "$MANIFEST" | while read -r dirpath; do
      mkdir -p "$dirpath"
    done

    # Copy registry templates
    jq -r '.registryTemplates[].path' "$MANIFEST" | while read -r tplpath; do
      srcfile="$TMP_DIR/covenant/open-core/$(basename "$tplpath")"
      if [ -f "$srcfile" ]; then
        mkdir -p "$(dirname "$tplpath")"
        [ ! -f "$tplpath" ] && cp "$srcfile" "$tplpath"
      fi
    done
  else
    # Fallback: grep-based parsing (no jq dependency)
    grep '"path"' "$MANIFEST" | sed 's/.*"path": *"//;s/".*//' | while read -r filepath; do
      src="$TMP_DIR/covenant/$filepath"
      if [ -e "$src" ]; then
        mkdir -p "$(dirname "$filepath")"
        [ ! -f "$filepath" ] && cp "$src" "$filepath"
      fi
    done

    # Create standard empty directories
    for dirpath in registry memory/inheritance memory/memos memory/semantic memory/covenants memory/checkpoints; do
      mkdir -p "$dirpath"
    done
  fi

  # Use community settings template
  if [ "$RUNTIME" = "claude" ] || [ "$RUNTIME" = "both" ]; then
    COMMUNITY_SETTINGS="$TMP_DIR/covenant/open-core/settings.community.json"
    if [ ! -f ".claude/settings.json" ] && [ -f "$COMMUNITY_SETTINGS" ]; then
      mkdir -p .claude
      cp "$COMMUNITY_SETTINGS" .claude/settings.json
      echo "  ✓  .claude/settings.json created (4 community hooks)"
    fi
  fi
else
  # Network tier: copy everything (original behavior)
  for item in "${FRAMEWORK_FILES[@]}"; do
    src="$TMP_DIR/covenant/$item"
    if [ -e "$src" ]; then
      if [ -d "$src" ]; then
        if [ -d "$item" ]; then
          cp -rn "$src" "$(dirname "$item")/" 2>/dev/null || cp -r "$src" "$(dirname "$item")/"
        else
          mkdir -p "$(dirname "$item")"
          cp -r "$src" "$item"
        fi
      else
        if [ ! -f "$item" ]; then
          mkdir -p "$(dirname "$item")"
          cp "$src" "$item"
        fi
      fi
    fi
  done
fi

# Handle CLAUDE.md for the Claude runtime
if { [ "$RUNTIME" = "claude" ] || [ "$RUNTIME" = "both" ]; } && [ -z "$SKIP_CANON" ]; then
  if [ -f "CLAUDE.md" ]; then
    echo "" >> CLAUDE.md
    echo "$SENTINEL" >> CLAUDE.md
    echo "" >> CLAUDE.md
    cat "$TMP_DIR/covenant/CLAUDE.md" >> CLAUDE.md
    echo "  ✓  Canon appended to existing CLAUDE.md (with sentinel)"
  else
    echo "$SENTINEL" > CLAUDE.md
    echo "" >> CLAUDE.md
    cat "$TMP_DIR/covenant/CLAUDE.md" >> CLAUDE.md
    echo "  ✓  CLAUDE.md created"
  fi
fi

# Ensure .claude/settings.json exists
if { [ "$RUNTIME" = "claude" ] || [ "$RUNTIME" = "both" ]; } && [ ! -f ".claude/settings.json" ]; then
  cp "$TMP_DIR/covenant/.claude/settings.json" .claude/settings.json
  echo "  ✓  .claude/settings.json created (hooks wired)"
elif [ "$RUNTIME" = "claude" ] || [ "$RUNTIME" = "both" ]; then
  echo "  !  .claude/settings.json skipped — merge hooks manually"
fi

# Cleanup
rm -rf "$TMP_DIR"

echo ""
# Count actual installed files
if [ "$RUNTIME" = "claude" ] || [ "$RUNTIME" = "both" ]; then
  AGENT_COUNT=$(ls -1 .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
  CMD_COUNT=$(ls -1 .claude/commands/*.md 2>/dev/null | wc -l | tr -d ' ')
  HOOK_COUNT=$(ls -1 .claude/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')
  echo "  ✓  Claude agents:    .claude/agents/ ($AGENT_COUNT agents)"
  echo "  ✓  Claude commands:  .claude/commands/ ($CMD_COUNT commands)"
  echo "  ✓  Claude hooks:     .claude/hooks/ ($HOOK_COUNT hooks)"
fi
if [ "$RUNTIME" = "codex" ] || [ "$RUNTIME" = "both" ]; then
  CODEX_AGENT_COUNT=$(ls -1 .codex/agents/*.toml 2>/dev/null | wc -l | tr -d ' ')
  echo "  ✓  Codex instructions: AGENTS.md"
  echo "  ✓  Codex agents:       .codex/agents/ ($CODEX_AGENT_COUNT agents)"
  CODEX_SKILL_COUNT=$(ls -1 .agents/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
  echo "  ✓  Codex skills:       .agents/skills/ ($CODEX_SKILL_COUNT skills)"
  echo "  ✓  Codex hooks:        .codex/hooks/covenant_hook.py"
fi
echo "  ✓  Registry:  registry/ (genealogy.json, spirit.json)"
echo "  ✓  Memory:    memory/ (user-model, parables, epistles)"
echo ""
echo "  ══════════════════════════════════"
echo "  Installation complete ($TIER tier)."
echo ""
if [ "$TIER" = "community" ]; then
  echo "  Community Edition: 4 hooks, 12 agents, 16 commands."
  echo "  Upgrade to Network for advanced enforcement, health scoring,"
  echo "  hotspot detection, and 22 additional commands."
  echo "  See: https://covenant.foundation/network"
  echo ""
fi
if [ "$RUNTIME" = "codex" ]; then
  echo "  Run 'codex' and speak to the Interpreter."
elif [ "$RUNTIME" = "both" ]; then
  echo "  Run 'claude' or 'codex' and speak to the Interpreter."
else
  echo "  Run 'claude' and speak to the Interpreter."
fi
echo "  ══════════════════════════════════"
echo ""
