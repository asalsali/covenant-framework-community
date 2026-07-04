#!/bin/bash
# ============================================================
# SESSION START — Fires once when Claude Code session begins.
# Checks for stale state that the Interpreter would otherwise
# need to remember to check (reducing prompt dependency).
#
# Checks:
#   1. Spirit staleness — is orientation.json older than 7 days?
#   2. Dormancy check — is user-model.json older than 24h?
#   3. Permission mode — warn if subagents will be read-only
#   4. Charter check — no covenants with >5 agents? (Section XVIII)
# ============================================================

# Detect python — prefer 'python' on Windows (python3 shim causes Permission Denied in Git Bash)
if command -v cygpath >/dev/null 2>&1 || [ -n "$MSYSTEM" ]; then
  PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
else
  PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
fi
if [ -z "$PYTHON" ]; then
  # No python available — silently skip (advisory, not a block)
  exit 0
fi

# Derive project root from this script's location (.claude/hooks/ → project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# Convert Git Bash /c/ path to C:/ for Python compatibility on Windows
command -v cygpath >/dev/null 2>&1 && PROJECT_DIR="$(cygpath -m "$PROJECT_DIR")"

"$PYTHON" -c "
import json, os
from datetime import datetime, timezone, timedelta

project_dir = '$PROJECT_DIR'
now = datetime.now(timezone.utc)
warnings = []

# --- Spirit staleness check ---
spirit_path = os.path.join(project_dir, 'registry', 'orientation.json')
if os.path.exists(spirit_path):
    try:
        with open(spirit_path) as f:
            spirit = json.load(f)
        last_updated = spirit.get('lastUpdatedAt', '')
        if last_updated:
            try:
                updated_dt = datetime.fromisoformat(last_updated.replace('Z', '+00:00'))
                age = now - updated_dt
                if age > timedelta(days=7):
                    warnings.append(f'STALE SPIRIT: orientation.json last updated {age.days} days ago. The orientation may no longer apply. Run /consolidation or update spirit manually.')
            except: pass
    except: pass
else:
    warnings.append('NO SPIRIT: registry/orientation.json not found. Run /genesis to initialize the framework.')

# --- Dormancy check ---
user_model_path = os.path.join(project_dir, 'memory', 'user-model.json')
if os.path.exists(user_model_path):
    try:
        with open(user_model_path) as f:
            um = json.load(f)
        last_updated = um.get('lastUpdated', '')
        if last_updated:
            try:
                updated_dt = datetime.fromisoformat(last_updated.replace('Z', '+00:00'))
                age = now - updated_dt
                if age > timedelta(hours=24):
                    warnings.append(f'DORMANCY DETECTED: User model last updated {age.days}d {age.seconds//3600}h ago. Consider running /reinit to re-orient before accepting requests.')
                    # Write reinit-required flag so spawn gate blocks until /reinit runs (Constitution Section XXII)
                    reinit_flag = os.path.join(project_dir, 'registry', 'reinit-required.flag')
                    try:
                        with open(reinit_flag, 'w') as rf:
                            rf.write('')
                    except: pass
            except: pass
    except: pass

# --- Permission mode check ---
# Claude Code sets CLAUDE_CODE_PERMISSION_MODE in the environment.
# If not set or 'default', subagents are read-only (no Write/Edit/Bash).
perm_mode = os.environ.get('CLAUDE_CODE_PERMISSION_MODE', '')
settings_path = os.path.join(project_dir, '.claude', 'settings.local.json')
# Also check settings.local.json for permission grants
has_local_perms = os.path.exists(settings_path)

# Check if user's global settings grant write permissions
global_settings = os.path.expanduser('~/.claude/settings.json')
global_grants_write = False
if os.path.exists(global_settings):
    try:
        with open(global_settings) as f:
            gs = json.load(f)
        allow = gs.get('permissions', {}).get('allow', [])
        if any(t in allow for t in ['Write', 'Edit', 'Bash']):
            global_grants_write = True
    except: pass

if not global_grants_write and not has_local_perms and perm_mode != 'dangerously_skip_permissions':
    warnings.append('PERMISSION MODE: Subagents will be READ-ONLY in default permission mode. Multi-agent spawning will fall back to delegation pattern (subagent plans, Interpreter executes). For full multi-agent execution, run with --dangerously-skip-permissions or grant Write/Edit permissions to subagents.')

# --- Charter check (Constitution Section XVIII) ---
covenants_dir = os.path.join(project_dir, 'memory', 'covenants')
agent_registry_path = os.path.join(project_dir, 'registry', 'agent-registry.json')
covenant_count = 0
if os.path.isdir(covenants_dir):
    covenant_count = len([f for f in os.listdir(covenants_dir) if os.path.isfile(os.path.join(covenants_dir, f))])
if covenant_count == 0:
    total_agents = 0
    try:
        with open(agent_registry_path) as f:
            reg = json.load(f)
        total_agents = len(reg.get('agents', []))
    except: pass
    if total_agents > 5:
        warnings.append(f'NO CHARTER: 0 active covenants with {total_agents} agents in registry.' + chr(10) + '   Constitution XVIII: Consider /charter to define success criteria for this project.')

# --- hook-errors.log rotation (truncate to last 200 lines if >500) ---
hook_err_log = os.path.join(project_dir, '.claude', 'hooks', 'hook-errors.log')
try:
    if os.path.exists(hook_err_log):
        with open(hook_err_log, 'r', encoding='utf-8', errors='replace') as hf:
            lines = hf.readlines()
        if len(lines) > 500:
            with open(hook_err_log, 'w', encoding='utf-8') as hf:
                hf.writelines(lines[-200:])
except: pass

# --- Pending spawn request surfacing (Constitution Section XXXV) ---
memos_dir = os.path.join(project_dir, 'memory', 'memos')
if os.path.isdir(memos_dir):
    import glob as _glob
    _pending_count = 0
    for _fpath in _glob.glob(os.path.join(memos_dir, 'spawn-request-*.md')):
        try:
            with open(_fpath, 'r', encoding='utf-8', errors='replace') as _fh:
                _content = _fh.read(500)
            if '"approvalStatus": "pending"' in _content or "'approvalStatus': 'pending'" in _content:
                _pending_count += 1
        except: pass
    if _pending_count > 0:
        warnings.append(f'LATERAL SPAWN REQUESTS: {_pending_count} pending request(s) await Interpreter review (Constitution Section XXXV)')

# --- Dream cycle staleness check (Constitution Section V-B) ---
dream_log_path = os.path.join(project_dir, 'registry', 'dream-log.json')
if os.path.exists(dream_log_path):
    try:
        with open(dream_log_path) as f:
            dream_data = json.load(f)
        cycles = dream_data.get('cycles', [])
        last_ran = None
        for cycle in reversed(cycles):
            ran_at = cycle.get('ranAt', '')
            if ran_at:
                last_ran = ran_at
                break
        if last_ran:
            try:
                ran_dt = datetime.fromisoformat(last_ran.replace('Z', '+00:00'))
                dream_age = now - ran_dt
                if dream_age > timedelta(hours=12):
                    warnings.append('DREAM_CYCLE: System idle >12h since last dream cycle. Consider running a dream cycle (Section V-B).')
            except: pass
        else:
            warnings.append('DREAM_CYCLE: System idle >12h since last dream cycle. Consider running a dream cycle (Section V-B).')
    except: pass

# --- Output warnings ---
import sys
for w in warnings:
    print(f'\u26a0\ufe0f  {w}', file=sys.stderr)
" 2>>"$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/../../registry/hook-errors.log"

exit 0
