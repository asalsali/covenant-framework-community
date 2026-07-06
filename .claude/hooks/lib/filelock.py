"""Cross-platform file locking using O_CREAT | O_EXCL.

Extracted from the proven lockfile pattern in post-tool-token-log.sh.
Works on both Unix and Windows without external dependencies.
"""

import os
import time


class FileLock:
    """Exclusive file lock via atomic lockfile creation.

    Usage as context manager:
        with FileLock('/path/to/target.json'):
            # critical section
            ...

    The lock file is created at <path>.lock. Stale locks older than
    stale_threshold seconds are automatically removed on retry.
    """

    def __init__(self, path, timeout=5.0, stale_threshold=10.0):
        self.lock_path = path + '.lock'
        self.timeout = timeout
        self.stale_threshold = stale_threshold

    def acquire(self):
        """Attempt to acquire the lock. Returns True on success, False on timeout."""
        deadline = time.time() + self.timeout
        attempt = 0
        while time.time() < deadline:
            try:
                fd = os.open(self.lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                try:
                    os.write(fd, str(os.getpid()).encode())
                finally:
                    os.close(fd)
                return True
            except FileExistsError:
                # Check for stale lock
                try:
                    age = time.time() - os.path.getmtime(self.lock_path)
                    if age > self.stale_threshold:
                        os.remove(self.lock_path)
                        continue
                except OSError:
                    pass
                attempt += 1
                time.sleep(min(0.2 * attempt, 1.0))
        return False

    def release(self):
        """Release the lock by removing the lockfile."""
        try:
            os.remove(self.lock_path)
        except OSError:
            pass

    def __enter__(self):
        if not self.acquire():
            raise TimeoutError(f"Could not acquire lock: {self.lock_path}")
        return self

    def __exit__(self, *args):
        self.release()
