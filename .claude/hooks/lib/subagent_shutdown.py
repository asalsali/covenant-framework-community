"""Subagent shutdown orchestrator.

Handles the full SubagentStop hook flow: agent ID resolution, exit report
validation, registry archival, auto-memo generation, consolidation check,
futility review, mediation advisory, skills/baselines/trust/compliance
updates, domain membership, spawn request count, user model advisory.

Always exits 0 -- post-tool hooks cannot block (except missing exit report).
"""

import json
import os
import sys

from .hooks_common import get_project_dir, get_err_log_path, get_timestamp, log_error
from .resolve_agent import resolve_canonical_id
from .registry_ops import archive_agent, read_registry
from .validate_exit_report import validate_exit_report, generate_auto_memo
from .shutdown_ops import (
    check_consolidation_threshold,
    check_futility,
    check_mediation,
    update_skills_on_shutdown,
    update_baselines_on_shutdown,
    check_regression,
    write_compliance_report,
    check_peak_performance,
    check_spawn_request_count,
    check_user_model_advisory,
)
from .trust_ops import update_trust_on_shutdown
from .domain_ops import update_domain_membership


def run():
    """Main entry point for subagent shutdown hook."""
    project_dir = get_project_dir()
    err_log = get_err_log_path(project_dir)
    timestamp = get_timestamp()

    input_data = json.load(sys.stdin)
    raw_agent_id = input_data.get('agent_id', 'unknown')
    agent_type = input_data.get('agent_type', 'main')

    if agent_type != 'subagent' or raw_agent_id == 'unknown':
        return

    # Resolve canonical agent ID
    registry_path = os.path.join(project_dir, 'registry', 'agent-registry.json')
    thread_map_path = os.path.join(project_dir, 'registry', 'thread-map.json')
    agent_id, method = resolve_canonical_id(
        raw_agent_id,
        registry_path,
        thread_map_path,
        archive_on_resolve=True,
    )
    if agent_id != raw_agent_id:
        log_error(err_log, f"Resolved thread ID '{raw_agent_id}' -> canonical ID '{agent_id}'")

    log_error(err_log, f"SUNSET: Agent '{agent_id}' has completed its mandate.")

    # Consolidation threshold check
    threshold_reached, archived_count, interval = check_consolidation_threshold(registry_path)
    if threshold_reached:
        log_error(err_log, f'CONSOLIDATION THRESHOLD REACHED: {archived_count} agents archived since last Consolidation (threshold: {interval}).')
        log_error(err_log, 'Run /consolidation before the next mandate. The system needs to rest and remember.')

    # Compliance reminder
    log_error(err_log, f'COMPLIANCE: Run /compliance {agent_id} to record Constitution telemetry for this agent.')

    # Archive in registry
    if os.path.exists(registry_path):
        success = archive_agent(registry_path, agent_id, timestamp, err_log)
        if not success:
            print('WARNING: Could not acquire lock for agent_registry archival.', file=sys.stderr)

    # Check for exit report
    inheritance_dir = os.path.join(project_dir, 'memory', 'inheritance')
    exit_report_json = os.path.join(inheritance_dir, f'{agent_id}-exit_report.json')
    exit_report_md = os.path.join(inheritance_dir, f'{agent_id}.md')

    if not os.path.exists(exit_report_json) and not os.path.exists(exit_report_md):
        print(f"COVENANT VIOLATION: Agent '{agent_id}' shutdown without writing a exit_report.", file=sys.stderr)
        print(f"   Constitution Section VI requires a exit_report at memory/handoff/<agent-id>-exit_report.json", file=sys.stderr)
        print(f"   'A shutdown agent that leaves no handoff has lived in vain.' (Proverb 7)", file=sys.stderr)
        print(f"   Run /reconcile to retroactively create exit_reports for unregistered agents.", file=sys.stderr)
        sys.exit(2)

    log_error(err_log, 'Inheritance ritual complete. Exit_Report found.')

    # Schema validation (advisory)
    if os.path.exists(exit_report_json):
        _run_schema_validation(project_dir, agent_id, exit_report_json, err_log)

    # Exit report field validation (single pass)
    if os.path.exists(exit_report_json):
        result = validate_exit_report(exit_report_json, agent_id, registry_path)
        for warning in result.warnings:
            if 'COMPLIANCE VIOLATION' in warning or 'CF-COMP' in warning:
                print(warning, file=sys.stderr)
            elif 'TOKEN GAP' in warning:
                log_error(err_log, warning)
            else:
                print(f'WARNING: {warning}', file=sys.stderr)

    # Auto-generate memo
    memos_dir = os.path.join(project_dir, 'memory', 'memos')
    os.makedirs(memos_dir, exist_ok=True)
    if os.path.exists(exit_report_json):
        memo_name = generate_auto_memo(exit_report_json, agent_id, timestamp, memos_dir)
        if memo_name:
            print(f'Auto-memo written: {memo_name}')

    # Futility review advisory
    if os.path.exists(exit_report_json):
        futility_signals = check_futility(exit_report_json, agent_id, registry_path, inheritance_dir)
        if 'INCOMPLETE' in futility_signals:
            log_error(err_log, f"FUTILITY REVIEW ADVISORY: Agent '{agent_id}' shutdown with mandateCompleted: false.")
            log_error(err_log, 'Constitution XXIII: Was this a Constitution violation or systemic futility?')
        for sig in futility_signals:
            if sig.startswith('PATTERN:'):
                log_error(err_log, 'FUTILITY REVIEW TRIGGER: Similar mandates have been abandoned before.')
                log_error(err_log, 'Check memory/handoff/ for prior failures on this mandate type.')

    # Mediation advisory
    if os.path.exists(exit_report_json):
        mediation_sib = check_mediation(exit_report_json, agent_id, registry_path, inheritance_dir)
        if mediation_sib:
            log_error(err_log, f"Sibling '{mediation_sib}' may have contradictory findings with '{agent_id}'. Consider /mediate (Constitution XXXI).")

    # Registry file updates
    if os.path.exists(exit_report_json):
        try:
            with open(exit_report_json, encoding='utf-8') as f:
                exit_report = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            exit_report = {}

        if exit_report:
            agent_type_name = agent_id.split('-')[0] if '-' in agent_id else agent_id

            # Look up domain ID
            domain_id = None
            try:
                registry = read_registry(registry_path)
                for a in registry.get('agents', []):
                    if a.get('id') == agent_id:
                        domain_id = a.get('tribeId')
                        break
            except Exception:
                pass

            # Skills
            skills_path = os.path.join(project_dir, 'registry', 'skills.json')
            try:
                update_skills_on_shutdown(skills_path, agent_id, exit_report, domain_id, timestamp)
            except Exception as e:
                log_error(err_log, f'Skills update failed: {e}')

            # Baselines
            baselines_path = os.path.join(project_dir, 'registry', 'baselines.json')
            try:
                baselines_list, atn = update_baselines_on_shutdown(baselines_path, agent_id, exit_report, timestamp)
                check_regression(baselines_list, atn, err_log)
            except Exception as e:
                log_error(err_log, f'Baselines update failed: {e}')

            # Trust
            trust_path = os.path.join(project_dir, 'registry', 'trust-registry.json')
            completed = exit_report.get('mandateCompleted', False)
            try:
                new_level, promotions, demotions = update_trust_on_shutdown(
                    trust_path, agent_type_name, completed, timestamp,
                )
                for p in promotions:
                    print(f'TRUST PROMOTION: {p}', file=sys.stderr)
                for d in demotions:
                    print(f'TRUST DEMOTION: {d}', file=sys.stderr)
                print(f'Trust registry updated: {agent_type_name} (level: {new_level})')
            except Exception as e:
                log_error(err_log, f'Trust update failed: {e}')

            print(f'Registry files updated: skills.json, baselines.json')

            # Compliance report
            compliance_path = os.path.join(project_dir, 'registry', 'constitution-compliance.json')
            try:
                write_compliance_report(compliance_path, agent_id, exit_report, timestamp)
                print(f'Constitution compliance report written for {agent_id}')
            except Exception as e:
                log_error(err_log, f'Compliance report failed: {e}')

            # Peak performance check
            preview = check_peak_performance(exit_report)
            if preview:
                print(f'PEAK PERFORMANCE CHECK: Agent reported substantial success.', file=sys.stderr)
                print(f'   whatWorked: {preview}', file=sys.stderr)
                print(f'   Constitution XXVIII: If this output was exceptional, record it.', file=sys.stderr)

            # Domain membership update
            if domain_id:
                domains_path = os.path.join(project_dir, 'registry', 'tribes.json')
                try:
                    update_domain_membership(
                        domains_path, domain_id, agent_id, agent_type_name,
                        timestamp, skills_path,
                    )
                    print(f'Domain-level membership updated: {agent_id} -> {domain_id}')
                except Exception as e:
                    print(f'Domain-level membership update failed: {e}', file=sys.stderr)

    # Spawn request count + user model advisory
    spawn_count = check_spawn_request_count(project_dir, agent_id)
    if spawn_count:
        print(
            f'COMPLIANCE VIOLATION (Section XXXV): Agent "{agent_id}" filed {spawn_count} '
            f'spawn requests (limit: 2 per mandate).',
            file=sys.stderr,
        )

    user_model_path = os.path.join(project_dir, 'memory', 'user-model.json')
    if check_user_model_advisory(user_model_path):
        print('USER MODEL ADVISORY: user-model.json not updated this session.', file=sys.stderr)
        print('   Constitution XXVII: The Interpreter should update affinity and interaction history.', file=sys.stderr)


def _run_schema_validation(project_dir, agent_id, exit_report_path, err_log):
    """Run JSON schema validation on exit report (advisory)."""
    schema_path = os.path.join(project_dir, 'registry', 'schemas', 'exit-report.schema.json')
    if not os.path.exists(schema_path):
        return
    try:
        import jsonschema
        with open(schema_path, encoding='utf-8') as sf:
            schema = json.load(sf)
        with open(exit_report_path, encoding='utf-8') as tf:
            report = json.load(tf)
        jsonschema.validate(report, schema)
    except ImportError:
        pass  # jsonschema not available
    except Exception as e:
        if hasattr(e, 'absolute_path'):
            field = '.'.join(str(p) for p in e.absolute_path) if e.absolute_path else 'root'
            print(f'SCHEMA WARNING: Exit report for {agent_id} failed validation at {field}: {e.message}', file=sys.stderr)
        else:
            print(f'SCHEMA WARNING: Exit report schema check error: {e}', file=sys.stderr)


if __name__ == '__main__':
    run()
