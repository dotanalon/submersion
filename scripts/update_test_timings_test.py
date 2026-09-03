#!/usr/bin/env python3
"""Unit tests for update_test_timings.py."""

import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(
        name, os.path.join(_HERE, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


check_test_timings = _load("check_test_timings")
guard = _load("update_test_timings")


def _make_test_tree(root, relative_paths):
    for rel in relative_paths:
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            fh.write("void main() {}\n")


def _write_timings(path, files):
    with open(path, "w") as fh:
        json.dump({"_meta": {"generated_at": "2026-01-01T00:00:00Z"},
                   "files": files}, fh)


class UpdateTests(unittest.TestCase):
    def test_noop_when_in_sync(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["a_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {"test/a_test.dart": 1.0})
            with open(timings_path) as fh:
                before = fh.read()

            missing, stale = guard.update(test_dir, timings_path)

            self.assertEqual(missing, [])
            self.assertEqual(stale, [])
            with open(timings_path) as fh:
                self.assertEqual(fh.read(), before)

    def test_adds_missing_with_median_placeholder_and_drops_stale(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["a_test.dart", "new_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {
                "test/a_test.dart": 1.0,
                "test/b_gone_test.dart": 3.0,
                "test/c_gone_test.dart": 5.0,
            })

            missing, stale = guard.update(test_dir, timings_path)

            self.assertEqual(missing, ["test/new_test.dart"])
            self.assertEqual(
                stale, ["test/b_gone_test.dart", "test/c_gone_test.dart"])

            with open(timings_path) as fh:
                updated = json.load(fh)["files"]
            self.assertEqual(updated, {
                "test/a_test.dart": 1.0,
                # median of [1.0, 3.0, 5.0]
                "test/new_test.dart": 3.0,
            })

    def test_placeholder_is_zero_when_no_existing_weights(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["only_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {})

            guard.update(test_dir, timings_path)

            with open(timings_path) as fh:
                updated = json.load(fh)["files"]
            self.assertEqual(updated, {"test/only_test.dart": 0.0})

    def test_missing_files_are_inserted_in_sorted_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["z_new_test.dart", "a_existing_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {"test/a_existing_test.dart": 1.0})

            guard.update(test_dir, timings_path)

            with open(timings_path) as fh:
                updated = json.load(fh)["files"]
            self.assertEqual(
                list(updated),
                ["test/a_existing_test.dart", "test/z_new_test.dart"])

    def test_raises_when_test_dir_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {})
            with self.assertRaises(FileNotFoundError):
                guard.update(os.path.join(tmp, "no_such_dir"), timings_path)


class MainTests(unittest.TestCase):
    def test_main_reports_when_already_in_sync(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["a_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {"test/a_test.dart": 1.0})

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = guard.main(["prog", test_dir, timings_path])
            self.assertEqual(rc, 0)
            self.assertIn("already up to date", buf.getvalue())

    def test_main_fixes_drift_and_check_then_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["a_test.dart", "new_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {
                "test/a_test.dart": 1.0,
                "test/gone_test.dart": 2.0,
            })

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = guard.main(["prog", test_dir, timings_path])
            self.assertEqual(rc, 0)
            self.assertIn("added placeholder weight for test/new_test.dart",
                          buf.getvalue())
            self.assertIn("removed stale entry for test/gone_test.dart",
                          buf.getvalue())

            # The fix this script applies should satisfy the CI gate.
            ok, _ = check_test_timings.check(test_dir, timings_path)
            self.assertTrue(ok)

    def test_main_reports_missing_timings_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["a_test.dart"])

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = guard.main(
                    ["prog", test_dir, os.path.join(tmp, "missing.json")])
            self.assertEqual(rc, 1)
            self.assertIn("ERROR", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
