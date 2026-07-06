"""Shared utilities for Covenant Framework hook scripts.

Provides timestamps, project dir resolution, error logging, and
prompt field parsing used across all hooks.
"""

import os
import sys
from datetime import datetime, timezone


def get_timestamp():
    """Return current UTC timestamp in ISO format."""
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def get_project_dir():
    """Derive project directory from _CF_PROJECT_DIR env var or script location."""
    proj = os.environ.get('_CF_PROJECT_DIR', '')
    if proj:
        return proj
    # Fallback: derive from CLAUDE_PROJECT_DIR
    proj = os.environ.get('CLAUDE_PROJECT_DIR', '')
    if proj:
        return proj
    return '.'


def get_err_log_path(project_dir=None):
    """Derive error log path from project directory."""
    if project_dir is None:
        project_dir = get_project_dir()
    path = os.environ.get('_CF_ERR_LOG', '')
    if path:
        return path
    return os.path.join(project_dir, 'registry', 'hook-errors.log')


def log_error(err_log, message):
    """Append a line to the error log. Swallows write errors."""
    try:
        with open(err_log, 'a', encoding='utf-8') as f:
            f.write(message + '\n')
    except OSError:
        pass


def parse_prompt_field(prompt, field):
    """Extract a field value from prompt text.

    e.g. parse_prompt_field('PARENT_ID: foo', 'PARENT_ID') -> 'foo'
    Returns None if the field is not found.
    """
    import re
    match = re.search(rf'{re.escape(field)}:\s*(\S+)', prompt)
    if match:
        return match.group(1)
    return None


def setup_lib_path():
    """Add the hooks directory to sys.path so lib modules can be imported."""
    hooks_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if hooks_dir not in sys.path:
        sys.path.insert(0, hooks_dir)
