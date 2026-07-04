#!/bin/bash
# ============================================================
# TOKEN LOG — PostToolUse Hook
# Logs completed tool calls and checks for over-consumption patterns.
#
# Single responsibility: token logging + over-consumption detection.
# Input Policy enforcement is handled by pre-tool-input_policy.sh.
# ============================================================

# Detect python command
# Detect python — prefer 'python' on Windows (python3 shim causes Permission Denied in Git Bash)
if command -v cygpath >/dev/null 2>&1 || [ -n "$MSYSTEM" ]; then
  PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
else
  PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
fi
if [ -z "$PYTHON" ]; then
  echo "🚫 TOKEN LOG: python not found — token tracking disabled. Install python3." >&2
  exit 2
fi

# Error log — replaces silent 2>/dev/null suppression on Python blocks
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_ERR_LOG="${_HOOK_DIR:+${_HOOK_DIR}/../../registry/hook-errors.log}"
[ -n "$_ERR_LOG" ] && command -v cygpath >/dev/null 2>&1 && _ERR_LOG="$(cygpath -m "$_ERR_LOG")"
_ERR_LOG="${_ERR_LOG:-/dev/null}"

INPUT=$(cat)

eval "$( printf '%s' "$INPUT" | "$PYTHON" -c "
import sys, json, os

d = json.load(sys.stdin)
# Claude Code provides 'agent_id' for subagents spawned via Agent tool.
# These are internal thread IDs (e.g. 'a69488e0287388db4'), not canonical IDs.
raw_agent_id = d.get('agent_id', '')
session_id = d.get('session_id', 'unknown')

# Resolve canonical agent ID from agent-registry.json
# The agent-gate hook registers agents with canonical IDs like 'writer-20260506T051130'.
# When only ONE non-root active agent exists, we can confidently attribute.
# When multiple exist, we log the raw ID to avoid misattribution — reconciliation
# happens at shutdown when the agent's thread ID can be correlated with its canonical ID.
canonical_id = ''
if raw_agent_id:
    agent_registry_path = os.path.join(os.environ.get('CLAUDE_PROJECT_DIR', '.'), 'registry', 'agent-registry.json')
    if not os.path.exists(agent_registry_path):
        script_dir = os.path.dirname(os.path.abspath('__file__'))
        agent_registry_path = os.path.join(script_dir, '..', '..', 'registry', 'agent-registry.json')
    try:
        with open(agent_registry_path) as f:
            reg = json.load(f)
        # First: check if raw_agent_id matches a canonical ID directly
        for a in reg.get('agents', []):
            if a.get('id') == raw_agent_id:
                canonical_id = raw_agent_id
                break
        if not canonical_id:
            # Second: check thread-map.json for thread ID -> canonical ID mapping
            thread_map_path = os.path.join(os.path.dirname(agent_registry_path), 'thread-map.json')
            try:
                with open(thread_map_path) as f:
                    thread_map = json.load(f)
                # Fast path: thread ID already assigned to a canonical agent
                for cid, entry in thread_map.items():
                    if entry.get('threadId') == raw_agent_id and entry.get('status') == 'active':
                        canonical_id = cid
                        break
                if not canonical_id:
                    # Slow path: find unassigned entry born within 120s of now
                    from datetime import datetime, timezone
                    now = datetime.now(timezone.utc)
                    unassigned = []
                    for cid, entry in thread_map.items():
                        if entry.get('status') == 'active' and not entry.get('threadId'):
                            try:
                                born = datetime.fromisoformat(entry['bornAt'].replace('Z', '+00:00'))
                                age = (now - born).total_seconds()
                                if 0 <= age <= 120:
                                    unassigned.append((cid, entry, age))
                            except: pass
                    if unassigned:
                        # Most recently born first
                        unassigned.sort(key=lambda x: x[2])
                        canonical_id = unassigned[0][0]
                        # Assign thread ID and write back
                        thread_map[canonical_id]['threadId'] = raw_agent_id
                        try:
                            with open(thread_map_path, 'w') as f:
                                json.dump(thread_map, f, indent=2)
                        except: pass
            except: pass
        if not canonical_id:
            # Tier 2.5: check if raw_agent_id is a canonical ID (key) in thread-map
            try:
                if raw_agent_id in thread_map and thread_map[raw_agent_id].get('status') == 'active':
                    canonical_id = raw_agent_id
            except: pass
        if not canonical_id:
            # Third: genesis-briefing fallback REMOVED (was misattributing meals
            # to last-spawned agent). Fail loud instead of silent misattribution.
            import sys
            print(f'MEAL ATTRIBUTION WARNING: no canonical ID resolved for thread {raw_agent_id}. '
                  f'Thread-map had no match. Meals may be untracked.', file=sys.stderr)
        if not canonical_id:
            # Fourth: single active agent fallback
            active = [a for a in reg.get('agents', []) if a.get('status') == 'active' and a.get('id') != 'root']
            if len(active) == 1:
                canonical_id = active[0].get('id', '')
    except: pass

if canonical_id:
    agent_id = canonical_id
elif not raw_agent_id:
    subagent_type = d.get('subagent_type', '')
    if subagent_type:
        agent_id = f'subagent-{subagent_type}'
    else:
        agent_id = 'root'
else:
    agent_id = raw_agent_id

print(f'AGENT_ID=\"{agent_id}\"')
print(f'TOOL=\"{d.get(\"tool_name\", \"\")}\"')
print(f'SESSION_ID=\"{session_id}\"')
ti = d.get('tool_input', '')
size = len(json.dumps(ti)) if ti else 0
print(f'INPUT_SIZE={size}')
" 2>>"$_ERR_LOG" )"

TIMESTAMP=$( "$PYTHON" -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>>"$_ERR_LOG" )

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)}"
# Convert Git Bash /c/ path to C:/ for Python compatibility on Windows
command -v cygpath >/dev/null 2>&1 && PROJECT_DIR="$(cygpath -m "$PROJECT_DIR")"
LOG_FILE="$PROJECT_DIR/registry/token-log.json"
mkdir -p "$PROJECT_DIR/registry"

# ── Log the meal ───────────────────────────────────────────
# Pass all variables via stdin JSON to avoid Windows backslash escaping issues
# Normalize any remaining backslashes in paths to forward slashes
_LOG_FILE_SAFE="$(printf '%s' "$LOG_FILE" | sed 's/\\/\//g')"
printf '%s' "{\"log_file\":\"${_LOG_FILE_SAFE}\",\"agent\":\"$AGENT_ID\",\"session\":\"$SESSION_ID\",\"tool\":\"$TOOL\",\"inputSize\":${INPUT_SIZE:-0},\"timestamp\":\"$TIMESTAMP\"}" | "$PYTHON" -c "
import json, os, shutil, sys, time

meta = json.load(sys.stdin)
log_file = meta['log_file']
bak_file = log_file + '.bak'
lock_file = log_file + '.lock'

# Acquire file lock — retry up to 5 times with 0.2s backoff
acquired = False
for attempt in range(5):
    try:
        fd = os.open(lock_file, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.write(fd, str(os.getpid()).encode())
        os.close(fd)
        acquired = True
        break
    except FileExistsError:
        # Check if lock is stale (>10s old)
        try:
            if time.time() - os.path.getmtime(lock_file) > 10:
                os.remove(lock_file)
                continue
        except: pass
        time.sleep(0.2 * (attempt + 1))

if not acquired:
    _err_log = '$_ERR_LOG'
    try:
        with open(_err_log, 'a') as _lf:
            _lf.write('TOKEN LOG: Could not acquire lock — skipping this entry to avoid data loss.\n')
    except: pass
    sys.exit(0)

try:
    # Read existing log — fall back to backup if main file is corrupted
    log = []
    if os.path.exists(log_file):
        try:
            with open(log_file, encoding='utf-8') as f:
                log = json.load(f)
        except (json.JSONDecodeError, IOError):
            if os.path.exists(bak_file):
                try:
                    with open(bak_file, encoding='utf-8') as f:
                        log = json.load(f)
                    try:
                        with open('$_ERR_LOG', 'a') as _lf:
                            _lf.write(f'TOKEN LOG: Recovered {len(log)} entries from backup.\n')
                    except: pass
                except (json.JSONDecodeError, IOError):
                    pass

    log.append({
        'agent': meta['agent'],
        'session': meta['session'],
        'tool': meta['tool'],
        'inputSize': meta['inputSize'],
        'timestamp': meta['timestamp']
    })

    # Rotation: archive older half when log exceeds 2000 entries
    if len(log) > 2000:
        archive_count = len(log) - 1000  # Keep most recent 1000
        archive_entries = log[:archive_count]
        log = log[archive_count:]
        # Write archive file
        archive_date = meta['timestamp'][:10].replace('-', '')
        archive_path = log_file.replace('token-log.json', f'token-log-archive-{archive_date}.json')
        # Append to existing archive if it exists
        existing_archive = []
        if os.path.exists(archive_path):
            try:
                with open(archive_path, encoding='utf-8') as f:
                    existing_archive = json.load(f)
            except: pass
        existing_archive.extend(archive_entries)
        with open(archive_path, 'w', encoding='utf-8') as f:
            json.dump(existing_archive, f)
        try:
            with open('$_ERR_LOG', 'a') as _lf:
                _lf.write(f'TOKEN LOG: Rotated {archive_count} entries to {os.path.basename(archive_path)}. Kept {len(log)}.\n')
        except: pass

    # Backup before write
    if os.path.exists(log_file) and os.path.getsize(log_file) > 2:
        shutil.copy2(log_file, bak_file)

    with open(log_file, 'w', encoding='utf-8') as f:
        json.dump(log, f, indent=2)
finally:
    # Always release lock
    try:
        os.remove(lock_file)
    except: pass
" 2>>"$_ERR_LOG"

# ── Cumulative token tracking ─────────────────────────────
CUMULATIVE_FILE="$PROJECT_DIR/registry/token-cumulative.json"
printf '%s' "{\"cumulative_file\":\"$(printf '%s' "$CUMULATIVE_FILE" | sed 's/\\/\//g')\",\"agent\":\"$AGENT_ID\",\"session\":\"$SESSION_ID\",\"timestamp\":\"$TIMESTAMP\"}" | "$PYTHON" -c "
import json, os, sys

meta = json.load(sys.stdin)
cum_file = meta['cumulative_file']

# Read or initialize
try:
    with open(cum_file, encoding='utf-8') as f:
        cum = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cum = {'description': 'Cumulative token accounting across sessions', 'sessions': [], 'totalMeals': 0, 'totalSessions': 0}

# Find or create session entry
session = None
for s in cum['sessions']:
    if s.get('sessionId') == meta['session']:
        session = s
        break

if session is None:
    session = {
        'sessionId': meta['session'],
        'startedAt': meta['timestamp'],
        'lastMealAt': meta['timestamp'],
        'mealCount': 0,
        'agents': []
    }
    cum['sessions'].append(session)
    cum['totalSessions'] += 1

session['mealCount'] += 1
session['lastMealAt'] = meta['timestamp']
if meta['agent'] not in session.get('agents', []):
    session['agents'].append(meta['agent'])

cum['totalMeals'] += 1
cum['lastUpdated'] = meta['timestamp']

# Keep only last 20 sessions to prevent unbounded growth
cum['sessions'] = cum['sessions'][-20:]

with open(cum_file, 'w', encoding='utf-8') as f:
    json.dump(cum, f, indent=2)

# Cross-session over-consumption check — batch warnings (1 per 50 meals, not every meal)
recent = cum['sessions'][-3:]
recent_total = sum(s.get('mealCount', 0) for s in recent)
if recent_total > 600 and recent_total % 50 == 0:
    try:
        with open('$_ERR_LOG', 'a') as _lf:
            _lf.write(f'OVER-CONSUMPTION WARNING: {recent_total} meals across last {len(recent)} sessions. Cross-session budget exceeded. Next warning at {recent_total + 50}.\n')
    except: pass
" 2>>"$_ERR_LOG"

# ── Over-consumption check ─────────────────────────────────────────
if [ -f "$LOG_FILE" ]; then
  AGENT_MEALS=$( printf '%s' "{\"log_file\":\"${_LOG_FILE_SAFE}\",\"agent\":\"$AGENT_ID\",\"session\":\"$SESSION_ID\"}" | "$PYTHON" -c "
import json, sys
meta = json.load(sys.stdin)
with open(meta['log_file'], encoding='utf-8') as f:
    log = json.load(f)
count = sum(1 for e in log if e.get('agent') == meta['agent'] and e.get('session') == meta['session'])
print(count)
" 2>>"$_ERR_LOG" )

  # Read meal thresholds from canon config (agent-registry.json)
  # Falls back to hardcoded defaults if read fails
  read MEAL_LIMIT_ROOT MEAL_WARN_ROOT MEAL_LIMIT_CHILD MEAL_WARN_CHILD < <( "$PYTHON" -c "
import json, os
try:
    reg_path = os.path.join('$(dirname "$AGENT_REGISTRY_PATH")', 'agent-registry.json')
    with open('$AGENT_REGISTRY_PATH', encoding='utf-8') as f:
        reg = json.load(f)
    canon = reg.get('canon', {})
    print(canon.get('mealLimitRoot', 120), canon.get('mealWarnRoot', 50), canon.get('mealLimitChild', 40), canon.get('mealWarnChild', 20))
except:
    print(120, 50, 40, 20)
" 2>>"$_ERR_LOG" )
  MEAL_LIMIT_ROOT=${MEAL_LIMIT_ROOT:-120}
  MEAL_WARN_ROOT=${MEAL_WARN_ROOT:-50}
  MEAL_LIMIT_CHILD=${MEAL_LIMIT_CHILD:-40}
  MEAL_WARN_CHILD=${MEAL_WARN_CHILD:-20}

  # Interpreter (root) has a higher threshold — it legitimately makes many calls
  # during interpretation, coordination, and governance rituals (/consolidation, /audit).
  # Child agents have a strict meal limit from canon config.
  if [ "$AGENT_ID" = "root" ]; then
    if [ "${AGENT_MEALS:-0}" -gt "$MEAL_LIMIT_ROOT" ]; then
      echo "🚫 OVER-CONSUMPTION CRITICAL: Interpreter has consumed ${AGENT_MEALS} meals this session (limit: ${MEAL_LIMIT_ROOT})." >&2
      echo "This session has exceeded even the Interpreter's expanded budget." >&2
      echo "Run /consolidation to consolidate, then start a new session." >&2
      exit 2
    elif [ "${AGENT_MEALS:-0}" -gt "$MEAL_WARN_ROOT" ]; then
      echo "OVER-CONSUMPTION WARNING: Interpreter has consumed ${AGENT_MEALS} meals this session." >>"$_ERR_LOG"
      echo "Consider running /consolidation soon. Long sessions lose coherence." >>"$_ERR_LOG"
    fi
  else
    if [ "${AGENT_MEALS:-0}" -gt "$MEAL_LIMIT_CHILD" ]; then
      echo "🚫 OVER-CONSUMPTION CRITICAL: Agent '$AGENT_ID' has consumed ${AGENT_MEALS} meals this session (limit: ${MEAL_LIMIT_CHILD})." >&2
      echo "This agent MUST be shutdown immediately. Its mandate is too broad." >&2
      echo "Run /binding to gracefully abort, or /consolidation to consolidate." >&2
      exit 2
    elif [ "${AGENT_MEALS:-0}" -gt "$MEAL_WARN_CHILD" ]; then
      echo "OVER-CONSUMPTION WARNING: Agent '$AGENT_ID' has consumed ${AGENT_MEALS} meals this session." >>"$_ERR_LOG"
      echo "Consider whether this agent's mandate is too broad. 'Measure your token before your second meal.'" >>"$_ERR_LOG"
    fi
  fi
fi

# ── Termination Conditions (Constitution Section VI-C) ─────────────
# Evaluate declarative termination conditions from the agent's registry entry.
# This runs AFTER the legacy over-consumption check (which remains for backward compat).
if [ "$AGENT_ID" != "root" ] && [ -f "$PROJECT_DIR/registry/agent-registry.json" ]; then
  TC_RESULT=$( printf '%s' "{\"project_dir\":\"$(printf '%s' "$PROJECT_DIR" | sed 's/\\/\//g')\",\"agent\":\"$AGENT_ID\",\"session\":\"$SESSION_ID\",\"timestamp\":\"$TIMESTAMP\",\"agent_meals\":${AGENT_MEALS:-0}}" | "$PYTHON" -c "
import json, sys, os
from datetime import datetime, timezone

meta = json.load(sys.stdin)
reg_path = os.path.join(meta['project_dir'], 'registry', 'agent-registry.json')

try:
    with open(reg_path, encoding='utf-8') as f:
        reg = json.load(f)
except:
    print('SKIP')
    sys.exit(0)

# Find this agent's entry
agent_entry = None
for a in reg.get('agents', []):
    if a.get('id') == meta['agent']:
        agent_entry = a
        break

if not agent_entry:
    print('SKIP')
    sys.exit(0)

tc = agent_entry.get('terminationConditions')
if not tc:
    # Apply defaults based on tokensExpected (Constitution VI-C Defaults)
    tier = agent_entry.get('tokensExpected', 'medium')
    defaults = {'low': 15, 'medium': 30, 'high': 60}
    tc = {'type': 'mealLimit', 'value': defaults.get(tier, 30), 'action': 'block'}

def evaluate_condition(cond, meals, born_at):
    ctype = cond.get('type')
    value = cond.get('value')
    action = cond.get('action', 'block')

    # Handle combinators
    if 'any' in cond:
        for sub in cond['any']:
            triggered, sub_action, reason = evaluate_condition(sub, meals, born_at)
            if triggered:
                return True, sub_action, reason
        return False, action, ''
    if 'all' in cond:
        reasons = []
        for sub in cond['all']:
            triggered, sub_action, reason = evaluate_condition(sub, meals, born_at)
            if not triggered:
                return False, action, ''
            reasons.append(reason)
        return True, action, ' AND '.join(reasons)

    if ctype == 'mealLimit':
        if meals >= int(value):
            return True, action, f'mealLimit {meals}/{value}'
    elif ctype == 'wallClock':
        if born_at:
            try:
                born = datetime.fromisoformat(born_at.replace('Z', '+00:00'))
                elapsed = (datetime.now(timezone.utc) - born).total_seconds()
                # Parse ISO duration (simple: PTxxM or PTxxH format)
                dur_str = str(value).upper()
                limit_secs = 0
                if 'H' in dur_str:
                    limit_secs += int(dur_str.split('PT')[1].split('H')[0]) * 3600
                if 'M' in dur_str:
                    m_part = dur_str.split('H')[-1] if 'H' in dur_str else dur_str.split('PT')[1]
                    if 'M' in m_part:
                        limit_secs += int(m_part.split('M')[0]) * 60
                if limit_secs > 0 and elapsed >= limit_secs:
                    return True, action, f'wallClock {int(elapsed)}s/{limit_secs}s'
            except:
                pass
    return False, action, ''

meals = int(meta.get('agent_meals', 0))
born_at = agent_entry.get('bornAt', '')

triggered, action, reason = evaluate_condition(tc, meals, born_at)

if triggered:
    print(f'{action.upper()}:{reason}')
else:
    print('OK')
" 2>>"$_ERR_LOG" )

  case "$TC_RESULT" in
    BLOCK:*)
      TC_REASON="${TC_RESULT#BLOCK:}"
      echo "TERMINATION CONDITION TRIGGERED [BLOCK]: $TC_REASON for agent '$AGENT_ID'." >&2
      echo "Agent must write its exit report now. Subsequent tool calls will be blocked." >&2
      echo "TERMINATION BLOCK: $AGENT_ID — $TC_REASON [$TIMESTAMP]" >>"$_ERR_LOG"
      exit 2
      ;;
    WARN:*)
      TC_REASON="${TC_RESULT#WARN:}"
      echo "TERMINATION CONDITION [WARN]: $TC_REASON for agent '$AGENT_ID'." >>"$_ERR_LOG"
      ;;
  esac
fi

exit 0
