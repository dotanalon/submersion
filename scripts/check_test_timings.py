#!/usr/bin/env python3
"""Verify .github/test-timings.json still lists exactly the current test files.

ci.yaml shards `flutter test` by FILE, using the per-file duration weights in
`.github/test-timings.json` to balance shards by wall-clock time instead of
plain file count (see that file's `_meta.method` for how the weights were
measured). A test file added or removed since the weights were captured makes
that mapping stale: a new file gets no weight at all (silently sorted into
whichever shard as if it were free), and a deleted file leaves a dangling
entry. Both drift the shards out of balance without any visible failure --
this guard makes that drift a loud CI failure instead, with the fix command
printed inline. Pure stdlib.

Usage: check_test_timings.py [test_dir] [timings_path]
"""

import json
import os
import sys

DEFAULT_TEST_DIR = "test"
DEFAULT_TIMINGS_PATH = ".github/test-timings.json"
FIX_COMMAND = "python3 scripts/update_test_timings.py"


def find_test_files(test_dir):
    """Return the sorted set of '_test.dart' paths under test_dir, repo-relative.

    Paths are reported relative to test_dir's parent, so they read the same
    way (e.g. "test/foo_test.dart") whether test_dir is passed as "test" from
    the repo root or as an absolute path, as tests here do.
    """
    base = os.path.dirname(os.path.normpath(test_dir)) or "."
    found = set()
    for root, _dirs, files in os.walk(test_dir):
        for name in files:
            if name.endswith("_test.dart"):
                rel = os.path.relpath(os.path.join(root, name), base)
                found.add(rel.replace(os.sep, "/"))
    return found


def load_timings(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def diff(timed_files, actual_files):
    """Return (missing, stale): missing lacks a weight, stale no longer exists."""
    missing = sorted(actual_files - timed_files)
    stale = sorted(timed_files - actual_files)
    return missing, stale


def check(test_dir=DEFAULT_TEST_DIR, timings_path=DEFAULT_TIMINGS_PATH):
    """Return (ok, lines) describing whether the timings file is current."""
    timings = load_timings(timings_path)
    timed_files = set(timings.get("files", {}))
    actual_files = find_test_files(test_dir)
    missing, stale = diff(timed_files, actual_files)

    if not missing and not stale:
        return True, [f"  ok    {len(actual_files)} test files match "
                      f"{timings_path}"]

    lines = []
    for f in missing:
        lines.append(f"  FAIL  {f} has no weight in {timings_path}")
    for f in stale:
        lines.append(f"  FAIL  {f} is listed in {timings_path} but no "
                      "longer exists")
    lines.append("")
    lines.append(f"  To fix: run `{FIX_COMMAND}`, then commit the updated "
                  f"{timings_path}.")
    return False, lines


def main(argv):
    test_dir = argv[1] if len(argv) > 1 else DEFAULT_TEST_DIR
    timings_path = argv[2] if len(argv) > 2 else DEFAULT_TIMINGS_PATH

    print(f"Checking {timings_path} against test files under {test_dir}/")
    try:
        ok, lines = check(test_dir, timings_path)
    except OSError as exc:
        print(f"  ERROR reading {timings_path}: {exc}")
        return 1
    except json.JSONDecodeError as exc:
        print(f"  ERROR parsing {timings_path}: {exc}")
        return 1

    for line in lines:
        print(line)
    print("  -> PASS" if ok else "  -> FAIL: test-timings.json is out of date")
    return 0 if ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
