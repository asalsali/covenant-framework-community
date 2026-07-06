"""Shutdown auxiliary operations.

Handles consolidation threshold checking, futility review, mediation
advisory, skills/baselines/trust updates, compliance reports, and
domain membership updates at agent shutdown.
"""

import json
import os
import re
import sys

from .hooks_common import log_error


def check_consolidation_threshold(registry_path):
    """Check if consolidation threshold is reached.

    Returns (threshold_reached, archived_count, interval).
    """
    try:
        with open(registry_path, encoding='utf-8') as f:
            registry = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return False, 0, 10

    interval = registry.get('canon', {}).get('sabbathInterval', 10)
    last_consolidation = registry.get('lastSabbath', '1970-01-01')
    archived = [
        a for a in registry.get('agents', [])
        if a.get('status') == 'archived'
        and a.get('shutdownAt', '') > last_consolidation
    ]
    return len(archived) >= interval, len(archived), interval


def check_futility(exit_report_path, agent_id, registry_path, inheritance_dir):
    """Check for futility signals.

    Returns list of futility signals: 'INCOMPLETE', 'PATTERN:N'.
    """
    try:
        with open(exit_report_path, encoding='utf-8') as f:
            report = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []

    results = []

    completed = report.get('mandateCompleted', True)
    if not completed:
        results.append('INCOMPLETE')

    current_mandate = report.get('mandate', '').lower()
    if not completed and current_mandate:
        try:
            with open(registry_path, encoding='utf-8') as f:
                registry = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            registry = {}

        common = {'the', 'a', 'an', 'to', 'for', 'and', 'of', 'in', 'on', 'with', 'is', 'it', 'this', 'that'}
        current_words = set(current_mandate.split()) - common
        abandon_count = 0

        for agent in registry.get('agents', []):
            if agent.get('id') == agent_id:
                continue
            if agent.get('status') != 'archived':
                continue
            other_mandate = agent.get('mandate', '').lower()
            other_words = set(other_mandate.split()) - common
            overlap = current_words & other_words
            if len(overlap) >= 2:
                other_report_path = os.path.join(inheritance_dir, agent['id'] + '-exit_report.json')
                if os.path.exists(other_report_path):
                    try:
                        with open(other_report_path, encoding='utf-8') as f2:
                            other_report = json.load(f2)
                        if not other_report.get('mandateCompleted', True):
                            abandon_count += 1
                    except (FileNotFoundError, json.JSONDecodeError):
                        pass

        if abandon_count >= 2:
            results.append(f'PATTERN:{abandon_count}')

    return results


def check_mediation(exit_report_path, agent_id, registry_path, inheritance_dir):
    """Check for contradictory findings with siblings.

    Returns sibling agent ID with contradictory findings, or None.
    """
    try:
        with open(exit_report_path, encoding='utf-8') as f:
            report = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None

    if not report.get('mandateCompleted', False):
        return None

    findings = [w.lower() for kf in report.get('keyFindings', []) for w in kf.split()]
    stop = {'the', 'a', 'an', 'to', 'for', 'and', 'of', 'in', 'on', 'with', 'is', 'it', 'this', 'that', 'was', 'were', 'been'}
    neg = {'not', 'no', 'never', 'false', 'incorrect', 'wrong', 'fail', 'reject', 'unable', 'missing'}
    my_words = set(findings) - stop - neg
    my_neg = bool(set(findings) & neg)

    try:
        with open(registry_path, encoding='utf-8') as f:
            registry = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None

    me = next((a for a in registry.get('agents', []) if a.get('id') == agent_id), None)
    if not me or not me.get('parentId', ''):
        return None

    for a in registry.get('agents', []):
        if a.get('id') == agent_id or a.get('parentId') != me['parentId']:
            continue
        sp = os.path.join(inheritance_dir, a['id'] + '-exit_report.json')
        if not os.path.exists(sp):
            continue
        try:
            with open(sp, encoding='utf-8') as f2:
                st = json.load(f2)
        except (FileNotFoundError, json.JSONDecodeError):
            continue
        if not st.get('mandateCompleted', False):
            continue
        sf = [w.lower() for kf in st.get('keyFindings', []) for w in kf.split()]
        sib_words = set(sf) - stop - neg
        sib_neg = bool(set(sf) & neg)
        if len(my_words & sib_words) >= 2 and my_neg != sib_neg:
            return a['id']

    return None


def _normalize_skill(mandate_text):
    """Extract a kebab-case skill name from mandate text."""
    stop_words = {
        'the', 'a', 'an', 'and', 'or', 'for', 'to', 'of', 'in', 'on', 'at', 'is',
        'it', 'be', 'as', 'do', 'by', 'from', 'with', 'all', 'this', 'that', 'not',
        'was', 'are', 'has', 'had', 'but', 'its', 'no', 'up', 'out', 'so', 'if',
        'than', 'into', 'over', 'such', 'can', 'will', 'may', 'would', 'could',
        'should', 'about', 'just', 'also', 'agent', 'mandate', 'spawn', 'plan',
        'session', 'epoch', 'parent', 'intermediate',
    }
    text = re.sub(r'[^a-z0-9\s]', ' ', mandate_text.lower())
    words = [w for w in text.split() if w not in stop_words and len(w) > 2]
    skill_words = words[:3] if len(words) >= 3 else words[:2] if len(words) >= 2 else words
    if not skill_words:
        return 'general-task'
    return '-'.join(skill_words)


def update_skills_on_shutdown(skills_path, agent_id, exit_report, domain_id, timestamp):
    """Update skills.json with demonstrated skills from this agent."""
    skills_doc = {'description': '', 'skills': [], 'schema': {}}
    if os.path.exists(skills_path):
        try:
            with open(skills_path, encoding='utf-8') as f:
                skills_doc = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    skills_list = skills_doc.get('skills', [])
    mandate = exit_report.get('mandate', '')
    what_worked = exit_report.get('whatWorked', '')
    agent_type_name = agent_id.split('-')[0] if '-' in agent_id else agent_id
    skill_name = _normalize_skill(mandate)

    existing_skill = None
    for s in skills_list:
        if s.get('agentType') == agent_type_name and s.get('skill') == skill_name:
            existing_skill = s
            break

    if existing_skill:
        existing_skill['mandateCount'] = existing_skill.get('mandateCount', 1) + 1
        existing_skill['lastUsed'] = timestamp
        if what_worked:
            existing_skill['confidenceNote'] = what_worked[:200]
    else:
        skills_list.append({
            'agentType': agent_type_name,
            'skill': skill_name,
            'demonstrated': True,
            'firstDemonstrated': timestamp,
            'mandateCount': 1,
            'lastUsed': timestamp,
            'confidenceNote': what_worked[:200] if what_worked else '',
            'tribeId': domain_id,
        })

    skills_doc['skills'] = skills_list
    with open(skills_path, 'w', encoding='utf-8') as f:
        json.dump(skills_doc, f, indent=2)


def update_baselines_on_shutdown(baselines_path, agent_id, exit_report, timestamp):
    """Update baselines.json with performance data from this agent."""
    baselines_doc = {'description': '', 'baselines': [], 'schema': {}}
    if os.path.exists(baselines_path):
        try:
            with open(baselines_path, encoding='utf-8') as f:
                baselines_doc = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    baselines_list = baselines_doc.get('baselines', [])
    token = exit_report.get('tokenConsumed', 'unknown')
    completed = exit_report.get('mandateCompleted', False)
    agent_type_name = agent_id.split('-')[0] if '-' in agent_id else agent_id

    existing = [b for b in baselines_list if b.get('agentType') == agent_type_name]
    run_entry = {
        'agentId': agent_id,
        'timestamp': timestamp,
        'completed': completed,
        'tokenConsumed': str(token),
        'exit_reportComplete': True,
    }

    if not existing:
        baselines_list.append({
            'agentType': agent_type_name,
            'metric': 'mandate_completion',
            'baselineValue': 1 if completed else 0,
            'recordedAt': timestamp,
            'lastChecked': timestamp,
            'degradationThreshold': 30,
            'runs': [run_entry],
        })
    else:
        existing[0]['lastChecked'] = timestamp
        existing[0].setdefault('runs', []).append(run_entry)

    baselines_doc['baselines'] = baselines_list
    with open(baselines_path, 'w', encoding='utf-8') as f:
        json.dump(baselines_doc, f, indent=2)

    return baselines_list, agent_type_name


def check_regression(baselines_list, agent_type_name, err_log):
    """Check if current agent's token consumption deviates >30% from baseline."""
    baseline_entry = [b for b in baselines_list if b.get('agentType') == agent_type_name]
    if not baseline_entry or len(baseline_entry[0].get('runs', [])) < 2:
        return

    runs = baseline_entry[0]['runs']
    token_vals = []
    for r in runs:
        try:
            tv = int(str(r.get('tokenConsumed', '0')).replace(',', ''))
            if tv > 0:
                token_vals.append(tv)
        except (ValueError, TypeError):
            pass

    if len(token_vals) < 2:
        return

    baseline_avg = sum(token_vals[:-1]) / len(token_vals[:-1])
    current = token_vals[-1]
    if baseline_avg > 0:
        deviation = abs(current - baseline_avg) / baseline_avg * 100
        if deviation > 30:
            direction = 'over' if current > baseline_avg else 'under'
            log_error(
                err_log,
                f'REGRESSION WARNING (Constitution XIX): Agent type '
                f'{agent_type_name} token consumption {direction}-deviated '
                f'{deviation:.0f}% from baseline (current: {current}, '
                f'baseline avg: {baseline_avg:.0f}). Possible degradation.'
            )


def write_compliance_report(compliance_path, agent_id, exit_report, timestamp):
    """Write auto-compliance report at shutdown."""
    try:
        with open(compliance_path, encoding='utf-8') as f:
            compliance_doc = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        compliance_doc = {'description': 'Constitution telemetry', 'reports': []}

    completed = exit_report.get('mandateCompleted', False)
    token = exit_report.get('tokenConsumed', 'unknown')

    checks = {
        'exit_reportWritten': True,
        'mandateScope': completed,
        'tokenWithinBudget': str(token) not in ['gluttonous', 'excessive'],
        'spiritAlignment': bool(exit_report.get('spiritContribution', '')),
    }
    passed = sum(1 for v in checks.values() if v)
    total = len(checks)

    compliance_doc.setdefault('reports', []).append({
        'agentId': agent_id,
        'shutdownAt': timestamp,
        'checks': checks,
        'overallCompliance': round(passed / total * 100),
        'notes': f'Auto-generated at shutdown. {passed}/{total} checks passed.',
    })
    with open(compliance_path, 'w', encoding='utf-8') as f:
        json.dump(compliance_doc, f, indent=2)


def check_peak_performance(exit_report):
    """Check if agent reported substantial success. Returns advisory string or None."""
    completed = exit_report.get('mandateCompleted', False)
    what_worked = exit_report.get('whatWorked', '')
    if completed and len(what_worked) > 50:
        preview = what_worked[:100].replace('\n', ' ')
        return preview
    return None


def check_spawn_request_count(project_dir, agent_id):
    """Check if agent exceeded spawn request limit (max 2). Returns count or 0."""
    import glob as _glob
    memos_dir = os.path.join(project_dir, 'memory', 'memos')
    pattern = os.path.join(memos_dir, f'spawn-request-{agent_id}-*.md')
    count = len(_glob.glob(pattern))
    return count if count > 2 else 0


def check_user_model_advisory(user_model_path):
    """Check if user model needs updating. Returns True if stale."""
    from datetime import datetime, timezone, timedelta
    if not user_model_path or not os.path.exists(user_model_path):
        return False
    try:
        with open(user_model_path, encoding='utf-8') as f:
            um = json.load(f)
        last_updated = um.get('lastUpdated', '')
        if last_updated:
            updated_dt = datetime.fromisoformat(last_updated.replace('Z', '+00:00'))
            age = datetime.now(timezone.utc) - updated_dt
            if age > timedelta(hours=1):
                return True
    except (FileNotFoundError, json.JSONDecodeError, ValueError, TypeError):
        pass
    return False
