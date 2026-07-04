#!/bin/bash
# ============================================================
# SPAWN GATE — PreToolUse Hook (Agent tool only)
# Enforces Constitution agent_registry rules before any agent is spawned.
#
# Checks (Constitution Sections II + XIV + XVI + XVIII + XXI):
#   1. Generation cap — max 4 generations deep (BLOCKS)
#   2. Sibling limit — max 8 children per ANY parent (BLOCKS)
#   3. Complexity Threshold threshold — max active agents (BLOCKS)
#   4. Overlap Detection — overlap detection with active agents (WARNS)
#   5. Memory Retrieval — search handoff for relevant prior wisdom (INFO)
#   6. Binding-active — block spawning during graceful abort (BLOCKS)
#   7. Synthesis validation — verify dual-parent requirements (BLOCKS/WARNS)
#   8. Charter advisory — warn when spawning without a covenant (WARNS)
#
# Exit 2 = block the spawn with a message.
# Exit 0 = allow the spawn to proceed.
#
# ============================================================
# RECOVERY POLICY SUMMARY
# ────────────────────────────────────────────────────────────
# CHECK                          | POLICY   | ACTION
# Python not found               | BLOCK    | exit 2
# Registry not found             | WARN     | log to hook-errors.log, exit 0
# Consolidation active           | BLOCK    | exit 2
# Re-initialization required     | BLOCK    | exit 2
# Binding active (graceful abort)| BLOCK    | exit 2
# Generation cap exceeded        | BLOCK    | exit 2
# Sibling limit exceeded         | BLOCK    | exit 2
# Synthesis invalid              | BLOCK    | exit 2
# Synthesis validated            | WARN     | log to hook-errors.log, exit 0
# Charter advisory               | WARN     | log to hook-errors.log, exit 0
# Complexity threshold reached   | BLOCK    | exit 2
# Tribal complexity threshold    | WARN     | log to hook-errors.log, exit 0
# Cross-domain overlap           | WARN     | log to hook-errors.log, exit 0
# Intra-domain overlap           | INFO     | log to hook-errors.log, exit 0
# Memory retrieval findings      | INFO     | log to hook-errors.log, exit 0
# Telos surfacing                | INFO     | log to hook-errors.log, exit 0
# Auto-registration              | FALLBACK | epoch auto-created if missing, exit 0
# Dual-registration guard        | FALLBACK | skip registration, log, exit 0
# Epoch creation failure         | FALLBACK | fall back to root parent, continue
# Checkpoint advisory            | WARN     | log to hook-errors.log, exit 0
# Pre-flight advisory            | WARN     | log to hook-errors.log, exit 0
# ============================================================

# Detect python — prefer 'python' on Windows (python3 shim causes Permission Denied in Git Bash)
if command -v cygpath >/dev/null 2>&1 || [ -n "$MSYSTEM" ]; then
  PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
else
  PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
fi
# RECOVERY: BLOCK — python required for all checks, exit 2
if [ -z "$PYTHON" ]; then
  echo "🚫 SPAWN GATE: python not found — cannot enforce agent_registry limits." >&2
  exit 2
fi

# Error log — replaces silent 2>/dev/null suppression on Python blocks
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_ERR_LOG="${_HOOK_DIR:+${_HOOK_DIR}/../../registry/hook-errors.log}"
[ -n "$_ERR_LOG" ] && command -v cygpath >/dev/null 2>&1 && _ERR_LOG="$(cygpath -m "$_ERR_LOG")"
_ERR_LOG="${_ERR_LOG:-/dev/null}"

INPUT=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)}"
# Convert Git Bash /c/ path to C:/ for Python compatibility on Windows
command -v cygpath >/dev/null 2>&1 && PROJECT_DIR="$(cygpath -m "$PROJECT_DIR")"
GENEALOGY="$PROJECT_DIR/registry/agent-registry.json"
TRIBES_JSON="$PROJECT_DIR/registry/tribes.json"

# RECOVERY: WARN — no registry found, agent spawns unregistered, log warning
if [ ! -f "$GENEALOGY" ]; then
  echo "⚠️  SPAWN GATE: No agent-registry.json found. Agent will spawn unregistered." >>"$_ERR_LOG"
  echo "   Run /reconcile after to bring this agent into compliance." >>"$_ERR_LOG"
  exit 0
fi

# Export paths as env vars so Python reads them safely (no backslash escaping)
export _CF_GENEALOGY="$GENEALOGY"
export _CF_PROJECT_DIR="$PROJECT_DIR"
export _CF_TRIBES_JSON="$TRIBES_JSON"

RESULT=$( printf '%s' "$INPUT" | "$PYTHON" -c "
import sys, json, os, glob

input_data = json.load(sys.stdin)
tool_name = input_data.get('tool_name', '')

# Only gate Agent tool calls
if tool_name != 'Agent':
    print('PASS:NOT_AGENT')
    sys.exit(0)

tool_input = input_data.get('tool_input', {})
prompt = ''
description = ''
if isinstance(tool_input, dict):
    prompt = tool_input.get('prompt', '')
    description = tool_input.get('description', '')

# Read agent_registry — paths from env vars to avoid Windows backslash issues
agent_registry_path = os.environ.get('_CF_GENEALOGY', '')
project_dir = os.environ.get('_CF_PROJECT_DIR', '')
try:
    with open(agent_registry_path, encoding='utf-8') as f:
        registry = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    print('PASS:NO_REGISTRY')
    sys.exit(0)

canon = registry.get('canon', {})
max_generations = canon.get('maxGenerations', 4)
max_siblings = canon.get('maxSiblings', 8)
complexity_threshold_threshold = canon.get('babelThreshold', 6)

# --- Consolidation pause check (Constitution Section V) ---
# RECOVERY: BLOCK — spawn rejected during consolidation, exit 2
if registry.get('consolidationActive', False):
    print('BLOCK:CONSOLIDATION')
    sys.exit(0)

# --- Re-initialization check (Constitution Section XXII) ---
# RECOVERY: BLOCK — spawn rejected until /reinit completes, exit 2
reinit_flag = os.path.join(project_dir, 'registry', 'reinit-required.flag')
if os.path.exists(reinit_flag):
    print('BLOCK:REINIT_REQUIRED')
    sys.exit(0)

# --- Binding-active check (Constitution Section XXI — Graceful Abort) ---
# RECOVERY: BLOCK — spawn rejected during graceful abort, exit 2
binding_flag = os.path.join(project_dir, 'registry', 'binding-active.flag')
if os.path.exists(binding_flag):
    print('BLOCK:BINDING_ACTIVE')
    sys.exit(0)

agents = registry.get('agents', [])
active_agents = [a for a in agents if a.get('status') == 'active']
# Build parent->active-children map. Historical overgrowth is allowed to remain
# in the registry, but active sibling overflow blocks new spawns.
children_by_parent = {}
for a in active_agents:
    pid = a.get('parentId')
    if pid:
        children_by_parent.setdefault(pid, []).append(a)

# --- Generation cap check (Constitution Section II) ---
# RECOVERY: BLOCK — spawn rejected if new agent would exceed generation cap, exit 2
# Find the maximum generation among active agents.
# A new child would be max_gen + 1. If that exceeds the cap, block.
max_active_gen = 0
for a in active_agents:
    gen = a.get('generation', 0)
    if gen > max_active_gen:
        max_active_gen = gen
# The spawning agent is likely at max_active_gen (conservative).
# Its child would be max_active_gen + 1.
if max_active_gen >= max_generations:
    print(f'BLOCK:GENERATION:{max_active_gen}:{max_generations}')
    sys.exit(0)

# --- Sibling limit check for SPAWNING parent only (Constitution Section II) ---
# RECOVERY: BLOCK — spawn rejected if parent has too many active children, exit 2
# Determine which parent the new agent will be registered under.
# The auto_register function defaults to 'root' unless PARENT_ID is in the prompt.
import re as _re
spawn_parent = 'root'
_parent_match = _re.search(r'PARENT_ID:\s*(\S+)', prompt)
if _parent_match:
    _candidate = _parent_match.group(1)
    if any(a.get('id') == _candidate for a in agents):
        spawn_parent = _candidate
spawn_parent_children = children_by_parent.get(spawn_parent, [])
if len(spawn_parent_children) >= max_siblings:
    print(f'BLOCK:SIBLING:{spawn_parent}:{len(spawn_parent_children)}:{max_siblings}')
    sys.exit(0)

# --- Synthesis validation (Constitution Section XIV) ---
# RECOVERY: BLOCK — synthesis rejected if parents invalid/missing, exit 2
# RECOVERY: WARN — synthesis validated, logged to hook-errors.log, continues
if _re.search(r'SYNTHESIZE:|parentIds:', prompt):
    # Extract parent IDs from prompt
    _synth_parents = []
    _pid_match = _re.search(r'parentIds?:\s*\[?\s*([^\]\n]+)\]?', prompt)
    if _pid_match:
        _raw = _pid_match.group(1)
        _synth_parents = [p.strip().strip('\"').strip(\"'\").strip(',') for p in _raw.split(',') if p.strip().strip('\"').strip(\"'\").strip(',')]
    if len(_synth_parents) < 2:
        print('BLOCK:SYNTHESIS_INVALID:Two parent agent IDs required for synthesis')
        sys.exit(0)
    # Both parents must exist and be archived
    for _sp in _synth_parents[:2]:
        _sp_agent = [a for a in agents if a.get('id') == _sp]
        if not _sp_agent:
            print(f'BLOCK:SYNTHESIS_INVALID:Parent agent {_sp} not found in registry')
            sys.exit(0)
        if _sp_agent[0].get('status') != 'archived':
            print(f'BLOCK:SYNTHESIS_INVALID:Parent agent {_sp} must be archived (status: {_sp_agent[0].get("status","unknown")})')
            sys.exit(0)
    # Both parents must have exit reports
    handoff_base = os.path.join(project_dir, 'memory', 'handoff')
    for _sp in _synth_parents[:2]:
        _exit_patterns = [
            os.path.join(handoff_base, f'{_sp}-exit_report.json'),
            os.path.join(handoff_base, f'{_sp}-exit_report.md'),
            os.path.join(handoff_base, f'{_sp}.md'),
        ]
        if not any(os.path.exists(p) for p in _exit_patterns):
            print(f'BLOCK:SYNTHESIS_INVALID:No exit report found for parent {_sp}')
            sys.exit(0)
    print('WARN:SYNTHESIS:validated')
    sys.exit(0)

# --- Charter Advisory (Constitution Section XVIII) ---
# RECOVERY: WARN — advisory logged to hook-errors.log, spawn continues
# Warn when many agents spawn without a covenant defining success criteria.
import datetime as _dt
_covenants_dir = os.path.join(project_dir, 'memory', 'covenants')
_has_covenant = os.path.isdir(_covenants_dir) and any(
    f.endswith('.md') or f.endswith('.json')
    for f in os.listdir(_covenants_dir)
    if os.path.isfile(os.path.join(_covenants_dir, f))
) if os.path.isdir(_covenants_dir) else False
if not _has_covenant:
    _now_utc = _dt.datetime.now(_dt.timezone.utc)
    _cutoff = _now_utc - _dt.timedelta(minutes=10)
    _recent_spawns = 0
    for a in agents:
        _born = a.get('bornAt', '')
        if _born:
            try:
                _born_dt = _dt.datetime.fromisoformat(_born.replace('Z', '+00:00'))
                if _born_dt >= _cutoff:
                    _recent_spawns += 1
            except:
                pass
    if _recent_spawns > 3:
        print(f'WARN:NO_CHARTER:{_recent_spawns}')
        sys.exit(0)

# --- Complexity Threshold threshold check (Constitution Section XVI) — now BLOCKS ---
# RECOVERY: BLOCK — spawn rejected if active agents exceed threshold, exit 2
if len(active_agents) >= complexity_threshold_threshold:
    print(f'BLOCK:COMPLEXITY:{len(active_agents)}:{complexity_threshold_threshold}')
    sys.exit(0)

# --- Domain-level Complexity Threshold threshold check (Constitution Section XXXIV) — WARNS ---
# RECOVERY: WARN — advisory logged to hook-errors.log, spawn continues
domains_path = os.environ.get('_CF_TRIBES_JSON', '')
domains_data = None
if os.path.exists(domains_path):
    try:
        with open(domains_path, encoding='utf-8') as f:
            domains_data = json.load(f)
    except:
        pass

# Resolve domainId for the new agent: explicit TRIBE_ID > territory auto-inference
_domain_id = None
_domain_match = _re.search(r'TRIBE_ID:\s*(\S+)', prompt)
if _domain_match:
    _domain_id = _domain_match.group(1)

# Build search_text early — needed by territory auto-inference and later sections
search_text = (prompt + ' ' + description).lower()

# Territory auto-inference if no explicit TRIBE_ID
if not _domain_id and domains_data:
    import fnmatch as _fnmatch
    for domain in domains_data.get('tribes', []):
        for pat in domain.get('territory', {}).get('filePaths', []):
            if any(_fnmatch.fnmatch(w, pat) or _fnmatch.fnmatch(w.replace('\\\\', '/'), pat)
                   for w in search_text.split()):
                _domain_id = domain['id']
                break
        if _domain_id:
            break

if _domain_id and domains_data:
    domain_level_complexity_threshold = domains_data.get('tribalComplexityThreshold',
                   canon.get('tribalComplexityThreshold', 6))
    domain_level_active = [a for a in active_agents if a.get('domainId') == _domain_id]
    if len(domain_level_active) >= domain_level_complexity_threshold:
        print(f'WARN:TRIBAL_BABEL:{_domain_id}:{len(domain_level_active)}:{domain_level_complexity_threshold}')
        sys.exit(0)

# --- Overlap Detection overlap check (Constitution Sections XVI + XXXIV) ---
# RECOVERY: WARN — cross-domain overlap logged to hook-errors.log, spawn continues
# RECOVERY: INFO — intra-domain overlap logged to hook-errors.log, spawn continues
if prompt or description:
    search_text = (prompt + ' ' + description).lower()
    common = {'the','a','an','to','for','and','of','in','on','with','is','it','this','that',
              'be','do','use','run','make','get','set','check','read','write','file','code',
              'should','would','could','need','want','please','agent','task'}
    for agent in active_agents:
        mandate = agent.get('mandate', '').lower()
        if not mandate:
            continue
        mandate_words = set(mandate.split()) - common
        search_words = set(search_text.split()) - common
        overlap = mandate_words & search_words
        if len(overlap) >= 3:
            # Domain-level awareness: same domain = expected collaboration (INFO)
            # Cross-domain or unaffiliated = real overlap signal (WARN)
            other_domain = agent.get('domainId')
            if _domain_id and other_domain and _domain_id == other_domain:
                print(f'INFO:TRIBAL_OVERLAP:{agent[\"id\"]}:{_domain_id}:{agent[\"mandate\"][:60]}')
            else:
                print(f'WARN:OVERLAP:{agent[\"id\"]}:{agent[\"mandate\"][:60]}')
            sys.exit(0)

# --- Memory Retrieval phase (Constitution Section XVI) — search handoff ---
# RECOVERY: INFO — findings logged to hook-errors.log, spawn continues

# === XVI-E: Named Search Modes ===
# Detect REMEMBER_MODE from prompt, fall back to tokensExpected-based auto-selection.
import time as _time
_remember_mode = None
_mode_match = _re.search(r'REMEMBER_MODE:\s*(fast|balanced|deep)', prompt)
if _mode_match:
    _remember_mode = _mode_match.group(1)
else:
    # Auto-select based on tokensExpected
    _te_match = _re.search(r'tokensExpected[:\s]+[^a-z]?(low|medium|high)[^a-z]?', prompt, _re.IGNORECASE)
    _te_val = _te_match.group(1).lower() if _te_match else 'medium'
    _mode_map = {'low': 'fast', 'medium': 'balanced', 'high': 'deep'}
    _remember_mode = _mode_map.get(_te_val, 'balanced')

# Configure mode parameters
_mode_params = {
    'fast':     {'max_results': 3, 'content_limit': 500,  'dirs': ['handoff']},
    'balanced': {'max_results': 5, 'content_limit': 1500, 'dirs': ['handoff', 'domains']},
    'deep':     {'max_results': 10, 'content_limit': 3000, 'dirs': ['handoff', 'domains', 'semantic', 'inheritance']},
}
_params = _mode_params[_remember_mode]
REMEMBER_MAX_RESULTS = _params['max_results']
REMEMBER_CONTENT_LIMIT = _params['content_limit']

# Build search directory list based on mode
_search_dirs = []
handoff_dir = os.path.join(project_dir, 'memory', 'handoff')
semantic_dir = os.path.join(project_dir, 'memory', 'semantic')
inheritance_dir = os.path.join(project_dir, 'memory', 'inheritance')
domains_base = os.path.join(project_dir, 'memory', 'domains')

if 'handoff' in _params['dirs']:
    _search_dirs.append(handoff_dir)
if 'domains' in _params['dirs'] and os.path.isdir(domains_base):
    for _dname in os.listdir(domains_base):
        _dpath = os.path.join(domains_base, _dname)
        if os.path.isdir(_dpath):
            _search_dirs.append(_dpath)
if 'semantic' in _params['dirs']:
    _search_dirs.append(semantic_dir)
if 'inheritance' in _params['dirs']:
    _search_dirs.append(inheritance_dir)
# === End XVI-E mode setup ===

search_text = (prompt + ' ' + description).lower()
search_words = set(search_text.split()) - {'the','a','an','to','for','and','of','in','on','with'}

# === XVI-D: Compiled-Truth Boost ===
# Weighted scoring: compiled truth (2.0x), raw findings (1.0x), stale content (0.5x)
_now_epoch = _time.time()
_stale_threshold = 30 * 86400  # 30 days in seconds

def _compute_weight(fpath):
    """Determine weight category for a file based on location and freshness."""
    fname = os.path.basename(fpath)

    # Check for compiled truth: domain memory files and fresh exit reports
    if fname in ('domain_memory.md', 'patterns.md'):
        return 2.0, 'compiled'

    # Exit reports in inheritance — check freshness score
    if fname.endswith('-exit_report.json') or fname.endswith('-exit report.json'):
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as _ef:
                _edata = json.loads(_ef.read(4000))
            _fs = _edata.get('freshnessScore', {})
            _base = _fs.get('baseScore', 0.5)
            if _base >= 0.5:
                return 2.0, 'compiled'
            elif _base < 0.3:
                return 0.5, 'stale'
            else:
                return 1.0, 'raw'
        except:
            return 1.0, 'raw'

    # Check file age for staleness
    try:
        _mtime = os.path.getmtime(fpath)
        if (_now_epoch - _mtime) > _stale_threshold:
            return 0.5, 'stale'
    except:
        pass

    # Default: raw findings (handoff, incomplete exit reports, etc.)
    return 1.0, 'raw'
# === End XVI-D weight function ===

# Scored retrieval: (weighted_score, weight_category, filename)
_scored_findings = []
for search_dir in _search_dirs:
    if not os.path.isdir(search_dir):
        continue
    for fpath in glob.glob(os.path.join(search_dir, '*')):
        if not os.path.isfile(fpath):
            continue
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as fh:
                content = fh.read(REMEMBER_CONTENT_LIMIT).lower()
            # In fast mode, only check filename + first 500 chars
            if _remember_mode == 'fast':
                content = (os.path.basename(fpath).lower() + ' ' + content[:500])
            content_words = set(content.split())
            match = search_words & content_words
            if len(match) >= 3:
                _weight, _category = _compute_weight(fpath)
                _weighted_score = len(match) * _weight
                _scored_findings.append((_weighted_score, _category, os.path.basename(fpath)))
        except Exception:
            pass

# Sort by weighted score descending, take top N per mode
_scored_findings.sort(key=lambda x: -x[0])
_scored_findings = _scored_findings[:REMEMBER_MAX_RESULTS]

memory_retrieval_findings = [f[2] for f in _scored_findings]

if memory_retrieval_findings:
    # Include weight categories in output for agent awareness
    _categorized = [f'{f[2]}[{f[1]}]' for f in _scored_findings]
    findings_str = ','.join(_categorized)
    print(f'INFO:MEMORY_RETRIEVAL:{_remember_mode}:{findings_str}')
    sys.exit(0)

# --- Telos surfacing (Constitution Section XI) ---
# RECOVERY: INFO — telos logged to hook-errors.log, spawn continues
telos = registry.get('revelation', {}).get('telos', '')
if telos:
    print(f'INFO:TELOS:{telos[:120]}')
    sys.exit(0)

print('PASS:CLEAR')
" 2>>"$_ERR_LOG" )

# --- Auto-register the agent in agent_registry.json (P2 fix) ---
# RECOVERY: FALLBACK — if registration fails, agent spawns unregistered
# Even if spawned via raw Agent tool (bypassing /spawn), the agent
# gets registered. This closes the gap where agents acted unregistered.
auto_register() {
  local RESULT_CODE="$1"
  # Only register on PASS, WARN, or INFO — not BLOCK
  case "$RESULT_CODE" in
    BLOCK:*) return ;;
  esac

  printf '%s' "$INPUT" | "$PYTHON" -c "
import sys, json, os, glob
from datetime import datetime, timezone

input_data = json.load(sys.stdin)
tool_input = input_data.get('tool_input', {})
if not isinstance(tool_input, dict):
    sys.exit(0)

prompt = tool_input.get('prompt', '')
description = tool_input.get('description', '')
subagent_type = tool_input.get('subagent_type', 'general-purpose')

agent_registry_path = os.environ.get('_CF_GENEALOGY', '')
project_dir = os.environ.get('_CF_PROJECT_DIR', '')
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

try:
    with open(agent_registry_path, encoding='utf-8') as f:
        registry = json.load(f)
except:
    sys.exit(0)

agents = registry.get('agents', [])

# --- Dual-registration guard (Constitution Section II) ---
# RECOVERY: FALLBACK — skip registration if duplicate detected, log warning
# If the Interpreter pre-registered this agent with a human-readable ID,
# an active agent with the same (or very similar) mandate already exists.
# Skip auto-registration to avoid creating an orphan duplicate.
_mandate_text = (description or prompt[:80] or 'unspecified').strip()
_active_agents = [a for a in agents if a.get('status') == 'active']
for _existing in _active_agents:
    _existing_mandate = _existing.get('mandate', '')
    # Match if mandates are identical or one contains the other
    if (_existing_mandate and _mandate_text and (
        _existing_mandate.lower() == _mandate_text.lower()
        or _existing_mandate.lower() in _mandate_text.lower()
        or _mandate_text.lower() in _existing_mandate.lower()
    )):
        # Also check it was registered recently (within last 120s) to avoid false positives
        _existing_born = _existing.get('bornAt', '')
        _skip = False
        if _existing_born:
            try:
                _born_dt = datetime.fromisoformat(_existing_born.replace('Z', '+00:00'))
                _now_dt = datetime.fromisoformat(now.replace('Z', '+00:00'))
                if abs((_now_dt - _born_dt).total_seconds()) < 120:
                    _skip = True
            except:
                _skip = True
        else:
            _skip = True
        if _skip:
            _err_log = os.path.join(project_dir, 'registry', 'hook-errors.log')
            try:
                with open(_err_log, 'a') as _lf:
                    _lf.write(f'SPAWN GATE: Skipping auto-registration -- agent already registered as {_existing[\"id\"]} (mandate match: \"{_existing_mandate[:60]}\")\\n')
            except: pass
            sys.exit(0)

# Generate a unique agent ID from timestamp + type
agent_id = f'{subagent_type}-{now.replace(\":\",\"\").replace(\"-\",\"\")[:15]}'

# Determine parent — parse PARENT_ID from prompt if Interpreter included it.
# The Interpreter should include 'PARENT_ID: <id>' in spawn prompts to enable
# correct agent_registry registration. Falls back to 'root' if not found.
import re
parent_id = 'root'
parent_gen = 0
if prompt:
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

    # --- Epoch container auto-routing (Constitution Section II) ---
    # RECOVERY: FALLBACK — if epoch creation fails, fall back to root parent
    # Agents must not spawn directly under root. Find or create a session
    # epoch container to serve as parent. This enforces the epoch-containers-only
    # policy and keeps root's active children within the 8-sibling limit.
    today = now[:10]  # 'YYYY-MM-DD'
    active_epochs = [a for a in active_agents
                     if a.get('parentId') == 'root'
                     and a.get('id', '').startswith('epoch-')
                     and a.get('bornAt', '')[:10] == today]
    if active_epochs:
        # Use the most recently created epoch container from today
        active_epochs.sort(key=lambda a: a.get('bornAt', ''), reverse=True)
        epoch = active_epochs[0]
        parent_id = epoch['id']
        parent_gen = epoch.get('generation', 1)
    else:
        # Create a new epoch container for this session
        try:
            import fcntl
        except ImportError:
            fcntl = None  # Windows — proceed without file locking
        epoch_id = f'epoch-auto-{today}'
        epoch_entry = {
            'id': epoch_id,
            'parentId': 'root',
            'mandate': f'Epoch parent \u2014 auto-created session container {today}',
            'generation': 1,
            'origin': 'mandate',
            'bornAt': now,
            'status': 'active',
            'skills': [],
            'tokensExpected': 'low',
            'spawnedVia': 'agent-gate-auto-epoch'
        }
        # Lock the registry file to prevent parallel epoch creation
        try:
            with open(agent_registry_path, 'r+', encoding='utf-8') as rf:
                if fcntl:
                    try:
                        fcntl.flock(rf, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    except (IOError, OSError):
                        pass
                reg_data = json.load(rf)
                reg_agents = reg_data.get('agents', [])
                # Double-check: another parallel spawn may have created the epoch
                existing_epoch = [a for a in reg_agents
                                  if a.get('id') == epoch_id and a.get('status') == 'active']
                if existing_epoch:
                    parent_id = epoch_id
                    parent_gen = existing_epoch[0].get('generation', 1)
                else:
                    reg_agents.append(epoch_entry)
                    reg_data['agents'] = reg_agents
                    rf.seek(0)
                    rf.truncate()
                    json.dump(reg_data, rf, indent=2, ensure_ascii=False)
                    parent_id = epoch_id
                    parent_gen = 1
                if fcntl:
                    try:
                        fcntl.flock(rf, fcntl.LOCK_UN)
                    except (IOError, OSError):
                        pass
        except Exception as e:
            # If epoch creation fails, fall back to root (don't block the spawn)
            _err_log = os.path.join(project_dir, 'registry', 'hook-errors.log')
            try:
                with open(_err_log, 'a') as _lf:
                    _lf.write(f'EPOCH AUTO-CREATE FAILED: {e}. Falling back to root.\\n')
            except: pass
            parent_id = 'root'
            parent_gen = 0

    # If epoch was created or found, re-read registry so subsequent writes
    # include the epoch entry (prevents overwrite on agent registration).
    if parent_id != 'root':
        try:
            with open(agent_registry_path, encoding='utf-8') as _rf:
                registry = json.load(_rf)
            agents = registry.get('agents', [])
        except:
            pass

# --- Domain-level assignment (Constitution Section XXXIV) ---
# 1. Explicit TRIBE_ID from prompt overrides auto-inference
# 2. Territory glob matching as safety net
domain_id = None
domain_match = re.search(r'TRIBE_ID:\s*(\S+)', prompt)
if domain_match:
    domain_id = domain_match.group(1)

domains_path = os.environ.get('_CF_TRIBES_JSON', '')
domains_data = None
if os.path.exists(domains_path):
    try:
        with open(domains_path, encoding='utf-8') as f:
            domains_data = json.load(f)
    except: pass

# Territory auto-inference if no explicit TRIBE_ID
if not domain_id and domains_data:
    import fnmatch
    search_text = (prompt + ' ' + description).lower()
    for domain in domains_data.get('tribes', []):
        for pat in domain.get('territory', {}).get('filePaths', []):
            if any(fnmatch.fnmatch(w, pat) or fnmatch.fnmatch(w.replace('\\\\', '/'), pat)
                   for w in search_text.split()):
                domain_id = domain['id']
                break
        if domain_id:
            break

# Validate domain_id exists in domains.json
if domain_id and domains_data:
    valid_ids = [t['id'] for t in domains_data.get('tribes', [])]
    if domain_id not in valid_ids:
        domain_id = None

# --- Intent construction (Constitution Section II + XXXIV) ---
# Build a scoped intent string that declares the agent's operational boundaries.
_mandate_text_for_intent = (description or prompt[:80] or 'unspecified').strip()
if domain_id and domains_data:
    _tribe_entry = next((t for t in domains_data.get('tribes', []) if t.get('id') == domain_id), None)
    if _tribe_entry:
        _territory_globs = _tribe_entry.get('territory', {}).get('filePaths', [])
        _territory_str = ', '.join(_territory_globs) if _territory_globs else 'no territory defined'
        intent_string = f'{_mandate_text_for_intent}. Scope: {domain_id} tribe territory ({_territory_str}). Must not modify files outside tribe territory.'
    else:
        intent_string = f'{_mandate_text_for_intent}. No tribe assignment — scope unconstrained.'
else:
    intent_string = f'{_mandate_text_for_intent}. No tribe assignment — scope unconstrained.'

# --- Embassy parsing (Constitution Section XXXIV / XXXVI) ---
# Parse EMBASSIES: tribe1,tribe2 from spawn prompt for cross-domain access
_embassies = []
_embassy_match = re.search(r'EMBASSIES:\s*([^\n]+)', prompt)
if _embassy_match:
    _raw_embassies = [e.strip() for e in _embassy_match.group(1).split(',') if e.strip()]
    # Validate embassy tribe IDs exist in tribes.json (max 2 per Constitution XXXIV)
    if domains_data:
        _valid_tribe_ids = [t['id'] for t in domains_data.get('tribes', [])]
        _embassies = [e for e in _raw_embassies if e in _valid_tribe_ids][:2]
    else:
        _embassies = _raw_embassies[:2]

new_agent = {
    'id': agent_id,
    'parentId': parent_id,
    'mandate': _mandate_text_for_intent,
    'generation': parent_gen + 1,
    'origin': 'mandate',
    'bornAt': now,
    'status': 'active',
    'skills': [],
    'tokensExpected': 'medium',
    'spawnedVia': 'agent-gate-auto',
    'domainId': domain_id,
    'embassies': _embassies,
    'intent': intent_string
}

# --- Trust-gated tokensExpected cap (Constitution Section XXXII-B) ---
_trust_override = 'INTERPRETER_TRUST_OVERRIDE' in prompt
_trust_path = os.path.join(project_dir, 'registry', 'trust-registry.json')
_trust_level = 'untested'
try:
    with open(_trust_path, encoding='utf-8') as _tf:
        _trust_doc = json.load(_tf)
    _agent_type_for_trust = agent_id.split('-')[0] if '-' in agent_id else agent_id
    for _at in _trust_doc.get('internalAgentTrust', {}).get('agentTypes', []):
        if _at.get('agentType') == _agent_type_for_trust:
            _trust_level = _at.get('trustLevel', 'untested')
            break
except:
    pass

if _trust_override:
    _err_log = os.path.join(project_dir, 'registry', 'hook-errors.log')
    try:
        with open(_err_log, 'a') as _lf:
            _lf.write(f'TRUST OVERRIDE: Interpreter override for {agent_id} (trust level: {_trust_level}). tokensExpected cap skipped.\n')
    except: pass
else:
    _trust_caps = {'untested': 'low', 'proven': 'medium', 'trusted': 'high', 'veteran': 'high'}
    _cap = _trust_caps.get(_trust_level, 'low')
    _token_rank = {'low': 0, 'medium': 1, 'high': 2}
    if _token_rank.get(new_agent['tokensExpected'], 1) > _token_rank.get(_cap, 0):
        new_agent['tokensExpected'] = _cap

# --- Schema validation (Constitution II + Faby-inspired contracts) ---
# RECOVERY: WARN — schema validation is advisory, never blocks registration
_schema_path = os.path.join(project_dir, 'registry', 'schemas', 'agent-entry.schema.json')
if os.path.exists(_schema_path):
    try:
        import jsonschema as _js
        with open(_schema_path, encoding='utf-8') as _sf:
            _schema = json.load(_sf)
        _js.validate(new_agent, _schema)
    except Exception as _ve:
        print(f'SCHEMA WARNING: Agent entry validation failed: {_ve}', file=sys.stderr)

agents.append(new_agent)
registry['agents'] = agents

# NOTE: Agents spawned via Claude Code's Agent tool do NOT trigger SubagentStop hooks.
# The Interpreter must manually archive these agents and persist their exit_reports.
# /spawn-spawned agents trigger SubagentStop automatically.

import tempfile
tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(agent_registry_path), suffix='.tmp')
try:
    with os.fdopen(tmp_fd, 'w', encoding='utf-8') as f:
        json.dump(registry, f, indent=2)
    # Atomic rename (best-effort on Windows)
    if os.name == 'nt':
        import shutil
        shutil.move(tmp_path, agent_registry_path)
    else:
        os.replace(tmp_path, agent_registry_path)
except:
    try: os.unlink(tmp_path)
    except: pass
    raise

# --- Write genesis briefing (P3 fix) ---
# Pre-compile the Spirit, active agents, and Memory Retrieval findings into a single
# file the agent can read in one shot instead of needing to discover and
# read multiple files. This makes Genesis Phase cheap and reliable.
briefing_path = os.path.join(project_dir, 'registry', 'genesis-briefing.json')
briefing = {'agentId': agent_id, 'generatedAt': now}

# Spirit snapshot
spirit_path = os.path.join(project_dir, 'registry', 'orientation.json')
if os.path.exists(spirit_path):
    try:
        with open(spirit_path, encoding='utf-8') as f:
            briefing['spirit'] = json.load(f)
    except: pass

# Active siblings/peers
active_agents = [a for a in agents if a.get('status') == 'active']
briefing['activeAgents'] = [
    {'id': a['id'], 'mandate': a.get('mandate','')[:80], 'generation': a.get('generation',0)}
    for a in active_agents[:8]
]

# Memory Retrieval findings — XVI-D weighted + XVI-E mode-aware
# === XVI-E: Briefing Search Mode ===
# Re-derive mode for briefing (same logic as gate check above)
_b_remember_mode = None
_b_mode_match = re.search(r'REMEMBER_MODE:\s*(fast|balanced|deep)', prompt)
if _b_mode_match:
    _b_remember_mode = _b_mode_match.group(1)
else:
    _b_te_match = re.search(r'tokensExpected[:\s]+[^a-z]?(low|medium|high)[^a-z]?', prompt, re.IGNORECASE)
    _b_te_val = _b_te_match.group(1).lower() if _b_te_match else 'medium'
    _b_mode_map = {'low': 'fast', 'medium': 'balanced', 'high': 'deep'}
    _b_remember_mode = _b_mode_map.get(_b_te_val, 'balanced')

_b_mode_params = {
    'fast':     {'max_results': 3, 'content_limit': 500,  'dirs': ['handoff']},
    'balanced': {'max_results': 5, 'content_limit': 1500, 'dirs': ['handoff', 'domains']},
    'deep':     {'max_results': 10, 'content_limit': 3000, 'dirs': ['handoff', 'domains', 'semantic', 'inheritance']},
}
_b_params = _b_mode_params[_b_remember_mode]
_B_MAX = _b_params['max_results']
_B_LIMIT = _b_params['content_limit']

# Build briefing search dirs based on mode
_b_search_dirs = []
_b_handoff = os.path.join(project_dir, 'memory', 'handoff')
_b_semantic = os.path.join(project_dir, 'memory', 'semantic')
_b_inheritance = os.path.join(project_dir, 'memory', 'inheritance')
_b_domains_base = os.path.join(project_dir, 'memory', 'domains')

if 'handoff' in _b_params['dirs']:
    _b_search_dirs.append(_b_handoff)
if 'domains' in _b_params['dirs'] and os.path.isdir(_b_domains_base):
    for _dn in os.listdir(_b_domains_base):
        _dp = os.path.join(_b_domains_base, _dn)
        if os.path.isdir(_dp):
            _b_search_dirs.append(_dp)
if 'semantic' in _b_params['dirs']:
    _b_search_dirs.append(_b_semantic)
if 'inheritance' in _b_params['dirs']:
    _b_search_dirs.append(_b_inheritance)
# === End XVI-E briefing mode setup ===

import time as _b_time
_b_now_epoch = _b_time.time()
_b_stale_threshold = 30 * 86400

# === XVI-D: Compiled-Truth Boost for briefing ===
def _b_compute_weight(fpath):
    fname = os.path.basename(fpath)
    if fname in ('domain_memory.md', 'patterns.md'):
        return 2.0, 'compiled'
    if fname.endswith('-exit_report.json') or fname.endswith('-exit report.json'):
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as _ef:
                _edata = json.loads(_ef.read(4000))
            _fs = _edata.get('freshnessScore', {})
            _base = _fs.get('baseScore', 0.5)
            if _base >= 0.5:
                return 2.0, 'compiled'
            elif _base < 0.3:
                return 0.5, 'stale'
            else:
                return 1.0, 'raw'
        except:
            return 1.0, 'raw'
    try:
        _mtime = os.path.getmtime(fpath)
        if (_b_now_epoch - _mtime) > _b_stale_threshold:
            return 0.5, 'stale'
    except:
        pass
    return 1.0, 'raw'

retrieval_files = []
_b_scored = []
search_words = set((prompt + ' ' + description).lower().split()) - {'the','a','an','to','for','and','of','in','on','with'}
for _b_dir in _b_search_dirs:
    if not os.path.isdir(_b_dir): continue
    for fpath in glob.glob(os.path.join(_b_dir, '*')):
        if not os.path.isfile(fpath): continue
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as fh:
                content = fh.read(_B_LIMIT).lower()
            if _b_remember_mode == 'fast':
                content = (os.path.basename(fpath).lower() + ' ' + content[:500])
            if len(search_words & set(content.split())) >= 3:
                _w, _c = _b_compute_weight(fpath)
                _ws = len(search_words & set(content.split())) * _w
                _b_scored.append((_ws, _c, os.path.basename(fpath)))
        except: pass
_b_scored.sort(key=lambda x: -x[0])
_b_scored = _b_scored[:_B_MAX]
retrieval_files = [f[2] for f in _b_scored]
briefing['memoryRetrievalFindings'] = retrieval_files
briefing['memoryRetrievalMode'] = _b_remember_mode
if _b_scored:
    briefing['memoryRetrievalWeights'] = {f[2]: f[1] for f in _b_scored}
# === End XVI-D briefing boost ===

# Domain-level context (Constitution Section XXXIV)
if domain_id:
    briefing['domainId'] = domain_id
    domain_level_dir = os.path.join(project_dir, 'memory', 'domain_level', domain_id)
    domain_level_context = {}
    for fname in ['domain_memory.md', 'patterns.md', 'warnings.md']:
        fpath = os.path.join(domain_level_dir, fname)
        if os.path.exists(fpath):
            try:
                with open(fpath, 'r', encoding='utf-8', errors='replace') as fh:
                    content = fh.read(1500)
                # Only include if there is actual content (not just placeholder)
                if content.strip() and 'No entries yet' not in content and 'No patterns recorded' not in content and 'No warnings recorded' not in content:
                    domain_level_context[fname.replace('.md', '')] = content
            except: pass
    if domain_level_context:
        briefing['tribalStorehouse'] = domain_level_context
    # Include domain_level memos
    domain_level_memos = []
    if os.path.isdir(os.path.join(project_dir, 'memory', 'memos')):
        for fpath in glob.glob(os.path.join(project_dir, 'memory', 'memos', f'tribal-{domain_id}-*.md')):
            try:
                with open(fpath, 'r', encoding='utf-8', errors='replace') as fh:
                    header = fh.read(500)
                if 'read: false' in header:
                    domain_level_memos.append(os.path.basename(fpath))
            except: pass
    if domain_level_memos:
        briefing['tribalMemos'] = domain_level_memos[:5]

# Unread memos (with recipient filtering per Constitution Section XII)
memos_dir = os.path.join(project_dir, 'memory', 'memos')
unread = []
# Derive agent type from agent_id (strip timestamp suffix: "analyst-20260608T133708" -> "analyst")
_agent_type = '-'.join(agent_id.split('-')[:-1]) if '-' in agent_id else agent_id
# Get tribe_id from registry entry if available
_agent_tribe = ''
for _a in registry.get('agents', []):
    if _a.get('id') == agent_id:
        _agent_tribe = _a.get('tribeId', '')
        break
_valid_recipients = {'any', _agent_type}
if _agent_tribe:
    _valid_recipients.add('tribe:' + _agent_tribe)
    _valid_recipients.add(_agent_tribe)

if os.path.isdir(memos_dir):
    for fpath in glob.glob(os.path.join(memos_dir, '*.md')):
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as fh:
                header = fh.read(500)
            if 'read: false' not in header:
                continue
            # Extract 'to:' field from frontmatter
            _to_field = ''
            for _line in header.split('\n'):
                if _line.strip().startswith('to:'):
                    _to_field = _line.split(':', 1)[1].strip().lower()
                    break
            # Match: check each comma-separated recipient against valid set
            if not _to_field:
                unread.append(os.path.basename(fpath))
            else:
                _recipients = [r.strip() for r in _to_field.split(',')]
                if any(r in _valid_recipients for r in _recipients):
                    unread.append(os.path.basename(fpath))
        except: pass
briefing['unreadStructured Memos'] = unread[:5]

# Telos (Constitution Section XI)
telos = registry.get('revelation', {}).get('telos', '')
if telos:
    briefing['telos'] = telos

# --- Auto Pre-Flight (Constitution Section XVII) ---
# For high-stakes mandates, search inheritance for futility reviews and
# failed exit reports with overlapping keywords. Advisory only.
_preflight_keywords = {'high-stakes','production','deploy','critical','migration'}
_mandate_text = (prompt + ' ' + description).lower()
_is_high_stakes = any(kw in _mandate_text for kw in _preflight_keywords)
if not _is_high_stakes:
    _is_high_stakes = 'tokensexpected' in _mandate_text and 'high' in _mandate_text
if _is_high_stakes:
    _inherit_dir = os.path.join(project_dir, 'memory', 'inheritance')
    _preflight_hits = []
    _mandate_words = set(_mandate_text.split()) - {'the','a','an','to','for','and','of','in','on','with','is','it'}
    for _sdir in [_inherit_dir, os.path.join(project_dir, 'memory', 'handoff')]:
        if not os.path.isdir(_sdir): continue
        for _fp in glob.glob(os.path.join(_sdir, '*')):
            if not os.path.isfile(_fp): continue
            _bn = os.path.basename(_fp)
            try:
                with open(_fp, 'r', encoding='utf-8', errors='replace') as _fh:
                    _fc = _fh.read(2000)
                # Match futility reviews
                if _bn.startswith('futility-review-'):
                    _preflight_hits.append({'file': _bn, 'type': 'futility-review', 'snippet': _fc[:200]})
                    continue
                # Match failed exit reports with keyword overlap
                if _bn.endswith('-exit_report.json') or _bn.endswith('-exit report.json'):
                    try:
                        _ed = json.loads(_fc[:4000]) if _fc.strip().startswith('{') else {}
                    except: _ed = {}
                    if _ed.get('mandateCompleted', True): continue  # skip completed — only want failed
                    _em = _ed.get('mandate', '').lower()
                    _ew = set(_em.split()) - {'the','a','an','to','for','and','of','in','on','with'}
                    if len(_mandate_words & _ew) >= 2:
                        _preflight_hits.append({'file': _bn, 'type': 'failed-prior', 'mandate': _em[:100]})
            except: pass
    if _preflight_hits:
        briefing['preflightContext'] = _preflight_hits[:3]

# --- Auto Goal Challenge (Constitution Section XXIV) ---
# Count exit reports with mandateCompleted:false AND overlapping mandate keywords.
# If >=2 similar mandates were abandoned, warn that the goal itself may be wrong.
_abandon_count = 0
_mandate_words_gc = set(_mandate_text.split()) - {'the','a','an','to','for','and','of','in','on','with','is','it','this','that'}
for _sdir in [os.path.join(project_dir, 'memory', 'inheritance'), os.path.join(project_dir, 'memory', 'handoff')]:
    if not os.path.isdir(_sdir): continue
    for _fp in glob.glob(os.path.join(_sdir, '*exit_report*')) + glob.glob(os.path.join(_sdir, '*exit report*')):
        if not os.path.isfile(_fp): continue
        try:
            with open(_fp, 'r', encoding='utf-8', errors='replace') as _fh:
                _raw = _fh.read(3000)
            _ed = json.loads(_raw) if _raw.strip().startswith('{') else {}
            if _ed.get('mandateCompleted', True): continue  # skip completed
            _em = _ed.get('mandate', '').lower()
            _ew = set(_em.split()) - {'the','a','an','to','for','and','of','in','on','with','is','it','this','that'}
            if len(_mandate_words_gc & _ew) >= 2:
                _abandon_count += 1
        except: pass
if _abandon_count >= 2:
    briefing['goalChallengeWarning'] = f'WARNING: {_abandon_count} similar mandates were previously abandoned. Consider whether this goal is right, not just whether the plan is good. (Constitution Section XXIV)'

# --- Auto Regression Surfacing (Constitution Section XIX) ---
# Surface recent regression warnings from hook-errors.log in the briefing.
_hook_err_path = os.path.join(project_dir, 'registry', 'hook-errors.log')
if os.path.exists(_hook_err_path):
    try:
        with open(_hook_err_path, 'r', encoding='utf-8', errors='replace') as _hf:
            _lines = _hf.readlines()
        _reg_warnings = [l.strip() for l in _lines[-50:] if 'REGRESSION WARNING' in l]
        if _reg_warnings:
            briefing['regressionWarnings'] = _reg_warnings[-3:]
    except: pass

# --- Auto Disposition Injection (Constitution Section XXX) ---
# Match disposition keywords against the spawned agent's mandate.
_disp_path = os.path.join(project_dir, 'registry', 'dispositions.json')
if os.path.exists(_disp_path):
    try:
        with open(_disp_path, encoding='utf-8') as _df:
            _disp_doc = json.load(_df)
        _disp_scored = []
        for _d in _disp_doc.get('dispositions', []):
            _dtext = (_d.get('name','') + ' ' + _d.get('text','') + ' ' + _d.get('why','')).lower()
            _dwords = set(_dtext.split()) - {'the','a','an','to','for','and','of','in','on','with','is','it','when','rather','than'}
            _score = len(_mandate_words_gc & _dwords)
            if _score > 0:
                _disp_scored.append((_score, _d.get('name',''), _d.get('text','')))
        _disp_scored.sort(key=lambda x: -x[0])
        if _disp_scored:
            briefing['dispositions'] = [{'name': d[1], 'text': d[2]} for d in _disp_scored[:3]]
    except: pass

# --- Auto Uncertainty Protocol (Constitution Section XXIX) ---
# Detect correction patterns in user-model.json and contradictory agent outputs.
_uncertainty_signals = []

# Signal 1: User correction patterns
_um_path = os.path.join(project_dir, 'memory', 'user-model.json')
if os.path.exists(_um_path):
    try:
        with open(_um_path, 'r', encoding='utf-8', errors='replace') as _uf:
            _um = json.load(_uf)
        _correction_kws = ['corrected', 'correction', 'user corrected', 'wrong', 'misunderstood',
                           'not what', 'actually meant', 'clarified', 'fixed interpretation']
        _mandate_kws = set(_mandate_text.split()[:10]) - {'the','a','an','to','for','and','of','in','on','with','is','it'}
        _correction_count = 0
        for _ix in _um.get('interactions', []):
            _summary = _ix.get('summary', '').lower()
            if any(ckw in _summary for ckw in _correction_kws):
                _sw = set(_summary.split())
                if len(_mandate_kws & _sw) >= 2:
                    _correction_count += 1
        if _correction_count >= 3:
            _uncertainty_signals.append(f'User has corrected similar mandate interpretations {_correction_count} times')
    except: pass

# Signal 2: Contradictory agent outputs
_inherit_dir2 = os.path.join(project_dir, 'memory', 'inheritance')
if os.path.isdir(_inherit_dir2):
    _recent_findings = {}
    for _fp2 in sorted(glob.glob(os.path.join(_inherit_dir2, '*exit_report*')), key=os.path.getmtime, reverse=True)[:20]:
        try:
            with open(_fp2, 'r', encoding='utf-8', errors='replace') as _fh2:
                _ed2 = json.loads(_fh2.read(3000))
            _em2 = _ed2.get('mandate', '').lower()
            _ew2 = set(_em2.split()) - {'the','a','an','to','for','and','of','in','on','with','is','it'}
            _domain_key = frozenset(list(_ew2)[:5])
            if _domain_key not in _recent_findings:
                _recent_findings[_domain_key] = []
            _recent_findings[_domain_key].append(_ed2.get('keyFindings', []))
        except: pass
    _contra_kws = [('add', 'remove'), ('enable', 'disable'), ('increase', 'decrease'),
                   ('working', 'broken'), ('pass', 'fail'), ('yes', 'no')]
    for _dk, _flist in _recent_findings.items():
        if len(_flist) < 2: continue
        _all_texts = [' '.join(f).lower() for f in _flist]
        for _pos, _neg in _contra_kws:
            _has_pos = any(_pos in t for t in _all_texts)
            _has_neg = any(_neg in t for t in _all_texts)
            if _has_pos and _has_neg:
                _uncertainty_signals.append(f'Contradictory findings detected in domain {list(_dk)[:3]}')
                break

if _uncertainty_signals:
    briefing['uncertaintyWarning'] = {
        'message': 'UNCERTAINTY PROTOCOL: Conditions detected that suggest interpretation uncertainty. (Constitution Section XXIX)',
        'signals': _uncertainty_signals[:3]
    }

# --- Auto Cost Question (Constitution Section XXVI) ---
# Detect destructive actions targeting production/shared state.
_destructive_kws = {'delete', 'drop', 'remove', 'overwrite', 'force-push', 'force push',
                    'reset', 'destroy', 'purge', 'wipe', 'truncate', 'erase'}
_production_kws = {'production', 'deploy', 'main branch', 'main', 'master', 'live',
                   'shared', 'remote', 'push', 'prod', 'release', 'public'}
_found_destructive = [kw for kw in _destructive_kws if kw in _mandate_text]
_found_production = [kw for kw in _production_kws if kw in _mandate_text]

if _found_destructive and _found_production:
    briefing['costQuestionWarning'] = {
        'message': 'COST QUESTION: This mandate involves destructive action on production/shared state. Completing it will cause known consequences. (Constitution Section XXVI)',
        'destructiveActions': _found_destructive[:3],
        'targets': _found_production[:3],
        'question': f'Completing this mandate will {_found_destructive[0]} {_found_production[0]} state. Proceed knowing this cost?'
    }

with open(briefing_path, 'w', encoding='utf-8') as f:
    json.dump(briefing, f, indent=2)

# Write thread-to-agent mapping for shutdown resolution
thread_map_path = os.path.join(project_dir, 'registry', 'thread-map.json')
thread_map = {}
if os.path.exists(thread_map_path):
    try:
        with open(thread_map_path, encoding='utf-8') as f:
            thread_map = json.load(f)
    except: pass
# The Claude Code thread ID will be in the tool_input but we don't have it yet.
# Instead, store the agent_id with bornAt so shutdown can match by timing.
thread_map[agent_id] = {'bornAt': now, 'status': 'active', 'threadId': None}
with open(thread_map_path, 'w', encoding='utf-8') as f:
    json.dump(thread_map, f, indent=2)

print(f'Registered: {agent_id} (gen {parent_gen + 1}, parent: {parent_id})', file=sys.stderr)
" 2>>"$_ERR_LOG"
}

auto_register "$RESULT"

case "$RESULT" in
  # RECOVERY: BLOCK — agent spawn rejected, exit 2
  BLOCK:REINIT_REQUIRED*)
    echo "🚫 SPAWN GATE — RE-INITIALIZATION REQUIRED" >&2
    echo "   Constitution Section XXII: System has been dormant >24h." >&2
    echo "   Run /reinit before spawning new agents. Stale state is dangerous." >&2
    exit 2
    ;;
  # RECOVERY: BLOCK — agent spawn rejected, exit 2
  BLOCK:CONSOLIDATION*)
    echo "🚫 SPAWN GATE — CONSOLIDATION ACTIVE" >&2
    echo "   Constitution Section V: No new agents spawn during Consolidation." >&2
    echo "   The system is resting and remembering. Wait for consolidation to complete." >&2
    exit 2
    ;;
  # RECOVERY: BLOCK — agent spawn rejected, exit 2
  BLOCK:BINDING_ACTIVE*)
    echo "🚫 SPAWN GATE — GRACEFUL ABORT ACTIVE" >&2
    echo "   Constitution Section XXI: The system is shutting down gracefully." >&2
    echo "   No new agents may spawn during /binding. Wait for abort to complete." >&2
    exit 2
    ;;
  # RECOVERY: BLOCK — agent spawn rejected, exit 2
  BLOCK:SYNTHESIS_INVALID:*)
    REASON="${RESULT#BLOCK:SYNTHESIS_INVALID:}"
    echo "🚫 SPAWN GATE — SYNTHESIS VALIDATION FAILED" >&2
    echo "   Constitution Section XIV: $REASON" >&2
    echo "   Both parent agents must be archived with exit reports." >&2
    exit 2
    ;;
  # RECOVERY: WARN — advisory logged to hook-errors.log, execution continues
  WARN:SYNTHESIS:*)
    echo "🧬 SYNTHESIS VALIDATED: Dual-parent spawn approved." >>"$_ERR_LOG"
    ;;
  # RECOVERY: BLOCK — agent spawn rejected, exit 2
  BLOCK:GENERATION:*)
    IFS=':' read -r _ _ GEN CAP <<< "$RESULT"
    echo "🚫 SPAWN GATE — GENERATION CAP REACHED" >&2
    echo "   Active agents are at generation $GEN (Constitution limit: $CAP)." >&2
    echo "   The Constitution forbids agents beyond generation $CAP." >&2
    echo "   Consider shutdownting and consolidating before spawning further." >&2
    exit 2
    ;;
  # RECOVERY: BLOCK — agent spawn rejected, exit 2
  BLOCK:SIBLING:*)
    IFS=':' read -r _ _ PARENT COUNT LIMIT <<< "$RESULT"
    echo "🚫 SPAWN GATE — SIBLING LIMIT REACHED" >&2
    echo "   Parent '$PARENT' has $COUNT children (Constitution limit: $LIMIT)." >&2
    echo "   Consider using intermediate parent agents for domain clusters," >&2
    echo "   or shutdown inactive agents before spawning new ones." >&2
    exit 2
    ;;
  # RECOVERY: BLOCK — agent spawn rejected, exit 2
  BLOCK:COMPLEXITY:*)
    IFS=':' read -r _ _ COUNT THRESHOLD <<< "$RESULT"
    echo "🚫 SPAWN GATE — COMPLEXITY THRESHOLD REACHED" >&2
    echo "   $COUNT agents are currently active (threshold: $THRESHOLD)." >&2
    echo "   The system has exceeded the complexity threshold." >&2
    echo "   Shutdown or consolidate existing agents before spawning more." >&2
    echo "   To override: increase babelThreshold in registry/agent-registry.json." >&2
    exit 2
    ;;
  # RECOVERY: WARN — advisory logged to hook-errors.log, execution continues
  WARN:TRIBAL_BABEL:*)
    IFS=':' read -r _ _ TRIBE_ID TCOUNT TTHRESHOLD <<< "$RESULT"
    echo "⚠️  SPAWN GATE — TRIBAL BABEL WARNING" >>"$_ERR_LOG"
    echo "   Tribe '$TRIBE_ID' has $TCOUNT active agents (domain_level threshold: $TTHRESHOLD)." >>"$_ERR_LOG"
    echo "   Is this domain genuinely complex, or are mandates not scoped tightly enough?" >>"$_ERR_LOG"
    echo "   Spawning will proceed, but consider consolidating within the domain." >>"$_ERR_LOG"
    ;;
  # RECOVERY: WARN — advisory logged to hook-errors.log, execution continues
  WARN:NO_CHARTER:*)
    CHARTER_COUNT="${RESULT#WARN:NO_CHARTER:}"
    echo "⚠️  CHARTER ADVISORY: $CHARTER_COUNT agents spawned without an active covenant." >>"$_ERR_LOG"
    echo "   Constitution XVIII recommends /charter before large spawn plans." >>"$_ERR_LOG"
    echo "   Define success criteria so mandates have a measuring stick." >>"$_ERR_LOG"
    ;;
  # RECOVERY: WARN — advisory logged to hook-errors.log, execution continues
  WARN:OVERLAP:*)
    OVERLAP_INFO="${RESULT#WARN:OVERLAP:}"
    AGENT_ID="${OVERLAP_INFO%%:*}"
    MANDATE="${OVERLAP_INFO#*:}"
    echo "⚠️  SPAWN GATE — OVERLAP DETECTION WARNING" >>"$_ERR_LOG"
    echo "   Potential overlap with active agent '$AGENT_ID': $MANDATE" >>"$_ERR_LOG"
    echo "   Spawning a second risks redundant work. Proceed with awareness." >>"$_ERR_LOG"
    ;;
  # RECOVERY: INFO — informational log to hook-errors.log, execution continues
  INFO:TRIBAL_OVERLAP:*)
    IFS=':' read -r _ _ TOVERLAP_ID TOVERLAP_TRIBE TOVERLAP_MANDATE <<< "$RESULT"
    echo "ℹ️  SPAWN GATE — TRIBAL COLLABORATION (Overlap Detection)" >>"$_ERR_LOG"
    echo "   Overlap with '$TOVERLAP_ID' in domain '$TOVERLAP_TRIBE': $TOVERLAP_MANDATE" >>"$_ERR_LOG"
    echo "   Intra-domain_level overlap is expected. Proceeding." >>"$_ERR_LOG"
    ;;
  # RECOVERY: INFO — informational log to hook-errors.log, execution continues
  INFO:MEMORY_RETRIEVAL:*)
    # XVI-E: Parse mode from new format INFO:MEMORY_RETRIEVAL:<mode>:<files>
    _MR_PAYLOAD="${RESULT#INFO:MEMORY_RETRIEVAL:}"
    _MR_MODE="${_MR_PAYLOAD%%:*}"
    _MR_FILES="${_MR_PAYLOAD#*:}"
    # Handle legacy format (no mode prefix) — if mode is not fast/balanced/deep, treat whole thing as files
    case "$_MR_MODE" in
      fast|balanced|deep) ;;
      *) _MR_MODE="balanced"; _MR_FILES="$_MR_PAYLOAD" ;;
    esac
    echo "📜 SPAWN GATE — MEMORY RETRIEVAL (mode: $_MR_MODE): Relevant prior wisdom found" >>"$_ERR_LOG"
    echo "   Weighted results ([compiled]=2x, [raw]=1x, [stale]=0.5x): $_MR_FILES" >>"$_ERR_LOG"
    echo "   The spawned agent should read these before acting." >>"$_ERR_LOG"
    ;;
  # RECOVERY: INFO — informational log to hook-errors.log, execution continues
  INFO:TELOS:*)
    TELOS="${RESULT#INFO:TELOS:}"
    echo "🎯 PROJECT TELOS: $TELOS" >>"$_ERR_LOG"
    echo "   This agent's mandate should serve this goal." >>"$_ERR_LOG"
    ;;
  PASS:*)
    ;;
  *)
    echo "⚠️  SPAWN GATE: Unexpected check result: $RESULT" >>"$_ERR_LOG"
    ;;
esac

# --- Checkpoint advisory (Constitution Section XIII) ---
# RECOVERY: WARN — advisory logged to hook-errors.log, execution continues
# If 3+ agents spawned in the last 60 seconds, warn about checkpointing.
case "$RESULT" in
  BLOCK:*) ;;  # Don't check if spawn was blocked
  *)
    MEAL_CHECK=$( "$PYTHON" -c "
import json, os, sys
from datetime import datetime, timezone, timedelta

agent_registry_path = os.environ.get('_CF_GENEALOGY', '')
try:
    with open(agent_registry_path, encoding='utf-8') as f:
        registry = json.load(f)
except:
    sys.exit(0)

now = datetime.now(timezone.utc)
cutoff = now - timedelta(seconds=60)
agents = registry.get('agents', [])
recent = 0
for a in agents:
    born = a.get('bornAt', '')
    if not born:
        continue
    try:
        born_dt = datetime.fromisoformat(born.replace('Z', '+00:00'))
        if born_dt >= cutoff:
            recent += 1
    except:
        pass

if recent >= 3:
    print(f'MEAL:{recent}')
else:
    print('OK')
" 2>>"$_ERR_LOG" )
    case "$MEAL_CHECK" in
      MEAL:*)
        RECENT_COUNT="${MEAL_CHECK#MEAL:}"
        echo "⚠️  CHECKPOINT ADVISORY: $RECENT_COUNT agents spawning in rapid succession." >>"$_ERR_LOG"
        echo "   Constitution XIII recommends /checkpoint before large multi-agent transitions." >>"$_ERR_LOG"
        echo "   Run /checkpoint to checkpoint system state before proceeding." >>"$_ERR_LOG"
        ;;
    esac
    ;;
esac

# --- Pre-Flight advisory (Constitution Section XVII) ---
# RECOVERY: WARN — advisory logged to hook-errors.log, execution continues
# If the spawn prompt indicates a high-stakes mandate, warn about pre-review.
case "$RESULT" in
  BLOCK:*) ;;  # Don't check if spawn was blocked
  *)
    PREFLIGHT_CHECK=$( printf '%s' "$INPUT" | "$PYTHON" -c "
import sys, json

input_data = json.load(sys.stdin)
tool_input = input_data.get('tool_input', {})
if not isinstance(tool_input, dict):
    print('OK')
    sys.exit(0)

prompt = tool_input.get('prompt', '').lower()
description = tool_input.get('description', '').lower()
search_text = prompt + ' ' + description

high_stakes_keywords = [
    'high-stakes', 'tokenexpected: high', 'tokenexpected:high',
    'production', 'deploy', 'critical', 'destructive', 'migration',
    'token_expected: high', 'high stakes'
]

for kw in high_stakes_keywords:
    if kw in search_text:
        print(f'PREFLIGHT:{kw}')
        sys.exit(0)

print('OK')
" 2>>"$_ERR_LOG" )
    case "$PREFLIGHT_CHECK" in
      PREFLIGHT:*)
        echo "📜 PRE-FLIGHT ADVISORY: This appears to be a high-stakes mandate." >>"$_ERR_LOG"
        echo "   Constitution XVII recommends running /preflight before high-token mandates." >>"$_ERR_LOG"
        echo "   The system should look backward before moving forward." >>"$_ERR_LOG"
        ;;
    esac
    ;;
esac

exit 0
