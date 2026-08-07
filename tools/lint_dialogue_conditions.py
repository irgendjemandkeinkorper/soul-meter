#!/usr/bin/env python3
"""Lint Dialogue Manager response conditions in dialogue/*.dialogue.

WHY THIS EXISTS
---------------
A Dialogue Manager response condition must use the self-closing form:

    - "Choice text" [if expr /]

The plain form `[if expr]` SILENTLY DOES NOTHING. The choice always shows. A
broken consequence check therefore looks exactly like a working one, in the
editor and at runtime. `DEPENDENCIES.md` records the defect.

That failure mode is invisible to the test suite: nothing asserts that a gated
choice was hidden, so a dropped `/` ships. This lint is the only mechanical
guard.

WHAT IT CHECKS
--------------
1. NOT_SELF_CLOSING  a response-line `[if ...]` tag missing the trailing `/`.
2. CONDITION_NOT_LAST another tag follows the condition on the same line.
   Dialogue Manager expects the condition to close the response line; anything
   after it is at best unread and at worst a parse surprise.

WHAT IT DOES NOT CHECK
----------------------
- Whether the expression itself is valid GDScript, or whether the flags and
  quest ids it names exist. Flag existence is the quest audit's job.
- Block-level `if expr:` lines, which are ordinary Dialogue Manager syntax and
  need no self-closing marker.
- Conditions built by string interpolation. This lint is textual.

A clean result means no response condition is silently dead. It does not mean
the conditions are correct.

USAGE
-----
    python3 tools/lint_dialogue_conditions.py [--quiet] [path ...]

Exit code 0 when clean, 1 when a violation is found, 2 on a usage error.
This script does not run Godot, so its exit code is trustworthy. Do not port
it into a `godot --headless --script` tool: that aborts at teardown 20 to 30
percent of the time in this environment and would make CI flaky.
"""

from __future__ import annotations

import argparse
import glob
import re
import sys

IF_TAG = re.compile(r"\[if\b")

DEFAULT_GLOB = "dialogue/*.dialogue"


class Finding:
    def __init__(self, kind: str, path: str, line_no: int, tag: str, note: str) -> None:
        self.kind = kind
        self.path = path
        self.line_no = line_no
        self.tag = tag
        self.note = note

    def __str__(self) -> str:
        return f"{self.path}:{self.line_no}: {self.kind}: {self.note}\n    {self.tag}"


def is_response_line(line: str) -> bool:
    """A Dialogue Manager response starts with '-' after optional indentation."""
    stripped = line.lstrip()
    return stripped.startswith("- ") or stripped == "-"


def scan_line(path: str, line_no: int, line: str) -> list[Finding]:
    if not is_response_line(line):
        return []

    findings: list[Finding] = []
    for match in IF_TAG.finditer(line):
        close = line.find("]", match.start())
        if close == -1:
            findings.append(
                Finding(
                    "UNCLOSED",
                    path,
                    line_no,
                    line[match.start():].strip(),
                    "an [if tag has no closing bracket",
                )
            )
            continue

        tag = line[match.start(): close + 1]
        if not tag.endswith("/]"):
            findings.append(
                Finding(
                    "NOT_SELF_CLOSING",
                    path,
                    line_no,
                    tag,
                    "condition is missing the trailing '/' and will silently no-op; "
                    "the choice always shows",
                )
            )
            continue

        trailing = line[close + 1:].strip()
        if trailing:
            findings.append(
                Finding(
                    "CONDITION_NOT_LAST",
                    path,
                    line_no,
                    tag,
                    f"the condition must close the response line, but {trailing!r} follows it",
                )
            )

    return findings


def scan_file(path: str) -> list[Finding]:
    findings: list[Finding] = []
    with open(path, encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, start=1):
            findings.extend(scan_line(path, line_no, line.rstrip("\n")))
    return findings


SELF_TEST_CASES: list[tuple[str, str, str | None]] = [
    ("self-closing condition", '- "Text" [if GameState.get_flag("x") /]', None),
    ("missing slash", '- "Text" [if GameState.get_flag("x")]', "NOT_SELF_CLOSING"),
    ("tag after condition", '- "Text" [if a /] [#tag=X]', "CONDITION_NOT_LAST"),
    ("unclosed tag", '- "Text" [if a', "UNCLOSED"),
    ("tag before condition is fine", '- "Text" [#tag=X] [if a /]', None),
    ("indented response", '\t- "Text" [if a]', "NOT_SELF_CLOSING"),
    ("block condition is not a response", "if GameState.get_flag(\"x\"):", None),
    ("narration line is not a response", "Speaker: he said [if] loudly", None),
]


def run_self_test() -> int:
    """Prove both failure modes are caught and the safe forms are not flagged.

    Fixtures are inline strings, never files. A committed `.dialogue` fixture
    would be picked up by Godot's importer and by this lint's own default glob.
    """
    failures = 0
    for name, line, expected in SELF_TEST_CASES:
        findings = scan_line("<self-test>", 1, line)
        actual = findings[0].kind if findings else None
        ok = actual == expected
        if not ok:
            failures += 1
        print(
            f"  {'PASS' if ok else 'FAIL'}  {name}: "
            f"expected {expected or 'no finding'}, got {actual or 'no finding'}"
        )
    print(
        f"DIALOGUE LINT SELF-TEST: {len(SELF_TEST_CASES) - failures}"
        f"/{len(SELF_TEST_CASES)} passed"
    )
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Lint Dialogue Manager response conditions.",
        epilog="Exit 0 when clean, 1 when a violation is found.",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help=f"files to scan (default: {DEFAULT_GLOB})",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="print nothing on success",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="check the lint against inline fixtures instead of scanning files",
    )
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()

    paths = args.paths or sorted(glob.glob(DEFAULT_GLOB))
    if not paths:
        print(
            f"DIALOGUE LINT: no files matched {DEFAULT_GLOB}; run from the project root",
            file=sys.stderr,
        )
        return 2

    findings: list[Finding] = []
    conditions = 0
    for path in paths:
        try:
            with open(path, encoding="utf-8") as handle:
                for line in handle:
                    if is_response_line(line):
                        conditions += len(IF_TAG.findall(line))
        except OSError as error:
            print(f"DIALOGUE LINT: cannot read {path}: {error}", file=sys.stderr)
            return 2
        findings.extend(scan_file(path))

    if findings:
        print(
            f"DIALOGUE LINT: {len(findings)} violation(s) "
            f"across {len(paths)} file(s)",
            file=sys.stderr,
        )
        for finding in findings:
            print(finding, file=sys.stderr)
        print(
            "\nA response condition needs the self-closing form: [if expr /]\n"
            "The plain form [if expr] silently does nothing. See DEPENDENCIES.md.",
            file=sys.stderr,
        )
        return 1

    if not args.quiet:
        print(
            f"DIALOGUE LINT: {conditions} response condition(s) "
            f"across {len(paths)} file(s), all self-closing"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
