#!/usr/bin/env python3
"""Bring .github/test-timings.json's file list back in sync with test/.

This does NOT re-measure anything -- it has no way to know how long a new
test file actually takes without running the suite. It only repairs the
*shape* of the file so scripts/check_test_timings.py passes again: new test
files are added with a placeholder weight (the median of the existing
weights, a reasonable guess until the next real measurement), and entries for
deleted test files are dropped. Run this after adding/removing/renaming test
files, then commit the updated JSON. Pure stdlib.

Usage: update_test_timings.py [test_dir] [timings_path]
"""

import json
import os
import statistics
import sys
from datetime import datetime, timezone

DEFAULT_TEST_DIR = "test"
DEFAULT_TIMINGS_PATH = ".github/test-timings.json"


def find_test_files(test_dir):
    """Return the set of '_test.dart' paths under test_dir, repo-relative.

    Paths are reported relative to test_dir's parent, so they read the same
    way (e.g. "test/foo_test.dart") whether test_dir is passed as "test" from
    the repo root or as an absolute path, as tests here do.
    """
    if not os.path.isdir(test_dir):
        raise FileNotFoundError(f"test_dir not found: {test_dir}")
    base = os.path.dirname(os.path.normpath(test_dir)) or "."
    found = set()
    for root, _dirs, files in os.walk(test_dir):
        for name in files:
            if name.endswith("_test.dart"):
                rel = os.path.relpath(os.path.join(root, name), base)
                found.add(rel.replace(os.sep, "/"))
    return found


def update(test_dir=DEFAULT_TEST_DIR, timings_path=DEFAULT_TIMINGS_PATH):
    """Sync the timings file's entries to test_dir. Returns (missing, stale)."""
    with open(timings_path, encoding="utf-8") as fh:
        timings = json.load(fh)
    files = timings.setdefault("files", {})
    actual_files = find_test_files(test_dir)
    missing = sorted(actual_files - set(files))
    stale = sorted(set(files) - actual_files)

    if missing or stale:
        placeholder = round(statistics.median(files.values()), 3) if files else 0.0
        for f in missing:
            files[f] = placeholder
        for f in stale:
            del files[f]
        timings["files"] = dict(sorted(files.items()))
        timings.setdefault("_meta", {})["updated_at"] = (
            datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        )
        with open(timings_path, "w", encoding="utf-8") as fh:
            json.dump(timings, fh, indent=2, sort_keys=False)
            fh.write("\n")

    return missing, stale


def main(argv):
    test_dir = argv[1] if len(argv) > 1 else DEFAULT_TEST_DIR
    timings_path = argv[2] if len(argv) > 2 else DEFAULT_TIMINGS_PATH

    try:
        missing, stale = update(test_dir, timings_path)
    except OSError as exc:
        print(f"ERROR: {exc}")
        return 1
    except json.JSONDecodeError as exc:
        print(f"ERROR parsing {timings_path}: {exc}")
        return 1

    if not missing and not stale:
        print(f"{timings_path} is already up to date.")
        return 0

    for f in missing:
        print(f"  + added placeholder weight for {f}")
    for f in stale:
        print(f"  - removed stale entry for {f}")
    print(f"Updated {timings_path}. Review and commit the change; the added "
          "entries carry a placeholder weight until the next real measurement.")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
