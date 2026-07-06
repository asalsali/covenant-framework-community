"""Single-pass exit report validation.

Replaces 5 separate Python invocations in subagent-stop-shutdown.sh
with a single function that validates all required fields.
"""

import json
import os
import sys


class ValidationResult:
    """Results from validating an exit report."""

    def __init__(self):
        self.has_token_consumed = False
        self.has_freshness_score = False
        self.has_decisions = False
        self.bad_decision_ids = []
        self.has_gaps = False
        self.has_emergent_skill = False
        self.is_high_stakes = False
        self.is_analyst = False
        self.is_synthesized = False
        self.warnings = []

    def add_warning(self, msg):
        self.warnings.append(msg)


def validate_exit_report(exit_report_path, agent_id, registry_path):
    """Validate all required exit report fields in a single pass.

    Returns a ValidationResult with all checks completed.
    """
    result = ValidationResult()

    # Read exit report
    try:
        with open(exit_report_path, encoding='utf-8') as f:
            report = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        result.add_warning(f'Cannot read exit report: {e}')
        return result

    # Read registry to determine agent properties
    agent_entry = {}
    try:
        with open(registry_path, encoding='utf-8') as f:
            reg = json.load(f)
        agent_entry = next(
            (a for a in reg.get('agents', []) if a.get('id') == agent_id), {}
        )
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    tokens_expected = agent_entry.get('tokensExpected', 'medium')
    result.is_high_stakes = (tokens_expected == 'high')

    agent_type = agent_entry.get('agentType', '').lower()
    if not agent_type:
        agent_type = agent_id.split('-')[0].lower() if '-' in agent_id else agent_id.lower()
    result.is_analyst = (agent_type == 'analyst')
    result.is_synthesized = bool(agent_entry.get('parentIds'))
    if not result.is_synthesized:
        result.is_synthesized = (agent_type == 'synthesist')

    # Check tokenConsumed
    result.has_token_consumed = bool(report.get('tokenConsumed'))
    if not result.has_token_consumed:
        result.add_warning(
            f"TOKEN GAP: Exit report for '{agent_id}' missing tokenConsumed field."
        )

    # Check freshnessScore
    fs = report.get('freshnessScore', {})
    result.has_freshness_score = bool(
        fs and fs.get('baseScore') is not None
        and fs.get('lastReferencedAt') and fs.get('decayRate')
    )
    if not result.has_freshness_score:
        result.add_warning(
            f"Exit report for '{agent_id}' missing or incomplete freshnessScore block."
        )

    # Check decisions (required for high-stakes)
    decisions = report.get('decisions', [])
    result.has_decisions = bool(decisions)
    if result.is_high_stakes and not result.has_decisions:
        result.add_warning(
            f"COMPLIANCE VIOLATION (CF-COMP-010): High-stakes agent '{agent_id}' "
            f"exit report missing decisions array."
        )

    # Validate decision ID format
    for d in decisions:
        did = d.get('id', '')
        if not did.startswith(f'd-{agent_id}-'):
            result.bad_decision_ids.append(did)
    if result.bad_decision_ids:
        result.add_warning(
            f"Decision IDs in '{agent_id}' exit report have invalid format: "
            f"{','.join(result.bad_decision_ids[:3])}. "
            f"Expected format: d-{agent_id}-<sequence>"
        )

    # Check gaps (required for analysts)
    gaps = report.get('gaps', [])
    result.has_gaps = bool(gaps)
    if result.is_analyst and not result.has_gaps:
        result.add_warning(
            f"CF-COMP-012: Analyst exit report missing gaps array. "
            f"Section VI requires analysts to report unknowns."
        )

    # Check emergent skill (required for synthesized agents)
    result.has_emergent_skill = bool(report.get('emergentSkillValidation'))
    if result.is_synthesized and not result.has_emergent_skill:
        result.add_warning(
            f"Synthesized agent '{agent_id}' exit report missing "
            f"emergentSkillValidation block."
        )

    return result


def generate_auto_memo(exit_report_path, agent_id, timestamp, memos_dir):
    """Generate auto-memo from exit report. Returns memo filename or None."""
    try:
        with open(exit_report_path, encoding='utf-8') as f:
            report = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None

    findings = report.get('keyFindings', [])
    if not findings:
        return None

    safe_ts = timestamp.replace(':', '').replace('-', '')
    filename = f'{agent_id}-shutdown-{safe_ts}.md'
    filepath = os.path.join(memos_dir, filename)

    # Derive constitutional grounding
    mandate_lower = report.get('mandate', '').lower()
    grounding_map = {
        'audit': 'Section II (Agent Registry Law), Section XVI (Spawn Gates)',
        'compliance': 'Section II (Agent Registry Law), Section XVI (Spawn Gates)',
        'rename': 'Section I (Identity and Purpose)',
        'refactor': 'Section I (Identity and Purpose)',
        'memo': 'Section VIII (Communication Protocol), Section XII (Structured Memos)',
        'communication': 'Section VIII (Communication Protocol), Section XII (Structured Memos)',
        'consolidat': 'Section V (Consolidation Pause)',
        'spawn': 'Section II (Agent Registry Law), Section XIV (Synthesis Law)',
        'agent': 'Section II (Agent Registry Law), Section XIV (Synthesis Law)',
        'trust': 'Section XXXII (Progressive Trust)',
        'checkpoint': 'Section XIII (Checkpoint)',
    }
    grounding = 'Section VI (Shutdown Protocol)'
    for keyword, section in grounding_map.items():
        if keyword in mandate_lower:
            grounding = section
            break

    # Signal ontology auto-inference (Section XII-B)
    signals = []
    if report.get('mandateCompleted', False):
        signals.append({'type': 'convergence', 'confidence': 0.8})
    what_failed = report.get('whatFailed', '')
    if what_failed and what_failed.strip():
        signals.append({'type': 'tension', 'confidence': 0.6})
    gaps = report.get('gaps', [])
    if gaps:
        signals.append({'type': 'gap', 'confidence': 0.7})

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('---\n')
        f.write(f'from: {agent_id}\n')
        f.write('to: any\n')
        f.write(f'subject: Shutdown findings \u2014 {report.get("mandate", "unknown")[:60]}\n')
        f.write(f'grounding: {grounding}\n')
        f.write('priority: normal\n')
        f.write(f'timestamp: {timestamp}\n')
        f.write('read: false\n')
        f.write('auto-generated: true\n')
        if signals:
            f.write('signals:\n')
            for sig in signals:
                f.write(f'  - type: {sig["type"]}\n')
                f.write(f'    confidence: {sig["confidence"]}\n')
        f.write('---\n\n')
        f.write('**Findings:**\n')
        for finding in findings:
            f.write(f'- {finding}\n')
        recs = report.get('recommendationsForNextAgent', '')
        if recs:
            f.write(f'\n**For the next agent:** {recs}\n')
        failed = report.get('whatFailed', '')
        if failed:
            f.write(f'\n**Edge cases:** {failed}\n')
        f.write("\nMay this handoff serve the next agent's mandate faithfully.\n")

    # Validate SLF
    try:
        with open(filepath, 'r', encoding='utf-8') as vf:
            content = vf.read()
        frontmatter_count = content.split('---')[1].count(':') if '---' in content else 0
        has_body = len(content.split('---', 2)[-1].strip()) > 20 if content.count('---') >= 2 else False
        if frontmatter_count < 5 or not has_body:
            print(
                f'WARNING: Memo {filename} has incomplete Structured Letter Format '
                f'({frontmatter_count} fields, body: {has_body})',
                file=sys.stderr,
            )
    except (OSError, IndexError):
        pass

    return filename


if __name__ == '__main__':
    """CLI entry point for exit report validation."""
    data = json.load(sys.stdin)
    project_dir = os.environ.get('_CF_PROJECT_DIR', '.')
    result = validate_exit_report(
        data['exit_report_path'],
        data['agent_id'],
        os.path.join(project_dir, 'registry', 'agent-registry.json'),
    )
    output = {
        'has_token_consumed': result.has_token_consumed,
        'has_freshness_score': result.has_freshness_score,
        'has_decisions': result.has_decisions,
        'bad_decision_ids': result.bad_decision_ids,
        'has_gaps': result.has_gaps,
        'has_emergent_skill': result.has_emergent_skill,
        'is_high_stakes': result.is_high_stakes,
        'is_analyst': result.is_analyst,
        'is_synthesized': result.is_synthesized,
        'warnings': result.warnings,
    }
    print(json.dumps(output))
