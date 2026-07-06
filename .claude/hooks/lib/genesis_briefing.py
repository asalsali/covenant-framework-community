"""Genesis briefing generation.

Produces the genesis briefing JSON for a newly spawned agent.
Includes: spirit snapshot, active agents, memory retrieval (weighted),
tribal context, unread memos, telos, preflight warnings, goal challenge,
regression warnings, dispositions, uncertainty signals, cost question.

Replaces the ~360-line briefing block in pre-tool-agent-gate.sh.
"""

import glob
import json
import os
import re
import sys

from .memory_retrieval import search_memory, extract_search_words, select_mode


def generate_briefing(
    project_dir,
    agent_id,
    prompt,
    description,
    registry,
    domain_id=None,
    timestamp='',
):
    """Generate the genesis briefing JSON for a newly spawned agent.

    Returns a dict suitable for writing to genesis-briefing.json.
    """
    briefing = {'agentId': agent_id, 'generatedAt': timestamp}
    agents = registry.get('agents', [])
    mandate_text = (prompt + ' ' + description).lower()

    # Spirit snapshot
    spirit_path = os.path.join(project_dir, 'registry', 'orientation.json')
    if os.path.exists(spirit_path):
        try:
            with open(spirit_path, encoding='utf-8') as f:
                briefing['spirit'] = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    # Active agents
    active_agents = [a for a in agents if a.get('status') == 'active']
    briefing['activeAgents'] = [
        {'id': a['id'], 'mandate': a.get('mandate', '')[:80], 'generation': a.get('generation', 0)}
        for a in active_agents[:8]
    ]

    # Memory retrieval -- XVI-D weighted + XVI-E mode-aware
    mode = select_mode(prompt)
    search_words = extract_search_words(prompt + ' ' + description)
    scored = search_memory(project_dir, search_words, mode=mode, domain_id=domain_id)
    briefing['memoryRetrievalFindings'] = [f[2] for f in scored]
    briefing['memoryRetrievalMode'] = mode
    if scored:
        briefing['memoryRetrievalWeights'] = {f[2]: f[1] for f in scored}

    # Tribal context
    if domain_id:
        briefing['domainId'] = domain_id
        _add_tribal_context(briefing, project_dir, domain_id)
        _add_tribal_memos(briefing, project_dir, domain_id)

    # Unread memos (with recipient filtering)
    _add_unread_memos(briefing, project_dir, agent_id, registry)

    # Telos
    telos = registry.get('revelation', {}).get('telos', '')
    if telos:
        briefing['telos'] = telos

    # Preflight (high-stakes mandates)
    _add_preflight(briefing, project_dir, mandate_text)

    # Goal challenge
    _add_goal_challenge(briefing, project_dir, mandate_text)

    # Regression warnings
    _add_regression_warnings(briefing, project_dir)

    # Dispositions
    _add_dispositions(briefing, project_dir, mandate_text)

    # Uncertainty signals
    _add_uncertainty_signals(briefing, project_dir, mandate_text)

    # Cost question
    _add_cost_question(briefing, mandate_text)

    return briefing


def _add_tribal_context(briefing, project_dir, domain_id):
    """Add tribal storehouse context to briefing."""
    tribal_dir = os.path.join(project_dir, 'memory', 'domain_level', domain_id)
    tribal_context = {}
    for fname in ['domain_memory.md', 'patterns.md', 'warnings.md']:
        fpath = os.path.join(tribal_dir, fname)
        if os.path.exists(fpath):
            try:
                with open(fpath, 'r', encoding='utf-8', errors='replace') as fh:
                    content = fh.read(1500)
                if (content.strip()
                        and 'No entries yet' not in content
                        and 'No patterns recorded' not in content
                        and 'No warnings recorded' not in content):
                    tribal_context[fname.replace('.md', '')] = content
            except (OSError, UnicodeDecodeError):
                pass
    if tribal_context:
        briefing['tribalStorehouse'] = tribal_context


def _add_tribal_memos(briefing, project_dir, domain_id):
    """Add unread tribal memos to briefing."""
    tribal_memos = []
    memos_dir = os.path.join(project_dir, 'memory', 'memos')
    if os.path.isdir(memos_dir):
        for fpath in glob.glob(os.path.join(memos_dir, f'tribal-{domain_id}-*.md')):
            try:
                with open(fpath, 'r', encoding='utf-8', errors='replace') as fh:
                    header = fh.read(500)
                if 'read: false' in header:
                    tribal_memos.append(os.path.basename(fpath))
            except (OSError, UnicodeDecodeError):
                pass
    if tribal_memos:
        briefing['tribalMemos'] = tribal_memos[:5]


def _add_unread_memos(briefing, project_dir, agent_id, registry):
    """Add unread memos addressed to this agent."""
    memos_dir = os.path.join(project_dir, 'memory', 'memos')
    if not os.path.isdir(memos_dir):
        briefing['unreadStructured Memos'] = []
        return

    # Derive agent type from ID
    agent_type = '-'.join(agent_id.split('-')[:-1]) if '-' in agent_id else agent_id
    agent_tribe = ''
    for a in registry.get('agents', []):
        if a.get('id') == agent_id:
            agent_tribe = a.get('tribeId', '')
            break

    valid_recipients = {'any', agent_type}
    if agent_tribe:
        valid_recipients.add('tribe:' + agent_tribe)
        valid_recipients.add(agent_tribe)

    unread = []
    for fpath in glob.glob(os.path.join(memos_dir, '*.md')):
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as fh:
                header = fh.read(500)
            if 'read: false' not in header:
                continue
            to_field = ''
            for line in header.split('\n'):
                if line.strip().startswith('to:'):
                    to_field = line.split(':', 1)[1].strip().lower()
                    break
            if not to_field:
                unread.append(os.path.basename(fpath))
            else:
                recipients = [r.strip() for r in to_field.split(',')]
                if any(r in valid_recipients for r in recipients):
                    unread.append(os.path.basename(fpath))
        except (OSError, UnicodeDecodeError):
            pass

    briefing['unreadStructured Memos'] = unread[:5]


def _add_preflight(briefing, project_dir, mandate_text):
    """Add preflight context for high-stakes mandates."""
    preflight_keywords = {'high-stakes', 'production', 'deploy', 'critical', 'migration'}
    is_high_stakes = any(kw in mandate_text for kw in preflight_keywords)
    if not is_high_stakes:
        is_high_stakes = 'tokensexpected' in mandate_text and 'high' in mandate_text
    if not is_high_stakes:
        return

    stop = {'the', 'a', 'an', 'to', 'for', 'and', 'of', 'in', 'on', 'with', 'is', 'it'}
    mandate_words = set(mandate_text.split()) - stop
    preflight_hits = []

    for sdir in [
        os.path.join(project_dir, 'memory', 'inheritance'),
        os.path.join(project_dir, 'memory', 'handoff'),
    ]:
        if not os.path.isdir(sdir):
            continue
        for fp in glob.glob(os.path.join(sdir, '*')):
            if not os.path.isfile(fp):
                continue
            bn = os.path.basename(fp)
            try:
                with open(fp, 'r', encoding='utf-8', errors='replace') as fh:
                    fc = fh.read(2000)
                if bn.startswith('futility-review-'):
                    preflight_hits.append({'file': bn, 'type': 'futility-review', 'snippet': fc[:200]})
                    continue
                if bn.endswith('-exit_report.json') or bn.endswith('-exit report.json'):
                    try:
                        ed = json.loads(fc[:4000]) if fc.strip().startswith('{') else {}
                    except (json.JSONDecodeError, ValueError):
                        ed = {}
                    if ed.get('mandateCompleted', True):
                        continue
                    em = ed.get('mandate', '').lower()
                    ew = set(em.split()) - stop
                    if len(mandate_words & ew) >= 2:
                        preflight_hits.append({'file': bn, 'type': 'failed-prior', 'mandate': em[:100]})
            except (OSError, UnicodeDecodeError):
                pass

    if preflight_hits:
        briefing['preflightContext'] = preflight_hits[:3]


def _add_goal_challenge(briefing, project_dir, mandate_text):
    """Add goal challenge warning if similar mandates were abandoned."""
    stop = {'the', 'a', 'an', 'to', 'for', 'and', 'of', 'in', 'on', 'with', 'is', 'it', 'this', 'that'}
    mandate_words = set(mandate_text.split()) - stop
    abandon_count = 0

    for sdir in [
        os.path.join(project_dir, 'memory', 'inheritance'),
        os.path.join(project_dir, 'memory', 'handoff'),
    ]:
        if not os.path.isdir(sdir):
            continue
        for fp in glob.glob(os.path.join(sdir, '*exit_report*')) + glob.glob(os.path.join(sdir, '*exit report*')):
            if not os.path.isfile(fp):
                continue
            try:
                with open(fp, 'r', encoding='utf-8', errors='replace') as fh:
                    raw = fh.read(3000)
                ed = json.loads(raw) if raw.strip().startswith('{') else {}
                if ed.get('mandateCompleted', True):
                    continue
                em = ed.get('mandate', '').lower()
                ew = set(em.split()) - stop
                if len(mandate_words & ew) >= 2:
                    abandon_count += 1
            except (OSError, json.JSONDecodeError, ValueError):
                pass

    if abandon_count >= 2:
        briefing['goalChallengeWarning'] = (
            f'WARNING: {abandon_count} similar mandates were previously abandoned. '
            f'Consider whether this goal is right, not just whether the plan is good. '
            f'(Constitution Section XXIV)'
        )


def _add_regression_warnings(briefing, project_dir):
    """Surface recent regression warnings from hook-errors.log."""
    hook_err_path = os.path.join(project_dir, 'registry', 'hook-errors.log')
    if not os.path.exists(hook_err_path):
        return
    try:
        with open(hook_err_path, 'r', encoding='utf-8', errors='replace') as hf:
            lines = hf.readlines()
        reg_warnings = [line.strip() for line in lines[-50:] if 'REGRESSION WARNING' in line]
        if reg_warnings:
            briefing['regressionWarnings'] = reg_warnings[-3:]
    except (OSError, UnicodeDecodeError):
        pass


def _add_dispositions(briefing, project_dir, mandate_text):
    """Match dispositions against mandate keywords."""
    disp_path = os.path.join(project_dir, 'registry', 'dispositions.json')
    if not os.path.exists(disp_path):
        return
    try:
        with open(disp_path, encoding='utf-8') as f:
            disp_doc = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return

    stop = {'the', 'a', 'an', 'to', 'for', 'and', 'of', 'in', 'on', 'with', 'is', 'it', 'when', 'rather', 'than'}
    mandate_words = set(mandate_text.split()) - stop

    scored = []
    for d in disp_doc.get('dispositions', []):
        dtext = (d.get('name', '') + ' ' + d.get('text', '') + ' ' + d.get('why', '')).lower()
        dwords = set(dtext.split()) - stop
        score = len(mandate_words & dwords)
        if score > 0:
            scored.append((score, d.get('name', ''), d.get('text', '')))

    scored.sort(key=lambda x: -x[0])
    if scored:
        briefing['dispositions'] = [{'name': d[1], 'text': d[2]} for d in scored[:3]]


def _add_uncertainty_signals(briefing, project_dir, mandate_text):
    """Detect uncertainty signals from user model and contradictory findings."""
    signals = []

    # Signal 1: User correction patterns
    um_path = os.path.join(project_dir, 'memory', 'user-model.json')
    if os.path.exists(um_path):
        try:
            with open(um_path, 'r', encoding='utf-8', errors='replace') as f:
                um = json.load(f)
            correction_kws = [
                'corrected', 'correction', 'user corrected', 'wrong', 'misunderstood',
                'not what', 'actually meant', 'clarified', 'fixed interpretation',
            ]
            mandate_kws = set(mandate_text.split()[:10]) - {'the', 'a', 'an', 'to', 'for', 'and', 'of', 'in', 'on', 'with', 'is', 'it'}
            correction_count = 0
            for ix in um.get('interactions', []):
                summary = ix.get('summary', '').lower()
                if any(ckw in summary for ckw in correction_kws):
                    sw = set(summary.split())
                    if len(mandate_kws & sw) >= 2:
                        correction_count += 1
            if correction_count >= 3:
                signals.append(f'User has corrected similar mandate interpretations {correction_count} times')
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    # Signal 2: Contradictory agent outputs
    inherit_dir = os.path.join(project_dir, 'memory', 'inheritance')
    if os.path.isdir(inherit_dir):
        recent_findings = {}
        sorted_files = []
        try:
            all_files = glob.glob(os.path.join(inherit_dir, '*exit_report*'))
            sorted_files = sorted(all_files, key=os.path.getmtime, reverse=True)[:20]
        except OSError:
            pass

        for fp in sorted_files:
            try:
                with open(fp, 'r', encoding='utf-8', errors='replace') as fh:
                    ed = json.loads(fh.read(3000))
                em = ed.get('mandate', '').lower()
                ew = set(em.split()) - {'the', 'a', 'an', 'to', 'for', 'and', 'of', 'in', 'on', 'with', 'is', 'it'}
                domain_key = frozenset(list(ew)[:5])
                if domain_key not in recent_findings:
                    recent_findings[domain_key] = []
                recent_findings[domain_key].append(ed.get('keyFindings', []))
            except (OSError, json.JSONDecodeError, ValueError):
                pass

        contra_kws = [
            ('add', 'remove'), ('enable', 'disable'), ('increase', 'decrease'),
            ('working', 'broken'), ('pass', 'fail'), ('yes', 'no'),
        ]
        for dk, flist in recent_findings.items():
            if len(flist) < 2:
                continue
            all_texts = [' '.join(f).lower() for f in flist]
            for pos, neg_kw in contra_kws:
                has_pos = any(pos in t for t in all_texts)
                has_neg = any(neg_kw in t for t in all_texts)
                if has_pos and has_neg:
                    signals.append(f'Contradictory findings detected in domain {list(dk)[:3]}')
                    break

    if signals:
        briefing['uncertaintyWarning'] = {
            'message': 'UNCERTAINTY PROTOCOL: Conditions detected that suggest interpretation uncertainty. (Constitution Section XXIX)',
            'signals': signals[:3],
        }


def _add_cost_question(briefing, mandate_text):
    """Detect destructive actions targeting production/shared state."""
    destructive_kws = {
        'delete', 'drop', 'remove', 'overwrite', 'force-push', 'force push',
        'reset', 'destroy', 'purge', 'wipe', 'truncate', 'erase',
    }
    production_kws = {
        'production', 'deploy', 'main branch', 'main', 'master', 'live',
        'shared', 'remote', 'push', 'prod', 'release', 'public',
    }
    found_destructive = [kw for kw in destructive_kws if kw in mandate_text]
    found_production = [kw for kw in production_kws if kw in mandate_text]

    if found_destructive and found_production:
        briefing['costQuestionWarning'] = {
            'message': (
                'COST QUESTION: This mandate involves destructive action on '
                'production/shared state. Completing it will cause known consequences. '
                '(Constitution Section XXVI)'
            ),
            'destructiveActions': found_destructive[:3],
            'targets': found_production[:3],
            'question': (
                f'Completing this mandate will {found_destructive[0]} '
                f'{found_production[0]} state. Proceed knowing this cost?'
            ),
        }
