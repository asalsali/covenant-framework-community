"""Session start checks.

Fires once when a Claude Code session begins. Checks for stale state:
spirit staleness, user model dormancy, permission mode, charter advisory,
hook-errors.log rotation, pending spawn requests, dream cycle staleness.

Always exits 0 -- all checks are advisory.
"""

import json
import os
import sys
from datetime import datetime, timezone, timedelta

from .hooks_common import get_project_dir


def run():
    """Run all session start checks. Prints warnings to stderr."""
    project_dir = get_project_dir()
    now = datetime.now(timezone.utc)
    warnings = []

    # --- Spirit staleness check ---
    spirit_path = os.path.join(project_dir, 'registry', 'orientation.json')
    if os.path.exists(spirit_path):
        try:
            with open(spirit_path, encoding='utf-8') as f:
                spirit = json.load(f)
            last_updated = spirit.get('lastUpdatedAt', '')
            if last_updated:
                try:
                    updated_dt = datetime.fromisoformat(last_updated.replace('Z', '+00:00'))
                    age = now - updated_dt
                    if age > timedelta(days=7):
                        warnings.append(
                            f'STALE SPIRIT: orientation.json last updated {age.days} days ago. '
                            f'The orientation may no longer apply. Run /consolidation or update spirit manually.'
                        )
                except (ValueError, TypeError):
                    pass
        except (FileNotFoundError, json.JSONDecodeError):
            pass
    else:
        warnings.append('NO SPIRIT: registry/orientation.json not found. Run /genesis to initialize the framework.')

    # --- Dormancy check ---
    user_model_path = os.path.join(project_dir, 'memory', 'user-model.json')
    if os.path.exists(user_model_path):
        try:
            with open(user_model_path, encoding='utf-8') as f:
                um = json.load(f)
            last_updated = um.get('lastUpdated', '')
            if last_updated:
                try:
                    updated_dt = datetime.fromisoformat(last_updated.replace('Z', '+00:00'))
                    age = now - updated_dt
                    if age > timedelta(hours=24):
                        warnings.append(
                            f'DORMANCY DETECTED: User model last updated {age.days}d {age.seconds // 3600}h ago. '
                            f'Consider running /reinit to re-orient before accepting requests.'
                        )
                        reinit_flag = os.path.join(project_dir, 'registry', 'reinit-required.flag')
                        try:
                            with open(reinit_flag, 'w') as rf:
                                rf.write('')
                        except OSError:
                            pass
                except (ValueError, TypeError):
                    pass
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    # --- Permission mode check ---
    perm_mode = os.environ.get('CLAUDE_CODE_PERMISSION_MODE', '')
    settings_path = os.path.join(project_dir, '.claude', 'settings.local.json')
    has_local_perms = os.path.exists(settings_path)

    global_settings = os.path.expanduser('~/.claude/settings.json')
    global_grants_write = False
    if os.path.exists(global_settings):
        try:
            with open(global_settings, encoding='utf-8') as f:
                gs = json.load(f)
            allow = gs.get('permissions', {}).get('allow', [])
            if any(t in allow for t in ['Write', 'Edit', 'Bash']):
                global_grants_write = True
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    if not global_grants_write and not has_local_perms and perm_mode != 'dangerously_skip_permissions':
        warnings.append(
            'PERMISSION MODE: Subagents will be READ-ONLY in default permission mode. '
            'Multi-agent spawning will fall back to delegation pattern (subagent plans, '
            'Interpreter executes). For full multi-agent execution, run with '
            '--dangerously-skip-permissions or grant Write/Edit permissions to subagents.'
        )

    # --- Charter check ---
    covenants_dir = os.path.join(project_dir, 'memory', 'covenants')
    registry_path = os.path.join(project_dir, 'registry', 'agent-registry.json')
    covenant_count = 0
    if os.path.isdir(covenants_dir):
        covenant_count = len([
            f for f in os.listdir(covenants_dir)
            if os.path.isfile(os.path.join(covenants_dir, f))
        ])
    if covenant_count == 0:
        total_agents = 0
        try:
            with open(registry_path, encoding='utf-8') as f:
                reg = json.load(f)
            total_agents = len(reg.get('agents', []))
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        if total_agents > 5:
            warnings.append(
                f'NO CHARTER: 0 active covenants with {total_agents} agents in registry.\n'
                f'   Constitution XVIII: Consider /charter to define success criteria for this project.'
            )

    # --- hook-errors.log rotation ---
    hook_err_log = os.path.join(project_dir, 'registry', 'hook-errors.log')
    try:
        if os.path.exists(hook_err_log):
            with open(hook_err_log, 'r', encoding='utf-8', errors='replace') as hf:
                lines = hf.readlines()
            if len(lines) > 500:
                with open(hook_err_log, 'w', encoding='utf-8') as hf:
                    hf.writelines(lines[-200:])
    except OSError:
        pass

    # --- Pending spawn requests ---
    memos_dir = os.path.join(project_dir, 'memory', 'memos')
    if os.path.isdir(memos_dir):
        import glob as _glob
        pending_count = 0
        for fpath in _glob.glob(os.path.join(memos_dir, 'spawn-request-*.md')):
            try:
                with open(fpath, 'r', encoding='utf-8', errors='replace') as fh:
                    content = fh.read(500)
                if '"approvalStatus": "pending"' in content or "'approvalStatus': 'pending'" in content:
                    pending_count += 1
            except (OSError, UnicodeDecodeError):
                pass
        if pending_count > 0:
            warnings.append(
                f'LATERAL SPAWN REQUESTS: {pending_count} pending request(s) await '
                f'Interpreter review (Constitution Section XXXV)'
            )

    # --- Dream cycle staleness ---
    dream_log_path = os.path.join(project_dir, 'registry', 'dream-log.json')
    if os.path.exists(dream_log_path):
        try:
            with open(dream_log_path, encoding='utf-8') as f:
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
                        warnings.append(
                            'DREAM_CYCLE: System idle >12h since last dream cycle. '
                            'Consider running a dream cycle (Section V-B).'
                        )
                except (ValueError, TypeError):
                    pass
            else:
                warnings.append(
                    'DREAM_CYCLE: System idle >12h since last dream cycle. '
                    'Consider running a dream cycle (Section V-B).'
                )
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    # Output warnings
    for w in warnings:
        print(f'\u26a0\ufe0f  {w}', file=sys.stderr)


if __name__ == '__main__':
    run()
