#!/usr/bin/env python3
"""Fail a PR if it introduces em/en dashes or curly quotes in prose files.

Based on github.com/blader/humanizer's dash/quote rules (SS14, SS19): these
characters are unambiguous AI-writing tells and are banned outright, not
just discouraged. Only lines ADDED by this PR are checked, so existing
content already on the default branch is not retroactively flagged.

Non-blocking: a small set of high-signal AI filler words/phrases is also
flagged as a warning, for human judgement rather than a hard failure.
"""
import re
import subprocess
import sys

CHECK_EXTENSIONS = (".html", ".htm", ".md", ".mdx")
SKIP_PATH_PARTS = ("node_modules/", "vendor/", "/dist/", ".min.")

BANNED_CHARS = {
    "—": "em dash (—)",
    "–": "en dash (–)",
    "“": "curly opening quote (“)",
    "”": "curly closing quote (”)",
    "‘": "curly opening apostrophe (‘)",
    "’": "curly closing apostrophe/apostrophe (’)",
}

# Non-blocking style warnings: highest-signal words from
# github.com/blader/humanizer's "overused AI words" and "sales language"
# lists. Deliberately short — long lists produce noisy false positives.
WARN_WORDS = [
    r"\bdelve\b", r"\btapestry\b", r"\btestament\b", r"\bunderscores?\b",
    r"\bboasts a\b", r"\bnestled\b", r"\bin the heart of\b",
    r"\bit'?s not just\b.*\bit'?s\b", r"\blet'?s dive in\b",
    r"\bfostering\b", r"\bshowcas(e|ing)\b", r"\bpivotal\b",
    r"\bgame-changer\b", r"\bstands? as a testament\b",
]

def get_base_ref():
    for ref in ("origin/main", "origin/master"):
        if subprocess.run(["git", "rev-parse", "--verify", ref],
                           capture_output=True).returncode == 0:
            return ref
    print("::error::could not find origin/main or origin/master to diff against")
    sys.exit(1)

def main():
    base = get_base_ref()
    diff = subprocess.run(
        ["git", "diff", "--unified=0", f"{base}...HEAD", "--"] +
        [f"*{ext}" for ext in CHECK_EXTENSIONS],
        capture_output=True, text=True,
    ).stdout

    current_file = None
    failures = []
    warnings = []

    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            current_file = line[6:]
            continue
        if not line.startswith("+") or line.startswith("+++"):
            continue
        if current_file is None or any(p in current_file for p in SKIP_PATH_PARTS):
            continue
        content = line[1:]
        for char, label in BANNED_CHARS.items():
            if char in content:
                failures.append(f"{current_file}: {label} in added line: {content.strip()[:140]}")
        for pattern in WARN_WORDS:
            if re.search(pattern, content, re.IGNORECASE):
                warnings.append(f"{current_file}: possible AI filler ({pattern}): {content.strip()[:140]}")

    if warnings:
        print("::warning::Humanizer style check found possible AI-writing filler (non-blocking):")
        for w in warnings[:30]:
            print(f"  - {w}")

    if failures:
        print("::error::Humanizer check failed: em/en dashes or curly quotes were added.")
        print("These are banned outright (github.com/blader/humanizer SS14/SS19), not just discouraged.")
        print("Replace em/en dashes with commas, periods, colons, or parentheses.")
        print("Replace curly quotes/apostrophes with straight ones (\" and ').")
        print()
        for f in failures[:50]:
            print(f"  - {f}")
        if len(failures) > 50:
            print(f"  ... and {len(failures) - 50} more")
        sys.exit(1)

    print("Humanizer check passed: no em/en dashes or curly quotes in added content.")

if __name__ == "__main__":
    main()
