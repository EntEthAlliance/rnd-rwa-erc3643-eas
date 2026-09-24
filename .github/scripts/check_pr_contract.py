#!/usr/bin/env python3
"""Deterministic PR-contract check.

Verifies a pull request body contains every required section from the
Engineering Quality Framework, and that each answer is substantive rather than a
placeholder. Exits 1 with a reviewable list of problems, 0 when the contract is
satisfied.

Usage:
    check_pr_contract.py --body-file body.md
    echo "$PR_BODY" | check_pr_contract.py
"""

from __future__ import annotations

import argparse
import re
import sys

REQUIRED_SECTIONS = [
    "Intended end state",
    "Scope and non-goals",
    "Why this matters",
    "Documentation impact",
    "Review / re-baseline status",
    "Testing and evidence",
    "Issue",
    "Limitations or uncertainty",
]

# Sections where an explicit "nothing to report" answer is legitimate.
ALLOWED_NULL_ANSWERS = {
    "Limitations or uncertainty": re.compile(r"none identified", re.I),
}

# Placeholder answers that never count as substantive.
PLACEHOLDER = re.compile(
    r"^(n/?a|tbd|todo|none|no|nope|-+|\.+|none needed|no docs needed|"
    r"not applicable|see above|same as above)$",
    re.I,
)

MIN_CHARS = 20

# "Documentation impact" must name a surface or justify the exemption; a bare
# "no docs needed" is explicitly rejected by the framework.
DOCS_EXEMPTION_EVIDENCE = re.compile(
    r"\.(md|mdx|rst|txt|ipynb)\b|readme|guide|changelog|docs?/|"
    r"unchanged because|remains accurate|internal-only|no external surface",
    re.I,
)


def strip_comments(text: str) -> str:
    """Remove HTML comments — template hints are not answers."""
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def parse_sections(body: str) -> dict[str, str]:
    """Map each `## Heading` to its body text."""
    sections: dict[str, str] = {}
    current: str | None = None
    buf: list[str] = []
    in_fence = False

    for line in body.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        if not in_fence:
            m = re.match(r"^\s{0,3}##\s+(.*?)\s*$", line)
            if m:
                if current is not None:
                    sections[current] = "\n".join(buf).strip()
                current = m.group(1).strip()
                buf = []
                continue
        if current is not None:
            buf.append(line)

    if current is not None:
        sections[current] = "\n".join(buf).strip()
    return sections


def normalize(heading: str) -> str:
    """Compare headings tolerantly: case, spacing, and slash spacing."""
    return re.sub(r"\s+", " ", heading.replace("/", " / ")).strip().lower()


def check(body: str) -> list[str]:
    """Return a list of problems; empty means the contract is satisfied."""
    problems: list[str] = []
    sections = parse_sections(strip_comments(body))
    found = {normalize(k): v for k, v in sections.items()}

    for required in REQUIRED_SECTIONS:
        answer = found.get(normalize(required))

        if answer is None:
            problems.append(f"Missing required section: '## {required}'")
            continue

        answer = answer.strip()
        if not answer:
            problems.append(f"'{required}' is empty — every section needs a substantive answer.")
            continue

        allowed = ALLOWED_NULL_ANSWERS.get(required)
        if allowed and allowed.search(answer):
            continue

        if PLACEHOLDER.match(answer):
            problems.append(
                f"'{required}' is a placeholder ({answer!r}). State the actual answer."
            )
            continue

        if required == "Documentation impact" and not DOCS_EXEMPTION_EVIDENCE.search(answer):
            problems.append(
                "'Documentation impact' must name the documents changed, or name the "
                "affected surface and say why existing documentation stays accurate. "
                "A bare assertion is not an exemption."
            )
            continue

        if required == "Issue" and len(answer) < 6:
            problems.append(
                "'Issue' must reference an issue (e.g. 'Fixes #123') or explain why none applies."
            )
            continue

        if required != "Issue" and len(answer) < MIN_CHARS:
            problems.append(
                f"'{required}' is too thin ({len(answer)} chars, need {MIN_CHARS}+)."
            )

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body-file", help="File containing the PR body; default stdin.")
    args = parser.parse_args()

    if args.body_file:
        with open(args.body_file, encoding="utf-8") as fh:
            body = fh.read()
    else:
        body = sys.stdin.read()

    problems = check(body)
    if problems:
        print("PR contract check FAILED:\n")
        for p in problems:
            print(f"  - {p}")
        print(
            "\nSee ENGINEERING_QUALITY.md - 'Pull request contract'. "
            "The PR must state the final intended change, not the implementation journey."
        )
        return 1

    print("PR contract check passed: all required sections present and substantive.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
