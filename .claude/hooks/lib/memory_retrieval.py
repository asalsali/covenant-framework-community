"""Memory Retrieval search -- XVI-D weighted scoring, XVI-E named modes.

Replaces two duplicated implementations in pre-tool-agent-gate.sh.
Provides weighted memory retrieval with compiled-truth boost and
configurable search modes (fast/balanced/deep).
"""

import glob
import json
import os
import re
import time


MODE_PARAMS = {
    'fast':     {'max_results': 3,  'content_limit': 500,  'dirs': ['handoff']},
    'balanced': {'max_results': 5,  'content_limit': 1500, 'dirs': ['handoff', 'domains']},
    'deep':     {'max_results': 10, 'content_limit': 3000, 'dirs': ['handoff', 'domains', 'semantic', 'inheritance']},
}

STOP_WORDS = {'the', 'a', 'an', 'to', 'for', 'and', 'of', 'in', 'on', 'with'}


def select_mode(prompt):
    """Derive search mode from REMEMBER_MODE or tokensExpected in prompt."""
    mode_match = re.search(r'REMEMBER_MODE:\s*(fast|balanced|deep)', prompt)
    if mode_match:
        return mode_match.group(1)

    te_match = re.search(r'tokensExpected[:\s]+[^a-z]?(low|medium|high)[^a-z]?', prompt, re.IGNORECASE)
    te_val = te_match.group(1).lower() if te_match else 'medium'
    mode_map = {'low': 'fast', 'medium': 'balanced', 'high': 'deep'}
    return mode_map.get(te_val, 'balanced')


def compute_weight(fpath, now_epoch=None, stale_threshold=2592000):
    """XVI-D compiled-truth boost. Returns (weight, category).

    Categories: 'compiled' (2.0x), 'raw' (1.0x), 'stale' (0.5x).
    stale_threshold defaults to 30 days in seconds.
    """
    if now_epoch is None:
        now_epoch = time.time()

    fname = os.path.basename(fpath)

    # Compiled truth: domain memory files
    if fname in ('domain_memory.md', 'patterns.md'):
        return 2.0, 'compiled'

    # Exit reports -- check freshness score
    if fname.endswith('-exit_report.json') or fname.endswith('-exit report.json'):
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as f:
                edata = json.loads(f.read(4000))
            fs = edata.get('freshnessScore', {})
            base = fs.get('baseScore', 0.5)
            if base >= 0.5:
                return 2.0, 'compiled'
            elif base < 0.3:
                return 0.5, 'stale'
            else:
                return 1.0, 'raw'
        except (FileNotFoundError, json.JSONDecodeError, KeyError):
            return 1.0, 'raw'

    # Check file age for staleness
    try:
        mtime = os.path.getmtime(fpath)
        if (now_epoch - mtime) > stale_threshold:
            return 0.5, 'stale'
    except OSError:
        pass

    return 1.0, 'raw'


def _build_search_dirs(project_dir, mode, domain_id=None):
    """Build the list of directories to search based on mode."""
    params = MODE_PARAMS[mode]
    dirs = []

    if 'handoff' in params['dirs']:
        dirs.append(os.path.join(project_dir, 'memory', 'handoff'))
    if 'domains' in params['dirs']:
        # If domain_id specified, search that domain first
        domains_base = os.path.join(project_dir, 'memory', 'domains')
        if os.path.isdir(domains_base):
            if domain_id:
                dpath = os.path.join(domains_base, domain_id)
                if os.path.isdir(dpath):
                    dirs.append(dpath)
            for dname in os.listdir(domains_base):
                dpath = os.path.join(domains_base, dname)
                if os.path.isdir(dpath) and dpath not in dirs:
                    dirs.append(dpath)
    if 'semantic' in params['dirs']:
        dirs.append(os.path.join(project_dir, 'memory', 'semantic'))
    if 'inheritance' in params['dirs']:
        dirs.append(os.path.join(project_dir, 'memory', 'inheritance'))

    return dirs


def search_memory(project_dir, search_words, mode='balanced', domain_id=None):
    """Weighted memory retrieval search.

    Args:
        project_dir: Root project directory.
        search_words: Set of search keywords (already lowered, stop words removed).
        mode: 'fast', 'balanced', or 'deep'.
        domain_id: Optional domain ID for domain-first search.

    Returns: list of (weighted_score, category, filename) sorted by score desc.
    """
    params = MODE_PARAMS[mode]
    max_results = params['max_results']
    content_limit = params['content_limit']
    search_dirs = _build_search_dirs(project_dir, mode, domain_id)

    now_epoch = time.time()
    scored = []

    for search_dir in search_dirs:
        if not os.path.isdir(search_dir):
            continue
        for fpath in glob.glob(os.path.join(search_dir, '*')):
            if not os.path.isfile(fpath):
                continue
            try:
                with open(fpath, 'r', encoding='utf-8', errors='replace') as fh:
                    content = fh.read(content_limit).lower()
                if mode == 'fast':
                    content = os.path.basename(fpath).lower() + ' ' + content[:500]
                content_words = set(content.split())
                match = search_words & content_words
                if len(match) >= 3:
                    weight, category = compute_weight(fpath, now_epoch)
                    weighted_score = len(match) * weight
                    scored.append((weighted_score, category, os.path.basename(fpath)))
            except (OSError, UnicodeDecodeError):
                pass

    scored.sort(key=lambda x: -x[0])
    return scored[:max_results]


def extract_search_words(text):
    """Extract search words from text, removing stop words."""
    return set(text.lower().split()) - STOP_WORDS
