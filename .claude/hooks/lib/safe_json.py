"""Atomic read-modify-write for JSON files with file locking.

Uses FileLock for concurrency safety and atomic temp+rename for
write safety. Windows-safe (uses shutil.move instead of os.replace
to handle cross-volume moves and locked files).
"""

import json
import os
import shutil
import tempfile

from .filelock import FileLock


def read_modify_write(json_path, modifier_fn, err_log=None):
    """Atomically read, modify, and write a JSON file under lock.

    Args:
        json_path: Path to the JSON file.
        modifier_fn: Callable that receives parsed JSON data, mutates and
                     returns it.
        err_log: Optional path to an error log file for lock failures.

    Returns:
        True on success, False if the lock could not be acquired.
    """
    lock = FileLock(json_path)
    if not lock.acquire():
        if err_log:
            try:
                with open(err_log, 'a', encoding='utf-8') as f:
                    f.write(f'LOCK FAILED: {json_path}\n')
            except OSError:
                pass
        return False
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        data = modifier_fn(data)

        # Write to temp file in the same directory, then atomic rename
        dir_name = os.path.dirname(os.path.abspath(json_path))
        tmp_fd, tmp_path = tempfile.mkstemp(dir=dir_name, suffix='.tmp')
        try:
            with os.fdopen(tmp_fd, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            # shutil.move works on Windows even when os.replace fails
            shutil.move(tmp_path, json_path)
        except Exception:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
            raise

        return True
    finally:
        lock.release()
