"""Domain/tribe operations.

Handles tribe resolution, territory matching, embassy parsing,
territorial enforcement, and domain membership updates.
"""

import json
import os
import re


def resolve_domain_id(prompt, description, domains_data):
    """Resolve domain ID from explicit TRIBE_ID or territory auto-inference.

    Returns domain_id string or None.
    """
    # Explicit TRIBE_ID in prompt
    match = re.search(r'TRIBE_ID:\s*(\S+)', prompt)
    if match:
        domain_id = match.group(1)
        # Validate it exists
        if domains_data:
            valid_ids = [t['id'] for t in domains_data.get('tribes', [])]
            if domain_id not in valid_ids:
                return None
        return domain_id

    # Territory auto-inference
    if not domains_data:
        return None

    import fnmatch
    search_text = (prompt + ' ' + description).lower()
    for domain in domains_data.get('tribes', []):
        for pat in domain.get('territory', {}).get('filePaths', []):
            if any(
                fnmatch.fnmatch(w, pat) or fnmatch.fnmatch(w.replace('\\', '/'), pat)
                for w in search_text.split()
            ):
                return domain['id']

    return None


def build_intent_string(mandate, domain_id, domains_data):
    """Build scoped intent string for agent registration."""
    if domain_id and domains_data:
        tribe_entry = next(
            (t for t in domains_data.get('tribes', []) if t.get('id') == domain_id),
            None,
        )
        if tribe_entry:
            territory_globs = tribe_entry.get('territory', {}).get('filePaths', [])
            territory_str = ', '.join(territory_globs) if territory_globs else 'no territory defined'
            return f'{mandate}. Scope: {domain_id} tribe territory ({territory_str}). Must not modify files outside tribe territory.'
    return f'{mandate}. No tribe assignment \u2014 scope unconstrained.'


def parse_embassies(prompt, domains_data):
    """Parse and validate EMBASSIES from spawn prompt. Max 2."""
    match = re.search(r'EMBASSIES:\s*([^\n]+)', prompt)
    if not match:
        return []

    raw = [e.strip() for e in match.group(1).split(',') if e.strip()]
    if domains_data:
        valid_ids = [t['id'] for t in domains_data.get('tribes', [])]
        return [e for e in raw if e in valid_ids][:2]
    return raw[:2]


def read_tribes(tribes_path):
    """Read tribes.json, returning parsed dict or None."""
    if not os.path.exists(tribes_path):
        return None
    try:
        with open(tribes_path, encoding='utf-8') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def update_domain_membership(
    domains_path,
    domain_id,
    agent_id,
    agent_type,
    timestamp,
    skills_path,
):
    """Update tribe members list and compute elder."""
    try:
        with open(domains_path, encoding='utf-8') as f:
            domains_doc = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        raise RuntimeError(f'Cannot read tribes.json: {e}')

    for domain in domains_doc.get('tribes', []):
        if domain['id'] == domain_id:
            members = domain.get('members', [])
            members.append({
                'id': agent_id,
                'type': agent_type,
                'shutdownAt': timestamp,
            })
            domain['members'] = members

            # Compute domain lead (most members of a type)
            type_counts = {}
            for m in members:
                t = m.get('type', '')
                type_counts[t] = type_counts.get(t, 0) + 1
            if type_counts:
                domain['domain_lead'] = max(type_counts, key=type_counts.get)

            # Compute elder (most skill demonstrations)
            try:
                with open(skills_path, encoding='utf-8') as sf:
                    skills_data = json.load(sf)
                skill_type_counts = {}
                for skill in skills_data.get('skills', []):
                    skill_tribe = skill.get('tribeId') or skill.get('domainId')
                    if skill_tribe == domain_id:
                        at = skill.get('agentType', '')
                        if at:
                            skill_type_counts[at] = skill_type_counts.get(at, 0) + skill.get('mandateCount', 1)
                if skill_type_counts:
                    domain['elder'] = max(skill_type_counts, key=skill_type_counts.get)
                else:
                    domain['elder'] = None
            except (FileNotFoundError, json.JSONDecodeError):
                pass
            break

    with open(domains_path, 'w', encoding='utf-8') as f:
        json.dump(domains_doc, f, indent=2)
