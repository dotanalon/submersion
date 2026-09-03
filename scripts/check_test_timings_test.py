#!/usr/bin/env python3
"""Unit tests for check_test_timings.py."""

import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_test_timings",
    os.path.join(_HERE, "check_test_timings.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)


def _make_test_tree(root, relative_paths):
    for rel in relative_paths:
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            fh.write("void main() {}\n")


def _write_timings(path, files):
    with open(path, "w") as fh:
        json.dump({"_meta": {}, "files": files}, fh)


class FindTestFilesTests(unittest.TestCase):
    def test_finds_nested_test_dart_files_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, [
                "a_test.dart",
                "nested/b_test.dart",
                "nested/helper.dart",
                "nested/deep/c_test.dart",
            ])
            found = guard.find_test_files(test_dir)
            self.assertEqual(found, {
                "test/a_test.dart",
                "test/nested/b_test.dart",
                "test/nested/deep/c_test.dart",
            })


class DiffTests(unittest.TestCase):
    def test_no_drift(self):
        files = {"test/a_test.dart", "test/b_test.dart"}
        self.assertEqual(guard.diff(files, files), ([], []))

    def test_missing_and_stale(self):
        timed = {"test/a_test.dart", "test/gone_test.dart"}
        actual = {"test/a_test.dart", "test/new_test.dart"}
        missing, stale = guard.diff(timed, actual)
        self.assertEqual(missing, ["test/new_test.dart"])
        self.assertEqual(stale, ["test/gone_test.dart"])


class CheckTests(unittest.TestCase):
    def test_ok_when_in_sync(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["a_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {"test/a_test.dart": 1.0})

            ok, lines = guard.check(test_dir, timings_path)
            self.assertTrue(ok)
            self.assertTrue(any("ok" in l for l in lines))

    def test_fails_and_prints_fix_command_on_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["a_test.dart", "new_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {
                "test/a_test.dart": 1.0,
                "test/gone_test.dart": 2.0,
            })

            ok, lines = guard.check(test_dir, timings_path)
            self.assertFalse(ok)
            text = "\n".join(lines)
            self.assertIn("test/new_test.dart", text)
            self.assertIn("test/gone_test.dart", text)
            self.assertIn(guard.FIX_COMMAND, text)


class MainTests(unittest.TestCase):
    def test_main_passes_on_sync(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["a_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {"test/a_test.dart": 1.0})

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = guard.main(["prog", test_dir, timings_path])
            self.assertEqual(rc, 0)
            self.assertIn("PASS", buf.getvalue())

    def test_main_fails_on_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["new_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            _write_timings(timings_path, {})

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = guard.main(["prog", test_dir, timings_path])
            self.assertEqual(rc, 1)
            self.assertIn("FAIL", buf.getvalue())

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

    def test_main_reports_malformed_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            test_dir = os.path.join(tmp, "test")
            _make_test_tree(test_dir, ["a_test.dart"])
            timings_path = os.path.join(tmp, "timings.json")
            with open(timings_path, "w") as fh:
                fh.write("{not valid json")

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = guard.main(["prog", test_dir, timings_path])
            self.assertEqual(rc, 1)
            self.assertIn("ERROR", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
