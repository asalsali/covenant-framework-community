"""Trust registry operations.

Handles trust level lookup, trust-gated tokensExpected capping,
and trust updates on agent shutdown.
"""

import json
import os


def get_trust_level(trust_path, agent_type):
    """Get current trust level for an agent type. Returns 'untested' if not found."""
    try:
        with open(trust_path, encoding='utf-8') as f:
            trust_doc = json.load(f)
        for entry in trust_doc.get('internalAgentTrust', {}).get('agentTypes', []):
            if entry.get('agentType') == agent_type:
                return entry.get('trustLevel', 'untested')
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    return 'untested'


def apply_trust_cap(tokens_expected, trust_level, has_override=False):
    """Apply trust-gated tokensExpected cap. Returns capped value."""
    if has_override:
        return tokens_expected

    trust_caps = {
        'untested': 'low',
        'proven': 'medium',
        'trusted': 'high',
        'veteran': 'high',
    }
    cap = trust_caps.get(trust_level, 'low')
    token_rank = {'low': 0, 'medium': 1, 'high': 2}

    if token_rank.get(tokens_expected, 1) > token_rank.get(cap, 0):
        return cap
    return tokens_expected


def update_trust_on_shutdown(trust_path, agent_type, mandate_completed, timestamp):
    """Update trust metrics and check promotion/demotion. Returns new trust level."""
    try:
        with open(trust_path, encoding='utf-8') as f:
            trust_doc = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        trust_doc = {
            'description': 'Progressive Trust Protocol',
            'externalToolTrust': {'tools': []},
            'internalAgentTrust': {'agentTypes': []},
        }

    trust_types = trust_doc.get('internalAgentTrust', {}).get('agentTypes', [])
    trust_entry = None
    for te in trust_types:
        if te.get('agentType') == agent_type:
            trust_entry = te
            break

    if trust_entry is None:
        trust_entry = {
            'agentType': agent_type,
            'trustLevel': 'untested',
            'completedMandates': 0,
            'totalMandates': 0,
            'constitutionalViolations': 0,
            'degradationFlags': 0,
            'sessions': [],
            'completionRate': 0,
            'lastUpdated': timestamp,
        }
        trust_types.append(trust_entry)

    trust_entry['totalMandates'] = trust_entry.get('totalMandates', 0) + 1
    if mandate_completed:
        trust_entry['completedMandates'] = trust_entry.get('completedMandates', 0) + 1

    session_date = timestamp[:10]
    if session_date not in trust_entry.get('sessions', []):
        trust_entry.setdefault('sessions', []).append(session_date)

    total = trust_entry.get('totalMandates', 0)
    completed = trust_entry.get('completedMandates', 0)
    trust_entry['completionRate'] = round(completed / total, 3) if total > 0 else 0
    trust_entry['lastUpdated'] = timestamp

    # Promotion checks
    cur_level = trust_entry.get('trustLevel', 'untested')
    violations = trust_entry.get('constitutionalViolations', 0)
    sessions = trust_entry.get('sessions', [])
    promotions = []

    if cur_level == 'untested' and completed >= 3 and violations == 0:
        trust_entry['trustLevel'] = 'proven'
        promotions.append(f'{agent_type} untested -> proven ({completed} completed mandates)')
    elif cur_level == 'proven' and completed >= 10 and len(sessions) >= 2 \
            and trust_entry['completionRate'] > 0.85 and violations == 0:
        trust_entry['trustLevel'] = 'trusted'
        promotions.append(f'{agent_type} proven -> trusted ({completed} completed, {len(sessions)} sessions)')

    # Demotion check
    incomplete = total - completed
    demotions = []
    if incomplete >= 2 and cur_level != 'untested':
        level_order = ['untested', 'proven', 'trusted', 'veteran']
        cur_idx = level_order.index(cur_level) if cur_level in level_order else 0
        if cur_idx > 0:
            trust_entry['trustLevel'] = level_order[cur_idx - 1]
            demotions.append(f'{agent_type} {cur_level} -> {trust_entry["trustLevel"]} ({incomplete} incomplete mandates)')

    trust_doc.setdefault('internalAgentTrust', {})['agentTypes'] = trust_types
    with open(trust_path, 'w', encoding='utf-8') as f:
        json.dump(trust_doc, f, indent=2)

    return trust_entry['trustLevel'], promotions, demotions
