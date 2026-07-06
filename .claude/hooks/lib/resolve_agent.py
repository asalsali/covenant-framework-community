"""4-tier agent ID resolution -- canonical implementation.

Resolves raw Claude Code thread IDs to canonical agent IDs from
the agent registry. Replaces 3 divergent copies across hooks.

Tiers:
  1. Direct registry match
  2. Thread-map lookup (threadId -> canonical ID)
  3. Thread-map key match (raw_id is itself a canonical key)
  4. Single-active / oldest-active fallback
"""

import json
import os
import sys
from datetime import datetime, timezone

from .hooks_common import log_error


def resolve_canonical_id(
    raw_agent_id,
    registry_path,
    thread_map_path,
    *,
    assign_thread=False,
    archive_on_resolve=False,
):
    """Resolve a raw thread ID to a canonical agent ID.

    Returns: (canonical_id, resolution_method)
    Resolution methods: 'direct', 'thread_map', 'thread_map_key',
                        'single_active', 'oldest_active', 'unresolved'

    Args:
        raw_agent_id: The raw thread or agent ID from Claude Code.
        registry_path: Path to agent-registry.json.
        thread_map_path: Path to thread-map.json.
        assign_thread: If True, writes the thread assignment back to thread-map.
        archive_on_resolve: If True, marks the resolved entry as 'archived'
                           in thread-map.
    """
    if not raw_agent_id or raw_agent_id == 'unknown':
        return raw_agent_id, 'unresolved'

    # Read registry
    try:
        with open(registry_path, encoding='utf-8') as f:
            registry = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        return raw_agent_id, 'unresolved'

    agents = registry.get('agents', [])

    # Tier 1: Direct registry match
    for a in agents:
        if a.get('id') == raw_agent_id:
            return raw_agent_id, 'direct'

    # Read thread-map
    thread_map = {}
    try:
        with open(thread_map_path, encoding='utf-8') as f:
            thread_map = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    # Tier 2: Thread-map lookup (threadId -> canonical ID)
    for cid, entry in thread_map.items():
        if entry.get('threadId') == raw_agent_id and entry.get('status') == 'active':
            if archive_on_resolve:
                thread_map[cid]['status'] = 'archived'
                _write_thread_map(thread_map_path, thread_map)
            return cid, 'thread_map'

    # Tier 2.5: Unassigned active entries -- prefer most recently born
    now = datetime.now(timezone.utc)
    unassigned = []
    for cid, entry in thread_map.items():
        if entry.get('status') == 'active' and not entry.get('threadId'):
            try:
                born = datetime.fromisoformat(entry['bornAt'].replace('Z', '+00:00'))
                age = (now - born).total_seconds()
                unassigned.append((cid, entry, age))
            except (ValueError, TypeError, KeyError):
                pass

    if len(unassigned) == 1:
        cid = unassigned[0][0]
        if assign_thread:
            thread_map[cid]['threadId'] = raw_agent_id
            _write_thread_map(thread_map_path, thread_map)
        if archive_on_resolve:
            thread_map[cid]['status'] = 'archived'
            _write_thread_map(thread_map_path, thread_map)
        return cid, 'thread_map'
    elif unassigned:
        # Ambiguous: multiple unassigned. Prefer most recently born.
        unassigned.sort(key=lambda x: x[2])
        cid = unassigned[0][0]
        if assign_thread:
            thread_map[cid]['threadId'] = raw_agent_id
            _write_thread_map(thread_map_path, thread_map)
        if archive_on_resolve:
            thread_map[cid]['status'] = 'archived'
            _write_thread_map(thread_map_path, thread_map)
        return cid, 'thread_map'

    # Tier 3: Thread-map key match (raw_id is itself a canonical key)
    if raw_agent_id in thread_map and thread_map[raw_agent_id].get('status') == 'active':
        if archive_on_resolve:
            thread_map[raw_agent_id]['status'] = 'archived'
            _write_thread_map(thread_map_path, thread_map)
        return raw_agent_id, 'thread_map_key'

    # Tier 4: Single-active / oldest-active fallback
    active = [a for a in agents if a.get('status') == 'active' and a.get('id') != 'root']
    if len(active) == 1:
        return active[0]['id'], 'single_active'
    elif active:
        active.sort(key=lambda a: a.get('bornAt', ''))
        return active[0]['id'], 'oldest_active'

    return raw_agent_id, 'unresolved'


def _write_thread_map(path, data):
    """Write thread-map.json. Best-effort, swallows errors."""
    try:
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
    except (IOError, OSError):
        pass


if __name__ == '__main__':
    """CLI entry point: reads JSON from stdin with raw_agent_id, prints result."""
    import json
    data = json.load(sys.stdin)
    project_dir = os.environ.get('_CF_PROJECT_DIR', '.')
    registry_path = os.path.join(project_dir, 'registry', 'agent-registry.json')
    thread_map_path = os.path.join(project_dir, 'registry', 'thread-map.json')

    canonical_id, method = resolve_canonical_id(
        data.get('raw_agent_id', ''),
        registry_path,
        thread_map_path,
        assign_thread=data.get('assign_thread', False),
        archive_on_resolve=data.get('archive_on_resolve', False),
    )
    print(json.dumps({'canonical_id': canonical_id, 'method': method}))
