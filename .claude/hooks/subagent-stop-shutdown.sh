#!/bin/bash
# ============================================================
# SHUTDOWN HANDLER — SubagentStop Hook
# Triggers handoff archival when a subagent completes.
# ============================================================
# ============================================================
# RECOVERY POLICY SUMMARY
# ────────────────────────────────────────────────────────────
# CHECK                              | POLICY   | ACTION
# Python not found                   | BLOCK    | exit 2
# Exit report missing                | BLOCK    | exit 2
# tokenConsumed missing              | WARN     | log to hook-errors.log
# freshnessScore missing             | WARN     | stderr warning
# decisions missing (high-stakes)    | WARN     | stderr warning
# decision ID format invalid         | WARN     | stderr warning
# Analyst gaps array missing         | WARN     | stderr warning (CF-COMP-012)
# Consolidation threshold reached    | INFO     | log to hook-errors.log
# Compliance reminder                | INFO     | log to hook-errors.log
# Futility review advisory           | INFO     | log to hook-errors.log
# Mediation advisory                 | INFO     | log to hook-errors.log
# Peak performance check             | INFO     | stderr info
# User model advisory                | INFO     | stderr info
# Spawn request count exceeded       | WARN     | stderr warning
# ============================================================

# Detect python command
# Detect python — prefer 'python' on Windows (python3 shim causes Permission Denied in Git Bash)
if command -v cygpath >/dev/null 2>&1 || [ -n "$MSYSTEM" ]; then
  PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
else
  PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
fi
# RECOVERY: BLOCK — python required for all shutdown checks, exit 2
if [ -z "$PYTHON" ]; then
  echo "🚫 SUNSET HOOK: python not found — shutdown ritual CANNOT run." >&2
  echo "   Install python3 or add it to PATH. Agents will shutdown without exit_reports." >&2
  exit 2
fi

# Error log — replaces silent 2>/dev/null suppression on Python blocks
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_ERR_LOG="${_HOOK_DIR:+${_HOOK_DIR}/../../registry/hook-errors.log}"
[ -n "$_ERR_LOG" ] && command -v cygpath >/dev/null 2>&1 && _ERR_LOG="$(cygpath -m "$_ERR_LOG")"
_ERR_LOG="${_ERR_LOG:-/dev/null}"

INPUT=$(cat)
RAW_AGENT_ID=$(printf '%s' "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_id','unknown'))" 2>>"$_ERR_LOG")
AGENT_TYPE=$(printf '%s' "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_type','main'))" 2>>"$_ERR_LOG")
TIMESTAMP=$( "$PYTHON" -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>>"$_ERR_LOG" )

  # Resolve paths early — needed for Consolidation check AND archival below
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)}"
  command -v cygpath >/dev/null 2>&1 && PROJECT_DIR="$(cygpath -m "$PROJECT_DIR")"
  GENEALOGY="$PROJECT_DIR/registry/agent-registry.json"
  # Export for Python subprocesses to avoid backslash escaping issues
  export _CF_GENEALOGY="$GENEALOGY"
  export _CF_PROJECT_DIR="$PROJECT_DIR"

  # --- Resolve raw thread ID to canonical agent ID ---
  # Claude Code passes a hex thread ID (e.g. "a2f212ca3e8722763") as agent_id,
  # but the agent_registry uses canonical IDs (e.g. "analyst-20260506T052804").
  # Strategy: find the most recently born active agent in agent_registry — that is
  # the one that just completed. Fallback: use raw ID if it matches directly.
  AGENT_ID="$RAW_AGENT_ID"
  if [ -f "$GENEALOGY" ] && [ "$RAW_AGENT_ID" != "unknown" ]; then
    RESOLVED_ID=$( "$PYTHON" -c "
import json, os, sys

agent_registry_path = os.environ.get('_CF_GENEALOGY', '')
raw_id = '$RAW_AGENT_ID'

try:
    with open(agent_registry_path, encoding='utf-8') as f:
        registry = json.load(f)
except:
    print(raw_id)
    sys.exit(0)

agents = registry.get('agents', [])

# First: check if the raw ID matches any agent directly
for a in agents:
    if a.get('id') == raw_id:
        print(raw_id)
        sys.exit(0)

# Second: check thread-map.json for thread ID -> canonical ID mapping
thread_map_path = os.path.join(os.path.dirname(agent_registry_path), 'thread-map.json')
resolved_via_thread_map = False
try:
    with open(thread_map_path) as f:
        thread_map = json.load(f)
    for cid, entry in thread_map.items():
        if entry.get('threadId') == raw_id and entry.get('status') == 'active':
            print(cid)
            # Mark as archived in thread-map
            thread_map[cid]['status'] = 'archived'
            try:
                with open(thread_map_path, 'w') as f:
                    json.dump(thread_map, f, indent=2)
            except: pass
            resolved_via_thread_map = True
            break
except: pass

# Third: check if raw_id matches a canonical ID (key) in thread-map directly
# This catches the case where threadId was never assigned but the canonical ID
# is passed as raw_id -- the common path since threadIds are rarely populated.
if not resolved_via_thread_map:
    try:
        if not thread_map:
            with open(thread_map_path) as f:
                thread_map = json.load(f)
    except:
        thread_map = {}
    if raw_id in thread_map and thread_map[raw_id].get('status') == 'active':
        print(raw_id)
        thread_map[raw_id]['status'] = 'archived'
        try:
            with open(thread_map_path, 'w') as f:
                json.dump(thread_map, f, indent=2)
        except: pass
        resolved_via_thread_map = True

if not resolved_via_thread_map:
    # Fourth: fallback heuristic — oldest active non-root agent
    active = [a for a in agents if a.get('status') == 'active' and a.get('id') != 'root']
    if len(active) == 1:
        # Only one active agent — unambiguous
        print(active[0]['id'])
    elif active:
        # Multiple active: pick the oldest (most likely to complete first)
        active.sort(key=lambda a: a.get('bornAt', ''))
        print(active[0]['id'])
    else:
        print(raw_id)
" 2>>"$_ERR_LOG" )
    if [ -n "$RESOLVED_ID" ]; then
      AGENT_ID="$RESOLVED_ID"
    fi
    if [ "$AGENT_ID" != "$RAW_AGENT_ID" ]; then
      echo "  Resolved thread ID '$RAW_AGENT_ID' -> canonical ID '$AGENT_ID'" >>"$_ERR_LOG"
    fi
  fi

if [ "$AGENT_TYPE" = "subagent" ] && [ "$AGENT_ID" != "unknown" ]; then
  echo "✦ SUNSET: Agent '$AGENT_ID' has completed its mandate." >>"$_ERR_LOG"

  # --- Consolidation threshold check (Constitution Section V) ---
  # RECOVERY: INFO — advisory logged to hook-errors.log, execution continues
  if [ -f "$GENEALOGY" ]; then
    CONSOLIDATION_CHECK=$( "$PYTHON" -c "
import json, os
with open(os.environ.get('_CF_GENEALOGY', ''), encoding='utf-8') as f:
    r = json.load(f)
interval = r.get('canon', {}).get('sabbathInterval', 10)
last_consolidation = r.get('lastSabbath', '1970-01-01')
archived = [a for a in r.get('agents', []) if a.get('status') == 'archived' and a.get('shutdownAt', '') > last_consolidation]
if len(archived) >= interval:
    print(f'CONSOLIDATION:{len(archived)}:{interval}')
else:
    print('OK')
" 2>>"$_ERR_LOG" )
    case "$CONSOLIDATION_CHECK" in
      CONSOLIDATION:*)
        IFS=':' read -r _ COUNT INTERVAL <<< "$CONSOLIDATION_CHECK"
        echo "⬛ CONSOLIDATION THRESHOLD REACHED: $COUNT agents archived since last Consolidation (threshold: $INTERVAL)." >>"$_ERR_LOG"
        echo "   Run /consolidation before the next mandate. The system needs to rest and remember." >>"$_ERR_LOG"
        ;;
    esac
  fi

  # --- Compliance reminder (Constitution Section XVI) ---
  # RECOVERY: INFO — advisory logged to hook-errors.log, execution continues
  echo "📋 COMPLIANCE: Run /compliance $AGENT_ID to record Constitution telemetry for this agent." >>"$_ERR_LOG"
  
  # Mark archived in agent_registry (with file locking — Constitution Gap 1 fix)
  if [ -f "$GENEALOGY" ]; then
    printf '%s' "{\"agent_id\":\"$AGENT_ID\",\"timestamp\":\"$TIMESTAMP\"}" | "$PYTHON" -c "
import json, os, sys

# Add hooks/lib to path for safe_json import
hooks_dir = os.path.dirname(os.path.abspath(os.environ.get('_CF_GENEALOGY', '')))
project_dir = os.environ.get('_CF_PROJECT_DIR', '')
lib_dir = os.path.join(project_dir, '.claude', 'hooks', 'lib')
if os.path.isdir(lib_dir):
    parent = os.path.join(project_dir, '.claude', 'hooks')
    if parent not in sys.path:
        sys.path.insert(0, parent)

meta = json.load(sys.stdin)
agent_registry_path = os.environ.get('_CF_GENEALOGY', '')
err_log = os.path.join(project_dir, 'registry', 'hook-errors.log')

try:
    from lib.safe_json import read_modify_write

    def archive_agent(registry):
        for agent in registry.get('agents', []):
            if agent.get('id') == meta['agent_id']:
                agent['status'] = 'archived'
                agent['shutdownAt'] = meta['timestamp']
        return registry

    if read_modify_write(agent_registry_path, archive_agent, err_log):
        print('Archived in agent_registry.')
    else:
        print('WARNING: Could not acquire lock for agent_registry archival.', file=sys.stderr)
except ImportError:
    # Fallback: inline write without locking (pre-Gap-1 behavior)
    with open(agent_registry_path, 'r', encoding='utf-8') as f:
        registry = json.load(f)
    for agent in registry.get('agents', []):
        if agent.get('id') == meta['agent_id']:
            agent['status'] = 'archived'
            agent['shutdownAt'] = meta['timestamp']
    import tempfile, shutil
    tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(agent_registry_path), suffix='.tmp')
    try:
        with os.fdopen(tmp_fd, 'w', encoding='utf-8') as f:
            json.dump(registry, f, indent=2)
        if os.name == 'nt':
            shutil.move(tmp_path, agent_registry_path)
        else:
            os.replace(tmp_path, agent_registry_path)
    except:
        try: os.unlink(tmp_path)
        except: pass
        raise
    print('Archived in agent_registry (fallback, no lock).')
" 2>>"$_ERR_LOG"
  fi
  
  # Check for exit_report (Constitution Section VI compliance)
  INHERITANCE_DIR="$PROJECT_DIR/memory/inheritance"
  export _CF_INHERITANCE_DIR="$INHERITANCE_DIR"
  TESTAMENT_JSON="$INHERITANCE_DIR/${AGENT_ID}-exit_report.json"
  TESTAMENT_MD="$INHERITANCE_DIR/${AGENT_ID}.md"
  # RECOVERY: BLOCK — exit report required, exit 2 if missing
  if [ ! -f "$TESTAMENT_JSON" ] && [ ! -f "$TESTAMENT_MD" ]; then
    echo "🚫 COVENANT VIOLATION: Agent '$AGENT_ID' shutdown without writing a exit_report." >&2
    echo "   Constitution Section VI requires a exit_report at memory/handoff/<agent-id>-exit_report.json" >&2
    echo "   'A shutdown agent that leaves no handoff has lived in vain.' (Proverb 7)" >&2
    echo "   Run /reconcile to retroactively create exit_reports for unregistered agents." >&2
    exit 2
  else
    echo "Inheritance ritual complete. Exit_Report found." >>"$_ERR_LOG"

    # --- Schema validation (Constitution VI + Faby-inspired contracts) ---
    # RECOVERY: WARN — schema validation is advisory, never blocks shutdown
    if [ -f "$TESTAMENT_JSON" ]; then
      "$PYTHON" -c "
import json, os, sys
project_dir = os.environ.get('_CF_PROJECT_DIR', '')
agent_id = os.environ.get('_CF_AGENT_ID', '$AGENT_ID')
exit_report_path = os.environ.get('_CF_TESTAMENT_JSON', '')
if not exit_report_path:
    exit_report_path = '$TESTAMENT_JSON'
schema_path = os.path.join(project_dir, 'registry', 'schemas', 'exit-report.schema.json')
if os.path.exists(schema_path):
    try:
        import jsonschema
        with open(schema_path, encoding='utf-8') as sf:
            schema = json.load(sf)
        with open(exit_report_path, encoding='utf-8') as tf:
            t = json.load(tf)
        try:
            jsonschema.validate(t, schema)
        except jsonschema.ValidationError as ve:
            field = '.'.join(str(p) for p in ve.absolute_path) if ve.absolute_path else 'root'
            print(f'SCHEMA WARNING: Exit report for {agent_id} failed validation at {field}: {ve.message}', file=sys.stderr)
    except ImportError:
        pass  # jsonschema not available on this machine
    except Exception as e:
        print(f'SCHEMA WARNING: Exit report schema check error: {e}', file=sys.stderr)
" 2>>"$_ERR_LOG"
    fi

    # Validate exit_report has tokenConsumed field (P7 — subagent token tracking)
    if [ -f "$TESTAMENT_JSON" ]; then
      HAS_TOKEN=$( printf '%s' "$TESTAMENT_JSON" | "$PYTHON" -c "
import json, sys
tpath = sys.stdin.read().strip()
with open(tpath, encoding='utf-8') as f:
    t = json.load(f)
print('yes' if t.get('tokenConsumed') else 'no')
" 2>>"$_ERR_LOG" )
      # RECOVERY: WARN — tokenConsumed missing logged to hook-errors.log
      if [ "$HAS_TOKEN" = "no" ]; then
        echo "⚠️  TOKEN GAP: Exit_Report for '$AGENT_ID' missing tokenConsumed field." >>"$_ERR_LOG"
        echo "   Constitution Section IV requires token tracking. Add tokenConsumed to the exit_report." >>"$_ERR_LOG"
      fi

      # Validate freshnessScore (Constitution Section VI-B)
      HAS_FRESHNESS=$( printf '%s' "$TESTAMENT_JSON" | "$PYTHON" -c "
import json, sys
tpath = sys.stdin.read().strip()
try:
    with open(tpath, encoding='utf-8') as f:
        t = json.load(f)
    fs = t.get('freshnessScore', {})
    if fs and fs.get('baseScore') is not None and fs.get('lastReferencedAt') and fs.get('decayRate'):
        print('yes')
    else:
        print('no')
except:
    print('no')
" 2>>"$_ERR_LOG" )
      # RECOVERY: WARN — freshnessScore missing, stderr warning
      if [ "$HAS_FRESHNESS" = "no" ]; then
        echo "WARNING: Exit report for '$AGENT_ID' missing or incomplete freshnessScore block (Constitution VI-B)." >&2
        echo "   Required fields: baseScore, lastReferencedAt, decayRate" >&2
      fi

      # Validate decisions array for high-stakes agents (Constitution Section VI-B / CF-COMP-010)
      DECISIONS_CHECK=$( printf '%s' "$TESTAMENT_JSON" | "$PYTHON" -c "
import json, os, sys
tpath = sys.stdin.read().strip()
agent_registry_path = os.environ.get('_CF_GENEALOGY', '')
agent_id = '$AGENT_ID'
try:
    with open(agent_registry_path, encoding='utf-8') as f:
        reg = json.load(f)
    agent_entry = next((a for a in reg.get('agents', []) if a.get('id') == agent_id), {})
    tokens_expected = agent_entry.get('tokensExpected', 'medium')
    if tokens_expected != 'high':
        print('SKIP')
        sys.exit(0)
    with open(tpath, encoding='utf-8') as f:
        t = json.load(f)
    decisions = t.get('decisions', [])
    if not decisions:
        print('MISSING')
    else:
        print('OK')
except:
    print('SKIP')
" 2>>"$_ERR_LOG" )
      # RECOVERY: WARN — decisions missing for high-stakes agent, stderr warning
      if [ "$DECISIONS_CHECK" = "MISSING" ]; then
        echo "COMPLIANCE VIOLATION (CF-COMP-010): High-stakes agent '$AGENT_ID' exit report missing decisions array." >&2
        echo "   Constitution Section VI-B requires decisions array for tokensExpected: high mandates." >&2
      fi

      # Validate decision ID format (Constitution Section VI-B)
      DECISION_FMT=$( printf '%s' "$TESTAMENT_JSON" | "$PYTHON" -c "
import json, sys
tpath = sys.stdin.read().strip()
agent_id = '$AGENT_ID'
try:
    with open(tpath, encoding='utf-8') as f:
        t = json.load(f)
    decisions = t.get('decisions', [])
    bad_ids = []
    for d in decisions:
        did = d.get('id', '')
        if not did.startswith(f'd-{agent_id}-'):
            bad_ids.append(did)
    if bad_ids:
        print('BAD:' + ','.join(bad_ids[:3]))
    else:
        print('OK')
except:
    print('OK')
" 2>>"$_ERR_LOG" )
      # RECOVERY: WARN — decision ID format invalid, stderr warning
      case "$DECISION_FMT" in
        BAD:*)
          BAD_IDS="${DECISION_FMT#BAD:}"
          echo "WARNING: Decision IDs in '$AGENT_ID' exit report have invalid format: $BAD_IDS" >&2
          echo "   Expected format: d-${AGENT_ID}-<sequence> (Constitution Section VI-B)" >&2
          ;;
      esac

      # --- Emergent Skill Validation for Synthesized Agents (Constitution XIV, rule 6) ---
      # RECOVERY: WARN — advisory via stderr, execution continues
      SYNTH_CHECK=$( printf '%s' "$TESTAMENT_JSON" | "$PYTHON" -c "
import json, os, sys
tpath = sys.stdin.read().strip()
agent_id = '$AGENT_ID'
agent_registry_path = os.environ.get('_CF_GENEALOGY', '')
try:
    # Determine if agent is synthesized (has parentIds) or is type synthesist
    agent_type = ''
    has_parent_ids = False
    try:
        with open(agent_registry_path, encoding='utf-8') as f:
            reg = json.load(f)
        entry = next((a for a in reg.get('agents', []) if a.get('id') == agent_id), {})
        agent_type = entry.get('agentType', '').lower()
        has_parent_ids = bool(entry.get('parentIds'))
    except: pass
    if not has_parent_ids and agent_type != 'synthesist':
        print('SKIP')
        sys.exit(0)
    with open(tpath, encoding='utf-8') as f:
        t = json.load(f)
    esv = t.get('emergentSkillValidation')
    if not esv:
        print('MISSING')
    else:
        print('OK')
except:
    print('SKIP')
" 2>>"$_ERR_LOG" )
      if [ "$SYNTH_CHECK" = "MISSING" ]; then
        echo "WARN: Synthesized agent '$AGENT_ID' exit report missing emergentSkillValidation block." >&2
        echo "   Constitution Section XIV (rule 6) requires synthesized agents to report whether" >&2
        echo "   the emergent skill proved real or theoretical. Schema:" >&2
        echo "   {declaredSkill, exercised, exerciseEvidence, couldParentADo, couldParentBDo, verdict, notes}" >&2
      fi

      # --- Gap Analysis Warning for Analysts (Section VI / CF-COMP-012) ---
      # RECOVERY: WARN — advisory via stderr, execution continues
      # Analysts must report unknowns; a missing or empty gaps array is a compliance gap.
      GAPS_CHECK=$( printf '%s' "$TESTAMENT_JSON" | "$PYTHON" -c "
import json, os, sys
tpath = sys.stdin.read().strip()
agent_id = '$AGENT_ID'
agent_registry_path = os.environ.get('_CF_GENEALOGY', '')
try:
    # Determine agent type: check registry entry first, fall back to ID prefix
    agent_type = ''
    try:
        with open(agent_registry_path, encoding='utf-8') as f:
            reg = json.load(f)
        entry = next((a for a in reg.get('agents', []) if a.get('id') == agent_id), {})
        agent_type = entry.get('agentType', '').lower()
    except: pass
    if not agent_type:
        agent_type = agent_id.split('-')[0].lower() if '-' in agent_id else agent_id.lower()
    if agent_type != 'analyst':
        print('SKIP')
        sys.exit(0)
    with open(tpath, encoding='utf-8') as f:
        t = json.load(f)
    gaps = t.get('gaps', [])
    if not gaps:
        print('MISSING')
    else:
        print('OK')
except:
    print('SKIP')
" 2>>"$_ERR_LOG" )
      if [ "$GAPS_CHECK" = "MISSING" ]; then
        echo "WARN:CF-COMP-012 — Analyst exit report missing gaps array. Section VI requires analysts to report unknowns." >&2
      fi
    fi

    # Auto-generate memo from exit_report (memo simplification)
    # This ensures lateral communication happens even when agents don't
    # explicitly write memos — the exit_report IS the memo content.
    EPISTLES_DIR="$PROJECT_DIR/memory/memos"
    mkdir -p "$EPISTLES_DIR"
    export _CF_TESTAMENT_JSON="$TESTAMENT_JSON"
    export _CF_EPISTLES_DIR="$EPISTLES_DIR"
    export _CF_AGENT_ID="$AGENT_ID"
    export _CF_TIMESTAMP="$TIMESTAMP"
    if [ -f "$TESTAMENT_JSON" ]; then
      "$PYTHON" -c "
import json, os, sys
exit_report_path = os.environ.get('_CF_TESTAMENT_JSON', '')
memos_dir = os.environ.get('_CF_EPISTLES_DIR', '')
agent_id = os.environ.get('_CF_AGENT_ID', '')
timestamp = os.environ.get('_CF_TIMESTAMP', '')
with open(exit_report_path, encoding='utf-8') as f:
    t = json.load(f)
findings = t.get('keyFindings', [])
if findings:
    safe_ts = timestamp.replace(':', '').replace('-', '')
    filename = agent_id + '-shutdown-' + safe_ts + '.md'
    filepath = os.path.join(memos_dir, filename)
    # Derive constitutional grounding from mandate (Constitution Section XII)
    mandate_lower = t.get('mandate', '').lower()
    if 'audit' in mandate_lower or 'compliance' in mandate_lower:
        grounding = 'Section II (Agent Registry Law), Section XVI (Spawn Gates)'
    elif 'rename' in mandate_lower or 'refactor' in mandate_lower:
        grounding = 'Section I (Identity and Purpose)'
    elif 'memo' in mandate_lower or 'communication' in mandate_lower:
        grounding = 'Section VIII (Communication Protocol), Section XII (Structured Memos)'
    elif 'consolidat' in mandate_lower:
        grounding = 'Section V (Consolidation Pause)'
    elif 'spawn' in mandate_lower or 'agent' in mandate_lower:
        grounding = 'Section II (Agent Registry Law), Section XIV (Synthesis Law)'
    elif 'trust' in mandate_lower:
        grounding = 'Section XXXII (Progressive Trust)'
    elif 'checkpoint' in mandate_lower:
        grounding = 'Section XIII (Checkpoint)'
    else:
        grounding = 'Section VI (Shutdown Protocol)'
    # --- Signal Ontology auto-inference (Constitution Section XII-B) ---
    # Infer signals from exit_report fields to enrich memo frontmatter.
    signals = []
    if t.get('mandateCompleted', False):
        signals.append({'type': 'convergence', 'confidence': 0.8})
    what_failed = t.get('whatFailed', '')
    if what_failed and what_failed.strip():
        signals.append({'type': 'tension', 'confidence': 0.6})
    gaps = t.get('gaps', [])
    if gaps and len(gaps) > 0:
        signals.append({'type': 'gap', 'confidence': 0.7})

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('---\n')
        f.write('from: ' + agent_id + '\n')
        f.write('to: any\n')
        f.write('subject: Shutdown findings — ' + t.get('mandate', 'unknown')[:60] + '\n')
        f.write('grounding: ' + grounding + '\n')
        f.write('priority: normal\n')
        f.write('timestamp: ' + timestamp + '\n')
        f.write('read: false\n')
        f.write('auto-generated: true\n')
        # Write signal ontology block (Section XII-B)
        if signals:
            f.write('signals:\n')
            for sig in signals:
                f.write('  - type: ' + sig['type'] + '\n')
                f.write('    confidence: ' + str(sig['confidence']) + '\n')
        f.write('---\n\n')
        f.write('**Findings:**\n')
        for finding in findings:
            f.write('- ' + finding + '\n')
        recs = t.get('recommendationsForNextAgent', '')
        if recs:
            f.write('\n**For the next agent:** ' + recs + '\n')
        failed = t.get('whatFailed', '')
        if failed:
            f.write('\n**Edge cases:** ' + failed + '\n')
        f.write('\nMay this handoff serve the next agent' + chr(39) + 's mandate faithfully.\n')
    # Validate Structured Letter Format (Constitution Section VIII/XII)
    try:
        with open(filepath, 'r', encoding='utf-8') as vf:
            content = vf.read()
        frontmatter_count = content.split('---')[1].count(':') if '---' in content else 0
        has_body = len(content.split('---', 2)[-1].strip()) > 20 if content.count('---') >= 2 else False
        if frontmatter_count < 5 or not has_body:
            print(f'WARNING: Memo {filename} has incomplete Structured Letter Format ({frontmatter_count} fields, body: {has_body})', file=sys.stderr)
    except:
        pass
    print('Auto-memo written: ' + filename)
" 2>>"$_ERR_LOG"
    fi
  fi

  # --- Futility Review advisory (Constitution Section XXIII) ---
  # RECOVERY: INFO — advisory logged to hook-errors.log, execution continues
  # If mandate was not completed, or similar mandates have been abandoned before,
  # surface the Futility Review question: Constitution violation or systemic futility?
  if [ -f "$TESTAMENT_JSON" ]; then
    FUTILITY_CHECK=$( "$PYTHON" -c "
import json, os, sys

exit_report_path = os.environ.get('_CF_TESTAMENT_JSON', '')
agent_registry_path = os.environ.get('_CF_GENEALOGY', '')
agent_id = os.environ.get('_CF_AGENT_ID', '')

try:
    with open(exit_report_path, encoding='utf-8') as f:
        t = json.load(f)
except:
    print('OK')
    sys.exit(0)

results = []

# Check 1: mandateCompleted is false
completed = t.get('mandateCompleted', True)
if not completed:
    results.append('INCOMPLETE')

# Check 2: similar mandates abandoned before
current_mandate = t.get('mandate', '').lower()
if not completed and current_mandate:
    try:
        with open(agent_registry_path, encoding='utf-8') as f:
            registry = json.load(f)
    except:
        registry = {}

    common = {'the','a','an','to','for','and','of','in','on','with','is','it','this','that'}
    current_words = set(current_mandate.split()) - common
    handoff_dir = os.environ.get('_CF_INHERITANCE_DIR', '')
    abandon_count = 0

    # Search archived agents' exit_reports for similar abandoned mandates
    for agent in registry.get('agents', []):
        if agent.get('id') == agent_id:
            continue
        if agent.get('status') != 'archived':
            continue
        other_mandate = agent.get('mandate', '').lower()
        other_words = set(other_mandate.split()) - common
        overlap = current_words & other_words
        if len(overlap) >= 2:
            # Check if that agent's exit_report also had mandateCompleted: false
            other_exit_report = os.path.join(handoff_dir, agent['id'] + '-exit_report.json')
            if os.path.exists(other_exit_report):
                try:
                    with open(other_exit_report, encoding='utf-8') as f2:
                        ot = json.load(f2)
                    if not ot.get('mandateCompleted', True):
                        abandon_count += 1
                except:
                    pass

    if abandon_count >= 2:
        results.append(f'PATTERN:{abandon_count}')

if results:
    print('|'.join(results))
else:
    print('OK')
" 2>>"$_ERR_LOG" )

    # Parse Futility Review results
    case "$FUTILITY_CHECK" in
      *INCOMPLETE*|*PATTERN:*)
        if [[ "$FUTILITY_CHECK" == *"INCOMPLETE"* ]]; then
          echo "📖 FUTILITY REVIEW ADVISORY: Agent '$AGENT_ID' shutdown with mandateCompleted: false." >>"$_ERR_LOG"
          echo "   Constitution XXIII: Was this a Constitution violation or systemic futility?" >>"$_ERR_LOG"
          echo "   Run /compliance $AGENT_ID for Constitution audit, or run Futility Review for futility analysis." >>"$_ERR_LOG"
        fi
        if [[ "$FUTILITY_CHECK" == *"PATTERN:"* ]]; then
          echo "📖 FUTILITY REVIEW TRIGGER: Similar mandates have been abandoned before." >>"$_ERR_LOG"
          echo "   Constitution XXIII says this pattern warrants Futility Review." >>"$_ERR_LOG"
          echo "   Check memory/handoff/ for prior failures on this mandate type." >>"$_ERR_LOG"
        fi
        ;;
    esac
  fi

  # --- Mediation advisory (Constitution XXXI) ---
  # RECOVERY: INFO — advisory logged to hook-errors.log, execution continues
  # If a completed sibling shares topic keywords but contradictory sentiment, suggest /mediate.
  if [ -f "$TESTAMENT_JSON" ]; then
    MEDIATION_SIB=$( "$PYTHON" -c "
import json, os, sys
try:
    with open(os.environ.get('_CF_TESTAMENT_JSON',''), encoding='utf-8') as f:
        t = json.load(f)
    if not t.get('mandateCompleted', False): sys.exit(0)
    findings = [w.lower() for kf in t.get('keyFindings',[]) for w in kf.split()]
    stop = {'the','a','an','to','for','and','of','in','on','with','is','it','this','that','was','were','been'}
    neg = {'not','no','never','false','incorrect','wrong','fail','reject','unable','missing'}
    my_words = set(findings) - stop - neg
    my_neg = bool(set(findings) & neg)
    reg_path = os.environ.get('_CF_GENEALOGY','')
    aid = os.environ.get('_CF_AGENT_ID','')
    with open(reg_path, encoding='utf-8') as f: reg = json.load(f)
    me = next((a for a in reg.get('agents',[]) if a.get('id')==aid), None)
    if not me or not me.get('parentId',''): sys.exit(0)
    inh = os.environ.get('_CF_INHERITANCE_DIR','')
    for a in reg.get('agents',[]):
        if a.get('id')==aid or a.get('parentId')!=me['parentId']: continue
        sp = os.path.join(inh, a['id']+'-exit_report.json')
        if not os.path.exists(sp): continue
        with open(sp, encoding='utf-8') as f2: st = json.load(f2)
        if not st.get('mandateCompleted', False): continue
        sf = [w.lower() for kf in st.get('keyFindings',[]) for w in kf.split()]
        sib_words = set(sf) - stop - neg
        sib_neg = bool(set(sf) & neg)
        if len(my_words & sib_words) >= 2 and my_neg != sib_neg:
            print(a['id']); break
except: pass
" 2>>"$_ERR_LOG" )
    if [ -n "$MEDIATION_SIB" ]; then
      echo "INFO: Sibling '$MEDIATION_SIB' may have contradictory findings with '$AGENT_ID'. Consider /mediate (Constitution XXXI)." >>"$_ERR_LOG"
    fi
  fi

  # --- Auto-update registry files from exit_report data ---
  if [ -f "$TESTAMENT_JSON" ]; then
    "$PYTHON" -c "
import json, os, sys
from datetime import datetime, timezone

exit_report_path = os.environ.get('_CF_TESTAMENT_JSON', '')
project_dir = os.environ.get('_CF_PROJECT_DIR', '')
agent_id = os.environ.get('_CF_AGENT_ID', '')
timestamp = os.environ.get('_CF_TIMESTAMP', '')

with open(exit_report_path, encoding='utf-8') as f:
    t = json.load(f)

# --- Update skills.json (Constitution Section XXXIII: Skills Registry) ---
skills_path = os.path.join(project_dir, 'registry', 'skills.json')
skills_doc = {'description': '', 'skills': [], 'schema': {}}
if os.path.exists(skills_path):
    try:
        with open(skills_path, encoding='utf-8') as f:
            skills_doc = json.load(f)
    except: pass

# Navigate into the 'skills' array within the structured document
skills_list = skills_doc.get('skills', [])

# Extract skills from exit_report's keyFindings and mandate
mandate = t.get('mandate', '')
what_worked = t.get('whatWorked', '')
# Derive agent type from ID (e.g. 'writer-20260506T051130' -> 'writer')
agent_type_name = agent_id.split('-')[0] if '-' in agent_id else agent_id

# Look up domainId from agent_registry (Constitution Section XXXIV)
domain_id = None
try:
    _ar_path = os.path.join(project_dir, 'registry', 'agent-registry.json')
    with open(_ar_path, encoding='utf-8') as f:
        reg = json.load(f)
    for a in reg.get('agents', []):
        if a.get('id') == agent_id:
            domain_id = a.get('tribeId')
            break
except: pass

# --- Normalize skill name from mandate text ---
def normalize_skill(mandate_text, key_findings=None):
    \"\"\"Extract a kebab-case skill name from mandate text.
    Takes the 2-3 most distinctive words, lowercases, hyphenates.\"\"\"
    import re
    stop_words = {'the','a','an','and','or','for','to','of','in','on','at','is',
                  'it','be','as','do','by','from','with','all','this','that','not',
                  'was','are','has','had','but','its','no','up','out','so','if',
                  'than','into','over','such','can','will','may','would','could',
                  'should','about','just','also','agent','mandate','spawn','plan',
                  'session','epoch','parent','intermediate'}
    text = mandate_text.lower()
    text = re.sub(r'[^a-z0-9\\s]', ' ', text)
    words = [w for w in text.split() if w not in stop_words and len(w) > 2]
    # Take up to 3 most distinctive words
    skill_words = words[:3] if len(words) >= 3 else words[:2] if len(words) >= 2 else words
    if not skill_words:
        return 'general-task'
    return '-'.join(skill_words)

skill_name = normalize_skill(mandate, t.get('keyFindings'))

# Check if this agent type already has this skill — increment rather than duplicate
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
    new_skill = {
        'agentType': agent_type_name,
        'skill': skill_name,
        'demonstrated': True,
        'firstDemonstrated': timestamp,
        'mandateCount': 1,
        'lastUsed': timestamp,
        'confidenceNote': what_worked[:200] if what_worked else '',
        'tribeId': domain_id
    }
    skills_list.append(new_skill)

skills_doc['skills'] = skills_list
with open(skills_path, 'w', encoding='utf-8') as f:
    json.dump(skills_doc, f, indent=2)

# --- Update baselines.json (Constitution Section XIX: Regression Drift) ---
baselines_path = os.path.join(project_dir, 'registry', 'baselines.json')
baselines_doc = {'description': '', 'baselines': [], 'schema': {}}
if os.path.exists(baselines_path):
    try:
        with open(baselines_path, encoding='utf-8') as f:
            baselines_doc = json.load(f)
    except: pass

# Navigate into the 'baselines' array within the structured document
baselines_list = baselines_doc.get('baselines', [])

token = t.get('tokenConsumed', 'unknown')
completed = t.get('mandateCompleted', False)
agent_type_name = agent_id.split('-')[0] if '-' in agent_id else agent_id

# Check if baseline already exists for this agent type
existing = [b for b in baselines_list if b.get('agentType') == agent_type_name]
if not existing:
    baselines_list.append({
        'agentType': agent_type_name,
        'metric': 'mandate_completion',
        'baselineValue': 1 if completed else 0,
        'recordedAt': timestamp,
        'lastChecked': timestamp,
        'degradationThreshold': 30,
        'runs': [{
            'agentId': agent_id,
            'timestamp': timestamp,
            'completed': completed,
            'tokenConsumed': str(token),
            'exit_reportComplete': True
        }]
    })
else:
    existing[0]['lastChecked'] = timestamp
    existing[0].setdefault('runs', []).append({
        'agentId': agent_id,
        'timestamp': timestamp,
        'completed': completed,
        'tokenConsumed': str(token),
        'exit_reportComplete': True
    })

baselines_doc['baselines'] = baselines_list
with open(baselines_path, 'w', encoding='utf-8') as f:
    json.dump(baselines_doc, f, indent=2)

# --- Trust level computation (Constitution Section XXXII-B) ---
trust_path = os.path.join(project_dir, 'registry', 'trust-registry.json')
try:
    with open(trust_path, encoding='utf-8') as f:
        trust_doc = json.load(f)
except:
    trust_doc = {
        'description': 'Progressive Trust Protocol',
        'externalToolTrust': {'tools': []},
        'internalAgentTrust': {'agentTypes': []}
    }

_trust_types = trust_doc.get('internalAgentTrust', {}).get('agentTypes', [])
_trust_entry = None
for _te in _trust_types:
    if _te.get('agentType') == agent_type_name:
        _trust_entry = _te
        break

if _trust_entry is None:
    _trust_entry = {
        'agentType': agent_type_name,
        'trustLevel': 'untested',
        'completedMandates': 0,
        'totalMandates': 0,
        'constitutionalViolations': 0,
        'degradationFlags': 0,
        'sessions': [],
        'completionRate': 0,
        'lastUpdated': timestamp
    }
    _trust_types.append(_trust_entry)

_trust_entry['totalMandates'] = _trust_entry.get('totalMandates', 0) + 1
if completed:
    _trust_entry['completedMandates'] = _trust_entry.get('completedMandates', 0) + 1

_session_date = timestamp[:10]
if _session_date not in _trust_entry.get('sessions', []):
    _trust_entry.setdefault('sessions', []).append(_session_date)

_total = _trust_entry.get('totalMandates', 0)
_completed = _trust_entry.get('completedMandates', 0)
_trust_entry['completionRate'] = round(_completed / _total, 3) if _total > 0 else 0
_trust_entry['lastUpdated'] = timestamp

# Promotion checks (untested->proven, proven->trusted; trusted->veteran needs Interpreter)
_cur_level = _trust_entry.get('trustLevel', 'untested')
_violations = _trust_entry.get('constitutionalViolations', 0)
_sessions = _trust_entry.get('sessions', [])

if _cur_level == 'untested' and _completed >= 3 and _violations == 0:
    _trust_entry['trustLevel'] = 'proven'
    print(f'TRUST PROMOTION: {agent_type_name} untested -> proven ({_completed} completed mandates)', file=sys.stderr)
elif _cur_level == 'proven' and _completed >= 10 and len(_sessions) >= 2 and _trust_entry['completionRate'] > 0.85 and _violations == 0:
    _trust_entry['trustLevel'] = 'trusted'
    print(f'TRUST PROMOTION: {agent_type_name} proven -> trusted ({_completed} completed, {len(_sessions)} sessions)', file=sys.stderr)

# Demotion check: 2+ incomplete mandates
_incomplete = _total - _completed
if _incomplete >= 2 and _cur_level != 'untested':
    _level_order = ['untested', 'proven', 'trusted', 'veteran']
    _cur_idx = _level_order.index(_cur_level) if _cur_level in _level_order else 0
    if _cur_idx > 0:
        _trust_entry['trustLevel'] = _level_order[_cur_idx - 1]
        print(f'TRUST DEMOTION: {agent_type_name} {_cur_level} -> {_trust_entry["trustLevel"]} ({_incomplete} incomplete mandates)', file=sys.stderr)

trust_doc.setdefault('internalAgentTrust', {})['agentTypes'] = _trust_types
with open(trust_path, 'w', encoding='utf-8') as f:
    json.dump(trust_doc, f, indent=2)
print(f'Trust registry updated: {agent_type_name} (level: {_trust_entry["trustLevel"]})')

# --- Auto Regression Detection (Constitution Section XIX) ---
# Check if current agent's token consumption deviates >30% from baseline.
# Advisory only — writes to hook-errors.log, never blocks.
_err_log = os.path.join(project_dir, 'registry', 'hook-errors.log')
_baseline_entry = [b for b in baselines_list if b.get('agentType') == agent_type_name]
if _baseline_entry and len(_baseline_entry[0].get('runs', [])) >= 2:
    _runs = _baseline_entry[0]['runs']
    # Parse token values, skip non-numeric
    _token_vals = []
    for _r in _runs:
        try:
            _tv = int(str(_r.get('tokenConsumed', '0')).replace(',', ''))
            if _tv > 0: _token_vals.append(_tv)
        except: pass
    if len(_token_vals) >= 2:
        _baseline_avg = sum(_token_vals[:-1]) / len(_token_vals[:-1])
        _current = _token_vals[-1]
        if _baseline_avg > 0:
            _deviation = abs(_current - _baseline_avg) / _baseline_avg * 100
            if _deviation > 30:
                _direction = 'over' if _current > _baseline_avg else 'under'
                _warn_msg = (f'REGRESSION WARNING (Constitution XIX): Agent type '
                    f'{agent_type_name} token consumption {_direction}-deviated '
                    f'{_deviation:.0f}% from baseline (current: {_current}, '
                    f'baseline avg: {_baseline_avg:.0f}). Possible degradation.\\n')
                try:
                    with open(_err_log, 'a', encoding='utf-8') as _ef:
                        _ef.write(_warn_msg)
                except: pass

print(f'Registry files updated: skills.json, baselines.json')

# --- Auto-compliance report (Constitution Section XVI / H1 fix) ---
# Generate a basic compliance report at shutdown so constitution-compliance.json
# is no longer empty. Uses exit_report data to infer compliance signals.
compliance_path = os.path.join(project_dir, 'registry', 'constitution-compliance.json')
try:
    with open(compliance_path, encoding='utf-8') as f:
        compliance_doc = json.load(f)
except:
    compliance_doc = {'description': 'Constitution telemetry', 'reports': []}

checks = {
    'exit_reportWritten': True,  # We're inside the exit_report-exists branch
    'mandateScope': completed,  # mandateCompleted implies stayed in scope
    'tokenWithinBudget': str(token) not in ['gluttonous', 'excessive'],
    'spiritAlignment': bool(t.get('spiritContribution', '')),
}
passed = sum(1 for v in checks.values() if v)
total = len(checks)

compliance_doc.setdefault('reports', []).append({
    'agentId': agent_id,
    'shutdownAt': timestamp,
    'checks': checks,
    'overallCompliance': round(passed / total * 100),
    'notes': f'Auto-generated at shutdown. {passed}/{total} checks passed.'
})
with open(compliance_path, 'w', encoding='utf-8') as f:
    json.dump(compliance_doc, f, indent=2)
print(f'Constitution compliance report written for {agent_id}')

# --- Peak Performance check (Constitution Section XXVIII) ---
# RECOVERY: INFO — advisory via stderr, execution continues
# If mandate completed with substantial whatWorked, prompt for recording
what_worked = t.get('whatWorked', '')
if completed and len(what_worked) > 50:
    preview = what_worked[:100].replace(chr(10), ' ')
    print(f'\\u2b50 PEAK PERFORMANCE CHECK: Agent reported substantial success.', file=sys.stderr)
    print(f'   whatWorked: {preview}', file=sys.stderr)
    print(f'   Constitution XXVIII: If this output was exceptional, record it via:', file=sys.stderr)
    print(f'   Add to registry/quality-benchmarks.json with agentType, mandateType, outputRef, whyExceptional', file=sys.stderr)

# --- Update domains.json members (Constitution Section XXXIV / H3 fix) ---
# Add this agent to its domain's members list and compute domain_leads
if domain_id:
    domains_path = os.path.join(project_dir, 'registry', 'tribes.json')
    try:
        with open(domains_path, encoding='utf-8') as f:
            domains_doc = json.load(f)
        for domain in domains_doc.get('tribes', []):
            if domain['id'] == domain_id:
                members = domain.get('members', [])
                member_entry = {'id': agent_id, 'type': agent_type_name, 'shutdownAt': timestamp}
                members.append(member_entry)
                domain['members'] = members
                # Compute domain_lead: agent type with most entries in this domain
                type_counts = {}
                for m in members:
                    t_name = m.get('type', '')
                    type_counts[t_name] = type_counts.get(t_name, 0) + 1
                if type_counts:
                    domain['domain_lead'] = max(type_counts, key=type_counts.get)
                break
        print(f'Domain-level membership updated: {agent_id} -> {domain_id}')

        # --- Elder computation (Constitution Section XXXIV) ---
        # Elder = agent type with most demonstrated skill entries in skills.json
        # where the skill's tribeId/domainId matches this tribe. This is different
        # from domain_lead (which counts members). Elder counts SKILLS.
        skills_path_elder = os.path.join(project_dir, 'registry', 'skills.json')
        try:
            with open(skills_path_elder, encoding='utf-8') as sf:
                skills_data = json.load(sf)
            skill_type_counts = {}
            for skill in skills_data.get('skills', []):
                skill_tribe = skill.get('tribeId') or skill.get('domainId')
                if skill_tribe == domain_id:
                    at = skill.get('agentType', '')
                    if at:
                        skill_type_counts[at] = skill_type_counts.get(at, 0) + skill.get('mandateCount', 1)
            if skill_type_counts:
                elder_type = max(skill_type_counts, key=skill_type_counts.get)
                domain['elder'] = elder_type
                print(f'Elder computed for {domain_id}: {elder_type} ({skill_type_counts[elder_type]} skill demonstrations)')
            else:
                domain['elder'] = None
        except Exception as elder_err:
            print(f'Elder computation failed: {elder_err}', file=sys.stderr)

        with open(domains_path, 'w', encoding='utf-8') as f:
            json.dump(domains_doc, f, indent=2)

    except Exception as e:
        print(f'Domain-level membership update failed: {e}', file=sys.stderr)
" 2>>"$_ERR_LOG"
  fi

  # --- Spawn request count + User model advisory (merged Python invocation) ---
  # Feature 3: Parallel Shutdown Orchestration (Section VI-D)
  # Previously these were two separate Python invocations (~1s total on Windows).
  # Merged into a single invocation that performs both read-only checks.
  USER_MODEL="$PROJECT_DIR/memory/user-model.json"
  export _CF_USER_MODEL="$USER_MODEL"
  "$PYTHON" -c "
import glob, json, os, sys
from datetime import datetime, timezone, timedelta

agent_id = os.environ.get('_CF_AGENT_ID', '')
project_dir = os.environ.get('_CF_PROJECT_DIR', '')

# --- Spawn request count check (Constitution Section XXXV) ---
# RECOVERY: WARN — spawn request count exceeded, stderr warning
memos_dir = os.path.join(project_dir, 'memory', 'memos')
pattern = os.path.join(memos_dir, f'spawn-request-{agent_id}-*.md')
spawn_req_count = len(glob.glob(pattern))
if spawn_req_count > 2:
    print(f'COMPLIANCE VIOLATION (Section XXXV): Agent \"{agent_id}\" filed {spawn_req_count} spawn requests (limit: 2 per mandate).', file=sys.stderr)

# --- User Model Session Warning (Constitution Section XXVII) ---
# RECOVERY: INFO — advisory via stderr, execution continues
user_model_path = os.environ.get('_CF_USER_MODEL', '')
if user_model_path and os.path.exists(user_model_path):
    try:
        with open(user_model_path, encoding='utf-8') as f:
            um = json.load(f)
        last_updated = um.get('lastUpdated', '')
        if last_updated:
            updated_dt = datetime.fromisoformat(last_updated.replace('Z', '+00:00'))
            age = datetime.now(timezone.utc) - updated_dt
            if age > timedelta(hours=1):
                print('\U0001f4dd USER MODEL ADVISORY: user-model.json not updated this session.', file=sys.stderr)
                print('   Constitution XXVII: The Interpreter should update affinity and interaction history.', file=sys.stderr)
                print('   Consider adding a re-engagement or session entry before ending.', file=sys.stderr)
    except Exception:
        pass
" 2>>"$_ERR_LOG"
fi

exit 0
