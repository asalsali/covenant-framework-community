"""Pre-spawn validation checks for the agent gate.

Each check returns a result tuple: (action, code, message)
  action: 'PASS', 'BLOCK', 'WARN', 'INFO'
  code: machine-readable code (e.g., 'GENERATION', 'SIBLING')
  message: human-readable detail
"""

import json
import os
import re
from datetime import datetime, timezone, timedelta


def check_consolidation_active(registry):
    """Check if consolidation is currently active."""
    if registry.get('consolidationActive', False):
        return 'BLOCK', 'CONSOLIDATION', 'Consolidation is active'
    return 'PASS', '', ''


def check_reinit_required(project_dir):
    """Check if re-initialization is required."""
    reinit_flag = os.path.join(project_dir, 'registry', 'reinit-required.flag')
    if os.path.exists(reinit_flag):
        return 'BLOCK', 'REINIT_REQUIRED', 'Re-initialization required'
    return 'PASS', '', ''


def check_binding_active(project_dir):
    """Check if graceful abort is in progress."""
    binding_flag = os.path.join(project_dir, 'registry', 'binding-active.flag')
    if os.path.exists(binding_flag):
        return 'BLOCK', 'BINDING_ACTIVE', 'Graceful abort is active'
    return 'PASS', '', ''


def check_generation_cap(active_agents, max_gen):
    """Check generation cap. Returns (action, code, message)."""
    max_active_gen = 0
    for a in active_agents:
        gen = a.get('generation', 0)
        if gen > max_active_gen:
            max_active_gen = gen
    if max_active_gen >= max_gen:
        return 'BLOCK', f'GENERATION:{max_active_gen}:{max_gen}', \
            f'Active agents at generation {max_active_gen} (limit: {max_gen})'
    return 'PASS', '', ''


def check_sibling_limit(children_map, parent_id, max_siblings):
    """Check sibling limit for a specific parent."""
    children = children_map.get(parent_id, [])
    if len(children) >= max_siblings:
        return 'BLOCK', f'SIBLING:{parent_id}:{len(children)}:{max_siblings}', \
            f'Parent {parent_id} has {len(children)} children (limit: {max_siblings})'
    return 'PASS', '', ''


def check_complexity_threshold(active_agents, threshold):
    """Check global complexity threshold (Babel)."""
    if len(active_agents) >= threshold:
        return 'BLOCK', f'COMPLEXITY:{len(active_agents)}:{threshold}', \
            f'{len(active_agents)} active agents (threshold: {threshold})'
    return 'PASS', '', ''


def check_synthesis_valid(prompt, agents, project_dir):
    """Validate synthesis (dual-parent spawn).

    Returns (result_code, message).
    result_code: 'PASS' (not a synthesis), 'BLOCK' (invalid), 'WARN' (validated)
    """
    if not re.search(r'SYNTHESIZE:|parentIds:', prompt):
        return 'PASS', ''

    # Extract parent IDs
    synth_parents = []
    pid_match = re.search(r'parentIds?:\s*\[?\s*([^\]\n]+)\]?', prompt)
    if pid_match:
        raw = pid_match.group(1)
        synth_parents = [
            p.strip().strip('"').strip("'").strip(',')
            for p in raw.split(',')
            if p.strip().strip('"').strip("'").strip(',')
        ]

    if len(synth_parents) < 2:
        return 'BLOCK', 'Two parent agent IDs required for synthesis'

    # Both parents must exist and be archived
    for sp in synth_parents[:2]:
        sp_agent = [a for a in agents if a.get('id') == sp]
        if not sp_agent:
            return 'BLOCK', f'Parent agent {sp} not found in registry'
        if sp_agent[0].get('status') != 'archived':
            return 'BLOCK', f'Parent agent {sp} must be archived (status: {sp_agent[0].get("status", "unknown")})'

    # Both parents must have exit reports
    handoff_base = os.path.join(project_dir, 'memory', 'handoff')
    for sp in synth_parents[:2]:
        exit_patterns = [
            os.path.join(handoff_base, f'{sp}-exit_report.json'),
            os.path.join(handoff_base, f'{sp}-exit_report.md'),
            os.path.join(handoff_base, f'{sp}.md'),
        ]
        if not any(os.path.exists(p) for p in exit_patterns):
            return 'BLOCK', f'No exit report found for parent {sp}'

    return 'WARN', 'Synthesis validated'


def check_charter_advisory(project_dir, agents):
    """Check if charter is needed. Returns warning message or None."""
    covenants_dir = os.path.join(project_dir, 'memory', 'covenants')
    has_covenant = False
    if os.path.isdir(covenants_dir):
        has_covenant = any(
            f.endswith('.md') or f.endswith('.json')
            for f in os.listdir(covenants_dir)
            if os.path.isfile(os.path.join(covenants_dir, f))
        )

    if has_covenant:
        return None

    now_utc = datetime.now(timezone.utc)
    cutoff = now_utc - timedelta(minutes=10)
    recent_spawns = 0
    for a in agents:
        born = a.get('bornAt', '')
        if born:
            try:
                born_dt = datetime.fromisoformat(born.replace('Z', '+00:00'))
                if born_dt >= cutoff:
                    recent_spawns += 1
            except (ValueError, TypeError):
                pass

    if recent_spawns > 3:
        return f'{recent_spawns} agents spawned without an active covenant'
    return None


def check_overlap(prompt, description, active_agents, domain_id):
    """Check for mandate overlap with active agents.

    Returns (level, overlap_info) where level is 'PASS', 'WARN', or 'INFO'.
    overlap_info is a dict with 'agent_id', 'domain_id', 'mandate' on match.
    """
    if not prompt and not description:
        return 'PASS', None

    search_text = (prompt + ' ' + description).lower()
    common = {
        'the', 'a', 'an', 'to', 'for', 'and', 'of', 'in', 'on', 'with', 'is', 'it',
        'this', 'that', 'be', 'do', 'use', 'run', 'make', 'get', 'set', 'check',
        'read', 'write', 'file', 'code', 'should', 'would', 'could', 'need', 'want',
        'please', 'agent', 'task',
    }
    search_words = set(search_text.split()) - common

    for agent in active_agents:
        mandate = agent.get('mandate', '').lower()
        if not mandate:
            continue
        mandate_words = set(mandate.split()) - common
        overlap = mandate_words & search_words
        if len(overlap) >= 3:
            other_domain = agent.get('domainId')
            info = {
                'agent_id': agent['id'],
                'domain_id': other_domain,
                'mandate': agent.get('mandate', '')[:60],
            }
            if domain_id and other_domain and domain_id == other_domain:
                return 'INFO', info
            else:
                return 'WARN', info

    return 'PASS', None


def check_domain_complexity(domain_id, active_agents, domains_data, canon):
    """Check domain-level complexity threshold. Returns warning message or None."""
    if not domain_id or not domains_data:
        return None

    tribal_threshold = domains_data.get(
        'tribalComplexityThreshold',
        canon.get('tribalComplexityThreshold', 6),
    )
    domain_active = [a for a in active_agents if a.get('domainId') == domain_id]
    if len(domain_active) >= tribal_threshold:
        return f'{domain_id}:{len(domain_active)}:{tribal_threshold}'
    return None


def run_all_checks(input_data, registry, project_dir, domains_data=None):
    """Run all spawn checks in sequence. Returns (result_string, exit_early).

    result_string matches the existing format: 'BLOCK:CODE:...' or 'PASS:CLEAR'.
    exit_early: True if the spawn should be blocked.
    """
    tool_input = input_data.get('tool_input', {})
    if not isinstance(tool_input, dict):
        return 'PASS:NOT_AGENT', False

    tool_name = input_data.get('tool_name', '')
    if tool_name != 'Agent':
        return 'PASS:NOT_AGENT', False

    prompt = tool_input.get('prompt', '')
    description = tool_input.get('description', '')

    if not registry:
        return 'PASS:NO_REGISTRY', False

    canon = registry.get('canon', {})
    max_generations = canon.get('maxGenerations', 4)
    max_siblings = canon.get('maxSiblings', 8)
    babel_threshold = canon.get('babelThreshold', 6)

    agents = registry.get('agents', [])
    active = [a for a in agents if a.get('status') == 'active']
    children_map = {}
    for a in active:
        pid = a.get('parentId')
        if pid:
            children_map.setdefault(pid, []).append(a)

    # Consolidation check
    action, code, msg = check_consolidation_active(registry)
    if action == 'BLOCK':
        return f'BLOCK:{code}', True

    # Reinit check
    action, code, msg = check_reinit_required(project_dir)
    if action == 'BLOCK':
        return f'BLOCK:{code}', True

    # Binding check
    action, code, msg = check_binding_active(project_dir)
    if action == 'BLOCK':
        return f'BLOCK:{code}', True

    # Generation cap
    action, code, msg = check_generation_cap(active, max_generations)
    if action == 'BLOCK':
        return f'BLOCK:{code}', True

    # Sibling limit -- determine spawn parent
    spawn_parent = 'root'
    parent_match = re.search(r'PARENT_ID:\s*(\S+)', prompt)
    if parent_match:
        candidate = parent_match.group(1)
        if any(a.get('id') == candidate for a in agents):
            spawn_parent = candidate
    action, code, msg = check_sibling_limit(children_map, spawn_parent, max_siblings)
    if action == 'BLOCK':
        return f'BLOCK:{code}', True

    # Synthesis validation
    synth_result, synth_msg = check_synthesis_valid(prompt, agents, project_dir)
    if synth_result == 'BLOCK':
        return f'BLOCK:SYNTHESIS_INVALID:{synth_msg}', True
    if synth_result == 'WARN':
        return 'WARN:SYNTHESIS:validated', False

    # Charter advisory
    charter_msg = check_charter_advisory(project_dir, agents)
    if charter_msg:
        count = charter_msg.split()[0] if charter_msg[0].isdigit() else '?'
        return f'WARN:NO_CHARTER:{count}', False

    # Complexity threshold
    action, code, msg = check_complexity_threshold(active, babel_threshold)
    if action == 'BLOCK':
        return f'BLOCK:{code}', True

    # Domain resolution for overlap/complexity checks
    domain_id = None
    domain_match = re.search(r'TRIBE_ID:\s*(\S+)', prompt)
    if domain_match:
        domain_id = domain_match.group(1)

    search_text = (prompt + ' ' + description).lower()
    if not domain_id and domains_data:
        import fnmatch
        for domain in domains_data.get('tribes', []):
            for pat in domain.get('territory', {}).get('filePaths', []):
                if any(
                    fnmatch.fnmatch(w, pat) or fnmatch.fnmatch(w.replace('\\', '/'), pat)
                    for w in search_text.split()
                ):
                    domain_id = domain['id']
                    break
            if domain_id:
                break

    # Domain complexity
    if domain_id and domains_data:
        domain_msg = check_domain_complexity(domain_id, active, domains_data, canon)
        if domain_msg:
            return f'WARN:TRIBAL_BABEL:{domain_msg}', False

    # Overlap detection
    level, info = check_overlap(prompt, description, active, domain_id)
    if level == 'WARN' and info:
        return f'WARN:OVERLAP:{info["agent_id"]}:{info["mandate"]}', False
    if level == 'INFO' and info:
        return f'INFO:TRIBAL_OVERLAP:{info["agent_id"]}:{info["domain_id"]}:{info["mandate"]}', False

    return 'PASS:CLEAR', False
