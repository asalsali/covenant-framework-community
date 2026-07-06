"""Agent registry CRUD operations.

Provides reading, querying, archiving, registering agents, and
epoch container creation in agent-registry.json.
"""

import json
import os
import shutil
import sys
import tempfile

from .hooks_common import log_error


def read_registry(registry_path):
    """Read agent-registry.json, return parsed dict or empty fallback."""
    try:
        with open(registry_path, encoding='utf-8') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def get_active_agents(registry):
    """Filter registry agents to status=='active'."""
    return [a for a in registry.get('agents', []) if a.get('status') == 'active']


def get_canon_config(registry):
    """Extract canon config with defaults."""
    canon = registry.get('canon', {})
    return {
        'maxGenerations': canon.get('maxGenerations', 4),
        'maxSiblings': canon.get('maxSiblings', 8),
        'babelThreshold': canon.get('babelThreshold', 6),
        'sabbathInterval': canon.get('sabbathInterval', 10),
        'mealLimitRoot': canon.get('mealLimitRoot', 120),
        'mealWarnRoot': canon.get('mealWarnRoot', 50),
        'mealLimitChild': canon.get('mealLimitChild', 40),
        'mealWarnChild': canon.get('mealWarnChild', 20),
        'tribalComplexityThreshold': canon.get('tribalComplexityThreshold', None),
    }


def children_by_parent(active_agents):
    """Build parent -> active children map."""
    result = {}
    for a in active_agents:
        pid = a.get('parentId')
        if pid:
            result.setdefault(pid, []).append(a)
    return result


def archive_agent(registry_path, agent_id, timestamp, err_log=None):
    """Archive agent in registry using safe_json. Returns success.

    Falls back to inline write if safe_json import fails.
    """
    try:
        from .safe_json import read_modify_write

        def _archive(registry):
            for agent in registry.get('agents', []):
                if agent.get('id') == agent_id:
                    agent['status'] = 'archived'
                    agent['shutdownAt'] = timestamp
            return registry

        return read_modify_write(registry_path, _archive, err_log)
    except ImportError:
        # Fallback: inline write without locking
        try:
            with open(registry_path, 'r', encoding='utf-8') as f:
                registry = json.load(f)
            for agent in registry.get('agents', []):
                if agent.get('id') == agent_id:
                    agent['status'] = 'archived'
                    agent['shutdownAt'] = timestamp
            _atomic_write(registry_path, registry)
            return True
        except Exception as e:
            if err_log:
                log_error(err_log, f'ARCHIVE FAILED (fallback): {e}')
            return False


def register_agent(
    registry_path,
    agent_id,
    parent_id,
    parent_gen,
    mandate,
    *,
    domain_id=None,
    embassies=None,
    tokens_expected='medium',
    spawned_via='agent-gate-auto',
    intent='',
    err_log=None,
    timestamp=None,
):
    """Register a new agent entry. Returns success."""
    from .hooks_common import get_timestamp
    if timestamp is None:
        timestamp = get_timestamp()

    new_agent = {
        'id': agent_id,
        'parentId': parent_id,
        'mandate': mandate,
        'generation': parent_gen + 1,
        'origin': 'mandate',
        'bornAt': timestamp,
        'status': 'active',
        'skills': [],
        'tokensExpected': tokens_expected,
        'spawnedVia': spawned_via,
        'domainId': domain_id,
        'embassies': embassies or [],
        'intent': intent,
    }

    try:
        with open(registry_path, encoding='utf-8') as f:
            registry = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        if err_log:
            log_error(err_log, f'REGISTER: Could not read registry at {registry_path}')
        return False

    registry.setdefault('agents', []).append(new_agent)
    try:
        _atomic_write(registry_path, registry)
        return True
    except Exception as e:
        if err_log:
            log_error(err_log, f'REGISTER FAILED: {e}')
        return False


def find_or_create_epoch(registry_path, today, timestamp, err_log=None):
    """Find or create a session epoch container.

    Returns (parent_id, parent_gen). Falls back to ('root', 0) on failure.
    """
    try:
        with open(registry_path, encoding='utf-8') as f:
            registry = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return 'root', 0

    agents = registry.get('agents', [])
    active_agents = [a for a in agents if a.get('status') == 'active']

    # Look for existing epoch container from today
    active_epochs = [
        a for a in active_agents
        if a.get('parentId') == 'root'
        and a.get('id', '').startswith('epoch-')
        and a.get('bornAt', '')[:10] == today
    ]
    if active_epochs:
        active_epochs.sort(key=lambda a: a.get('bornAt', ''), reverse=True)
        epoch = active_epochs[0]
        return epoch['id'], epoch.get('generation', 1)

    # Create a new epoch container
    epoch_id = f'epoch-auto-{today}'
    epoch_entry = {
        'id': epoch_id,
        'parentId': 'root',
        'mandate': f'Epoch parent \u2014 auto-created session container {today}',
        'generation': 1,
        'origin': 'mandate',
        'bornAt': timestamp,
        'status': 'active',
        'skills': [],
        'tokensExpected': 'low',
        'spawnedVia': 'agent-gate-auto-epoch',
    }

    try:
        # Use fcntl if available (Unix), skip on Windows
        try:
            import fcntl
        except ImportError:
            fcntl = None

        with open(registry_path, 'r+', encoding='utf-8') as rf:
            if fcntl:
                try:
                    fcntl.flock(rf, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except (IOError, OSError):
                    pass
            reg_data = json.load(rf)
            reg_agents = reg_data.get('agents', [])
            # Double-check: another parallel spawn may have created the epoch
            existing = [a for a in reg_agents if a.get('id') == epoch_id and a.get('status') == 'active']
            if existing:
                parent_id = epoch_id
                parent_gen = existing[0].get('generation', 1)
            else:
                reg_agents.append(epoch_entry)
                reg_data['agents'] = reg_agents
                rf.seek(0)
                rf.truncate()
                json.dump(reg_data, rf, indent=2, ensure_ascii=False)
                parent_id = epoch_id
                parent_gen = 1
            if fcntl:
                try:
                    fcntl.flock(rf, fcntl.LOCK_UN)
                except (IOError, OSError):
                    pass
        return parent_id, parent_gen
    except Exception as e:
        if err_log:
            log_error(err_log, f'EPOCH AUTO-CREATE FAILED: {e}. Falling back to root.')
        return 'root', 0


def _atomic_write(path, data):
    """Atomic JSON write via temp file + rename. Windows-safe."""
    dir_name = os.path.dirname(os.path.abspath(path))
    tmp_fd, tmp_path = tempfile.mkstemp(dir=dir_name, suffix='.tmp')
    try:
        with os.fdopen(tmp_fd, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        if os.name == 'nt':
            shutil.move(tmp_path, path)
        else:
            os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise
