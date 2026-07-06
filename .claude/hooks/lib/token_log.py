"""Token logging and over-consumption detection.

Handles: agent ID resolution, token logging (with file locking),
cumulative session tracking, meal limit checking, and termination
condition evaluation.

Always exits 0 -- post-tool hooks cannot block.
"""

import json
import os
import shutil
import sys
import time
from datetime import datetime, timezone, timedelta

from .hooks_common import get_project_dir, get_err_log_path, get_timestamp, log_error
from .resolve_agent import resolve_canonical_id
from .registry_ops import read_registry, get_canon_config


def _resolve_agent_id(input_data, project_dir):
    """Resolve the agent ID from hook input."""
    raw_agent_id = input_data.get('agent_id', '')
    session_id = input_data.get('session_id', 'unknown')

    canonical_id = ''
    if raw_agent_id:
        registry_path = os.path.join(project_dir, 'registry', 'agent-registry.json')
        thread_map_path = os.path.join(project_dir, 'registry', 'thread-map.json')
        canonical_id, method = resolve_canonical_id(
            raw_agent_id,
            registry_path,
            thread_map_path,
            assign_thread=True,
        )
        if method == 'unresolved' and raw_agent_id:
            print(
                f'MEAL ATTRIBUTION WARNING: no canonical ID resolved for thread {raw_agent_id}. '
                f'Thread-map had no match. Meals logged under raw thread ID.',
                file=sys.stderr,
            )

    if canonical_id:
        agent_id = canonical_id
    elif not raw_agent_id:
        subagent_type = input_data.get('subagent_type', '')
        agent_id = f'subagent-{subagent_type}' if subagent_type else 'root'
    else:
        agent_id = raw_agent_id

    tool_name = input_data.get('tool_name', '')
    tool_input = input_data.get('tool_input', '')
    input_size = len(json.dumps(tool_input)) if tool_input else 0

    return agent_id, session_id, tool_name, input_size


def _log_meal(log_file, agent_id, session_id, tool_name, input_size, timestamp, err_log):
    """Log a single tool call to token-log.json with file locking."""
    lock_file = log_file + '.lock'
    bak_file = log_file + '.bak'

    # Acquire file lock
    acquired = False
    for attempt in range(5):
        try:
            fd = os.open(lock_file, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            acquired = True
            break
        except FileExistsError:
            try:
                if time.time() - os.path.getmtime(lock_file) > 10:
                    os.remove(lock_file)
                    continue
            except (OSError, FileNotFoundError):
                pass
            time.sleep(0.2 * (attempt + 1))

    if not acquired:
        log_error(err_log, 'TOKEN LOG: Could not acquire lock -- skipping this entry to avoid data loss.')
        return

    try:
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
                        log_error(err_log, f'TOKEN LOG: Recovered {len(log)} entries from backup.')
                    except (json.JSONDecodeError, IOError):
                        pass

        log.append({
            'agent': agent_id,
            'session': session_id,
            'tool': tool_name,
            'inputSize': input_size,
            'timestamp': timestamp,
        })

        # Rotation
        if len(log) > 2000:
            archive_count = len(log) - 1000
            archive_entries = log[:archive_count]
            log = log[archive_count:]
            archive_date = timestamp[:10].replace('-', '')
            archive_path = log_file.replace('token-log.json', f'token-log-archive-{archive_date}.json')
            existing_archive = []
            if os.path.exists(archive_path):
                try:
                    with open(archive_path, encoding='utf-8') as f:
                        existing_archive = json.load(f)
                except (FileNotFoundError, json.JSONDecodeError):
                    pass
            existing_archive.extend(archive_entries)
            with open(archive_path, 'w', encoding='utf-8') as f:
                json.dump(existing_archive, f)
            log_error(err_log, f'TOKEN LOG: Rotated {archive_count} entries to {os.path.basename(archive_path)}. Kept {len(log)}.')

        # Backup before write
        if os.path.exists(log_file) and os.path.getsize(log_file) > 2:
            shutil.copy2(log_file, bak_file)

        with open(log_file, 'w', encoding='utf-8') as f:
            json.dump(log, f, indent=2)
    finally:
        try:
            os.remove(lock_file)
        except OSError:
            pass


def _log_cumulative(cumulative_file, agent_id, session_id, timestamp, err_log):
    """Update cumulative token tracking across sessions."""
    try:
        with open(cumulative_file, encoding='utf-8') as f:
            cum = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        cum = {'description': 'Cumulative token accounting across sessions', 'sessions': [], 'totalMeals': 0, 'totalSessions': 0}

    session = None
    for s in cum['sessions']:
        if s.get('sessionId') == session_id:
            session = s
            break

    if session is None:
        session = {
            'sessionId': session_id,
            'startedAt': timestamp,
            'lastMealAt': timestamp,
            'mealCount': 0,
            'agents': [],
        }
        cum['sessions'].append(session)
        cum['totalSessions'] += 1

    session['mealCount'] += 1
    session['lastMealAt'] = timestamp
    if agent_id not in session.get('agents', []):
        session['agents'].append(agent_id)

    cum['totalMeals'] += 1
    cum['lastUpdated'] = timestamp
    cum['sessions'] = cum['sessions'][-20:]

    with open(cumulative_file, 'w', encoding='utf-8') as f:
        json.dump(cum, f, indent=2)

    # Cross-session over-consumption check
    recent = cum['sessions'][-3:]
    recent_total = sum(s.get('mealCount', 0) for s in recent)
    if recent_total > 600 and recent_total % 50 == 0:
        log_error(err_log, f'OVER-CONSUMPTION WARNING: {recent_total} meals across last {len(recent)} sessions. Cross-session budget exceeded. Next warning at {recent_total + 50}.')


def _check_meal_limits(log_file, agent_id, session_id, project_dir, err_log):
    """Check meal limits and termination conditions. Returns exit code."""
    if not os.path.exists(log_file):
        return 0

    # Count agent meals
    try:
        with open(log_file, encoding='utf-8') as f:
            log = json.load(f)
        agent_meals = sum(1 for e in log if e.get('agent') == agent_id and e.get('session') == session_id)
    except (FileNotFoundError, json.JSONDecodeError):
        return 0

    # Read canon config -- FIX for $AGENT_REGISTRY_PATH bug
    registry_path = os.path.join(project_dir, 'registry', 'agent-registry.json')
    registry = read_registry(registry_path)
    canon = get_canon_config(registry)

    meal_limit_root = canon.get('mealLimitRoot', 120)
    meal_warn_root = canon.get('mealWarnRoot', 50)
    meal_limit_child = canon.get('mealLimitChild', 40)
    meal_warn_child = canon.get('mealWarnChild', 20)

    if agent_id == 'root':
        if agent_meals > meal_limit_root:
            print(
                f'OVER-CONSUMPTION CRITICAL: Interpreter has consumed {agent_meals} meals '
                f'this session (limit: {meal_limit_root}).\n'
                f'This session has exceeded even the Interpreter\'s expanded budget.\n'
                f'Run /consolidation to consolidate, then start a new session.',
                file=sys.stderr,
            )
            return 2
        elif agent_meals > meal_warn_root:
            log_error(err_log, f'OVER-CONSUMPTION WARNING: Interpreter has consumed {agent_meals} meals this session.')
            log_error(err_log, 'Consider running /consolidation soon. Long sessions lose coherence.')
    else:
        if agent_meals > meal_limit_child:
            print(
                f'OVER-CONSUMPTION CRITICAL: Agent \'{agent_id}\' has consumed {agent_meals} meals '
                f'this session (limit: {meal_limit_child}).\n'
                f'This agent MUST be shutdown immediately. Its mandate is too broad.\n'
                f'Run /binding to gracefully abort, or /consolidation to consolidate.',
                file=sys.stderr,
            )
            return 2
        elif agent_meals > meal_warn_child:
            log_error(err_log, f'OVER-CONSUMPTION WARNING: Agent \'{agent_id}\' has consumed {agent_meals} meals this session.')
            log_error(err_log, 'Consider whether this agent\'s mandate is too broad. \'Measure your token before your second meal.\'')

    # Termination conditions (Section VI-C)
    if agent_id != 'root':
        tc_result = _evaluate_termination_conditions(registry, agent_id, agent_meals, err_log)
        if tc_result:
            return tc_result

    return 0


def _evaluate_termination_conditions(registry, agent_id, agent_meals, err_log):
    """Evaluate declarative termination conditions. Returns exit code or 0."""
    agents = registry.get('agents', [])
    agent_entry = next((a for a in agents if a.get('id') == agent_id), None)
    if not agent_entry:
        return 0

    tc = agent_entry.get('terminationConditions')
    if not tc:
        tier = agent_entry.get('tokensExpected', 'medium')
        defaults = {'low': 15, 'medium': 30, 'high': 60}
        tc = {'type': 'mealLimit', 'value': defaults.get(tier, 30), 'action': 'block'}

    born_at = agent_entry.get('bornAt', '')
    triggered, action, reason = _evaluate_condition(tc, agent_meals, born_at)

    if triggered:
        timestamp = get_timestamp()
        if action.upper() == 'BLOCK':
            print(
                f'TERMINATION CONDITION TRIGGERED [BLOCK]: {reason} for agent \'{agent_id}\'.\n'
                f'Agent must write its exit report now. Subsequent tool calls will be blocked.',
                file=sys.stderr,
            )
            log_error(err_log, f'TERMINATION BLOCK: {agent_id} -- {reason} [{timestamp}]')
            return 2
        else:
            log_error(err_log, f'TERMINATION CONDITION [WARN]: {reason} for agent \'{agent_id}\'.')

    return 0


def _evaluate_condition(cond, meals, born_at):
    """Evaluate a single termination condition recursively.

    Returns (triggered, action, reason).
    """
    action = cond.get('action', 'block')

    # Handle combinators
    if 'any' in cond:
        for sub in cond['any']:
            triggered, sub_action, reason = _evaluate_condition(sub, meals, born_at)
            if triggered:
                return True, sub_action, reason
        return False, action, ''

    if 'all' in cond:
        reasons = []
        for sub in cond['all']:
            triggered, sub_action, reason = _evaluate_condition(sub, meals, born_at)
            if not triggered:
                return False, action, ''
            reasons.append(reason)
        return True, action, ' AND '.join(reasons)

    ctype = cond.get('type')
    value = cond.get('value')

    if ctype == 'mealLimit':
        if meals >= int(value):
            return True, action, f'mealLimit {meals}/{value}'
    elif ctype == 'wallClock':
        if born_at:
            try:
                born = datetime.fromisoformat(born_at.replace('Z', '+00:00'))
                elapsed = (datetime.now(timezone.utc) - born).total_seconds()
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
            except (ValueError, TypeError, IndexError):
                pass

    return False, action, ''


def run():
    """Main entry point for the token log hook."""
    project_dir = get_project_dir()
    err_log = get_err_log_path(project_dir)
    timestamp = get_timestamp()

    input_data = json.load(sys.stdin)
    agent_id, session_id, tool_name, input_size = _resolve_agent_id(input_data, project_dir)

    log_file = os.path.join(project_dir, 'registry', 'token-log.json')
    os.makedirs(os.path.dirname(log_file), exist_ok=True)

    _log_meal(log_file, agent_id, session_id, tool_name, input_size, timestamp, err_log)

    cumulative_file = os.path.join(project_dir, 'registry', 'token-cumulative.json')
    _log_cumulative(cumulative_file, agent_id, session_id, timestamp, err_log)

    exit_code = _check_meal_limits(log_file, agent_id, session_id, project_dir, err_log)
    sys.exit(exit_code)


if __name__ == '__main__':
    run()
