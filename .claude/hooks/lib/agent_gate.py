"""Agent gate orchestrator -- PreToolUse hook for Agent tool.

Runs all spawn checks, auto-registers the agent, and generates
the genesis briefing. Prints result codes to stdout for the bash
shim to route on.
"""

import json
import os
import re
import sys

from .hooks_common import get_project_dir, get_err_log_path, get_timestamp, log_error
from .registry_ops import (
    read_registry, get_active_agents, get_canon_config,
    find_or_create_epoch, children_by_parent,
)
from .spawn_checks import run_all_checks
from .domain_ops import resolve_domain_id, build_intent_string, parse_embassies, read_tribes
from .trust_ops import get_trust_level, apply_trust_cap
from .memory_retrieval import search_memory, extract_search_words, select_mode
from .genesis_briefing import generate_briefing


def _run_gate_checks(input_data, registry, project_dir, domains_data):
    """Run spawn gate checks and memory retrieval.

    Returns result string matching the existing format.
    """
    result, is_block = run_all_checks(input_data, registry, project_dir, domains_data)
    if is_block or not result.startswith('PASS:CLEAR'):
        return result

    # Memory retrieval phase
    tool_input = input_data.get('tool_input', {})
    prompt = tool_input.get('prompt', '') if isinstance(tool_input, dict) else ''
    description = tool_input.get('description', '') if isinstance(tool_input, dict) else ''

    mode = select_mode(prompt)
    search_words = extract_search_words(prompt + ' ' + description)
    scored = search_memory(project_dir, search_words, mode=mode)

    if scored:
        categorized = [f'{f[2]}[{f[1]}]' for f in scored]
        findings_str = ','.join(categorized)
        return f'INFO:MEMORY_RETRIEVAL:{mode}:{findings_str}'

    # Telos surfacing
    telos = registry.get('revelation', {}).get('telos', '')
    if telos:
        return f'INFO:TELOS:{telos[:120]}'

    return 'PASS:CLEAR'


def _auto_register(input_data, result_code, project_dir, err_log):
    """Auto-register the spawning agent in agent-registry.json.

    Handles dual-registration guard, epoch routing, domain assignment,
    embassy parsing, trust-gated tokensExpected cap, genesis briefing
    generation, and thread-map write.
    """
    if result_code.startswith('BLOCK:'):
        return

    tool_input = input_data.get('tool_input', {})
    if not isinstance(tool_input, dict):
        return

    prompt = tool_input.get('prompt', '')
    description = tool_input.get('description', '')
    subagent_type = tool_input.get('subagent_type', 'general-purpose')

    registry_path = os.path.join(project_dir, 'registry', 'agent-registry.json')
    now = get_timestamp()

    try:
        with open(registry_path, encoding='utf-8') as f:
            registry = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return

    agents = registry.get('agents', [])

    # Dual-registration guard
    mandate_text = (description or prompt[:80] or 'unspecified').strip()
    active_agents = [a for a in agents if a.get('status') == 'active']

    from datetime import datetime, timezone
    for existing in active_agents:
        existing_mandate = existing.get('mandate', '')
        if (existing_mandate and mandate_text and (
            existing_mandate.lower() == mandate_text.lower()
            or existing_mandate.lower() in mandate_text.lower()
            or mandate_text.lower() in existing_mandate.lower()
        )):
            existing_born = existing.get('bornAt', '')
            skip = False
            if existing_born:
                try:
                    born_dt = datetime.fromisoformat(existing_born.replace('Z', '+00:00'))
                    now_dt = datetime.fromisoformat(now.replace('Z', '+00:00'))
                    if abs((now_dt - born_dt).total_seconds()) < 120:
                        skip = True
                except (ValueError, TypeError):
                    skip = True
            else:
                skip = True
            if skip:
                log_error(err_log, f'SPAWN GATE: Skipping auto-registration -- agent already registered as {existing["id"]} (mandate match: "{existing_mandate[:60]}")')
                return

    # Generate agent ID
    agent_id = f'{subagent_type}-{now.replace(":", "").replace("-", "")[:15]}'

    # Determine parent
    parent_id = 'root'
    parent_gen = 0
    parent_match = re.search(r'PARENT_ID:\s*(\S+)', prompt)
    if parent_match:
        candidate = parent_match.group(1)
        parent_agent = [a for a in agents if a.get('id') == candidate]
        if parent_agent:
            parent_id = candidate
            parent_gen = parent_agent[0].get('generation', 0)

    if parent_id == 'root':
        root = [a for a in agents if a.get('id') == 'root']
        if root:
            parent_gen = root[0].get('generation', 0)

        # Epoch container routing
        today = now[:10]
        epoch_parent_id, epoch_parent_gen = find_or_create_epoch(
            registry_path, today, now, err_log
        )
        if epoch_parent_id != 'root':
            parent_id = epoch_parent_id
            parent_gen = epoch_parent_gen

        # Re-read registry after epoch creation
        if parent_id != 'root':
            try:
                with open(registry_path, encoding='utf-8') as f:
                    registry = json.load(f)
                agents = registry.get('agents', [])
            except (FileNotFoundError, json.JSONDecodeError):
                pass

    # Domain assignment
    tribes_path = os.path.join(project_dir, 'registry', 'tribes.json')
    domains_data = read_tribes(tribes_path)
    domain_id = resolve_domain_id(prompt, description, domains_data)

    # Intent construction
    intent = build_intent_string(mandate_text, domain_id, domains_data)

    # Embassy parsing
    embassies = parse_embassies(prompt, domains_data)

    # Build new agent entry
    new_agent = {
        'id': agent_id,
        'parentId': parent_id,
        'mandate': mandate_text,
        'generation': parent_gen + 1,
        'origin': 'mandate',
        'bornAt': now,
        'status': 'active',
        'skills': [],
        'tokensExpected': 'medium',
        'spawnedVia': 'agent-gate-auto',
        'domainId': domain_id,
        'embassies': embassies,
        'intent': intent,
    }

    # Trust-gated tokensExpected cap
    trust_override = 'INTERPRETER_TRUST_OVERRIDE' in prompt
    trust_path = os.path.join(project_dir, 'registry', 'trust-registry.json')
    agent_type_for_trust = agent_id.split('-')[0] if '-' in agent_id else agent_id
    trust_level = get_trust_level(trust_path, agent_type_for_trust)

    if trust_override:
        log_error(err_log, f'TRUST OVERRIDE: Interpreter override for {agent_id} (trust level: {trust_level}). tokensExpected cap skipped.')
    else:
        new_agent['tokensExpected'] = apply_trust_cap(new_agent['tokensExpected'], trust_level)

    # Schema validation (advisory)
    schema_path = os.path.join(project_dir, 'registry', 'schemas', 'agent-entry.schema.json')
    if os.path.exists(schema_path):
        try:
            import jsonschema
            with open(schema_path, encoding='utf-8') as sf:
                schema = json.load(sf)
            jsonschema.validate(new_agent, schema)
        except Exception as ve:
            print(f'SCHEMA WARNING: Agent entry validation failed: {ve}', file=sys.stderr)

    # Write to registry
    agents.append(new_agent)
    registry['agents'] = agents

    import tempfile
    import shutil
    tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(registry_path), suffix='.tmp')
    try:
        with os.fdopen(tmp_fd, 'w', encoding='utf-8') as f:
            json.dump(registry, f, indent=2, ensure_ascii=False)
        if os.name == 'nt':
            shutil.move(tmp_path, registry_path)
        else:
            os.replace(tmp_path, registry_path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise

    # Generate genesis briefing
    briefing = generate_briefing(
        project_dir, agent_id, prompt, description, registry,
        domain_id=domain_id, timestamp=now,
    )
    briefing_path = os.path.join(project_dir, 'registry', 'genesis-briefing.json')
    with open(briefing_path, 'w', encoding='utf-8') as f:
        json.dump(briefing, f, indent=2)

    # Write thread-map
    thread_map_path = os.path.join(project_dir, 'registry', 'thread-map.json')
    thread_map = {}
    if os.path.exists(thread_map_path):
        try:
            with open(thread_map_path, encoding='utf-8') as f:
                thread_map = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            pass
    thread_map[agent_id] = {'bornAt': now, 'status': 'active', 'threadId': None}
    with open(thread_map_path, 'w', encoding='utf-8') as f:
        json.dump(thread_map, f, indent=2)

    print(f'Registered: {agent_id} (gen {parent_gen + 1}, parent: {parent_id})', file=sys.stderr)


def _check_checkpoint_advisory(project_dir, err_log):
    """Check if rapid spawning warrants a checkpoint advisory."""
    from datetime import datetime, timezone, timedelta
    registry_path = os.path.join(project_dir, 'registry', 'agent-registry.json')
    try:
        with open(registry_path, encoding='utf-8') as f:
            registry = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return

    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(seconds=60)
    recent = 0
    for a in registry.get('agents', []):
        born = a.get('bornAt', '')
        if not born:
            continue
        try:
            born_dt = datetime.fromisoformat(born.replace('Z', '+00:00'))
            if born_dt >= cutoff:
                recent += 1
        except (ValueError, TypeError):
            pass

    if recent >= 3:
        log_error(err_log, f'CHECKPOINT ADVISORY: {recent} agents spawning in rapid succession.')
        log_error(err_log, 'Constitution XIII recommends /checkpoint before large multi-agent transitions.')


def _check_preflight_advisory(input_data, err_log):
    """Check if this is a high-stakes mandate needing pre-flight review."""
    tool_input = input_data.get('tool_input', {})
    if not isinstance(tool_input, dict):
        return

    prompt = tool_input.get('prompt', '').lower()
    description = tool_input.get('description', '').lower()
    search_text = prompt + ' ' + description

    high_stakes_kws = [
        'high-stakes', 'tokenexpected: high', 'tokenexpected:high',
        'production', 'deploy', 'critical', 'destructive', 'migration',
        'token_expected: high', 'high stakes',
    ]
    for kw in high_stakes_kws:
        if kw in search_text:
            log_error(err_log, 'PRE-FLIGHT ADVISORY: This appears to be a high-stakes mandate.')
            log_error(err_log, 'Constitution XVII recommends running /preflight before high-token mandates.')
            return


def run():
    """Main entry point for the agent gate hook.

    Prints result code to stdout:
      BLOCK:... -> bash shim exits 2
      GENESIS_BRIEFING -> bash shim prints briefing to stderr
      PASS:... -> bash shim exits 0
    """
    project_dir = get_project_dir()
    err_log = get_err_log_path(project_dir)

    input_data = json.load(sys.stdin)

    # Check if this is an Agent tool call
    tool_name = input_data.get('tool_name', '')
    if tool_name != 'Agent':
        print('PASS:NOT_AGENT')
        return

    registry_path = os.path.join(project_dir, 'registry', 'agent-registry.json')
    if not os.path.exists(registry_path):
        log_error(err_log, 'SPAWN GATE: No agent-registry.json found. Agent will spawn unregistered.')
        print('PASS:NO_REGISTRY')
        return

    registry = read_registry(registry_path)
    tribes_path = os.path.join(project_dir, 'registry', 'tribes.json')
    domains_data = read_tribes(tribes_path)

    # Run gate checks
    result = _run_gate_checks(input_data, registry, project_dir, domains_data)
    print(result)

    # Auto-register
    _auto_register(input_data, result, project_dir, err_log)

    # Post-registration advisories (only if not blocked)
    if not result.startswith('BLOCK:'):
        _check_checkpoint_advisory(project_dir, err_log)
        _check_preflight_advisory(input_data, err_log)


if __name__ == '__main__':
    run()
