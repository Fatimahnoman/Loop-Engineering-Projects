"""
reviewer.py — The REVIEWER (Checker) agent in run_workflow.sh.

Reads reverse_string from the string_utils.py located in the CURRENT
working directory (each worktree has its own copy), runs assertions, and
exits with code 0 (PASS) or code 1 (FAIL).

The exit code is the single source of truth consumed by run_workflow.sh.
"""

import sys

from string_utils import reverse_string

TESTS = [
    ("abc", "cba"),
    ("hello", "olleh"),
    ("", ""),
    ("a", "a"),
    ("racecar", "racecar"),
]


def main():
    for inp, expected in TESTS:
        got = reverse_string(inp)
        if got != expected:
            print(f"FAIL: reverse_string({inp!r}) = {got!r}, expected {expected!r}")
            return 1
    print("PASS: all reverse_string checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())