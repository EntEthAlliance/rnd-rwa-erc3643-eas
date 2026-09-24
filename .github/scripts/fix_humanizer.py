#!/usr/bin/env python3
"""Auto-fix em/en dashes and curly quotes in lines a PR adds, then commit.

Only touches lines newly ADDED by this PR (parsed from unified diff hunk
headers), so it never rewrites pre-existing content elsewhere in the file.
This is the auto-correct counterpart to a blocking check: nothing fails,
the PR branch just gets a follow-up commit with the fix applied.
"""
import re
import subprocess
import sys

CHECK_EXTENSIONS = (".html", ".htm", ".md", ".mdx")
SKIP_PATH_PARTS = ("node_modules/", "vendor/", "/dist/", ".min.")

REPLACEMENTS = [
    (re.compile("“"), '"'),   # “
    (re.compile("”"), '"'),   # ”
    (re.compile("‘"), "'"),   # ‘
    (re.compile("’"), "'"),   # ’
    (re.compile(r"(?<=\d)–(?=\d)"), "-"),   # en dash between digits: a range, e.g. 10-20
    (re.compile(r"\s*[–—]\s*"), ", "), # remaining en/em dash, spaced or not
]

def get_base_ref():
    for ref in ("origin/main", "origin/master"):
        if subprocess.run(["git", "rev-parse", "--verify", ref], capture_output=True).returncode == 0:
            return ref
    print("::error::could not find origin/main or origin/master to diff against")
    sys.exit(1)

def added_line_numbers_by_file(base):
    """Parse `git diff -U0` hunk headers to get exact new-file line numbers added by this PR."""
    diff = subprocess.run(
        ["git", "diff", "--unified=0", f"{base}...HEAD", "--"] +
        [f"*{ext}" for ext in CHECK_EXTENSIONS],
        capture_output=True, text=True,
    ).stdout

    result = {}
    current_file = None
    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            current_file = line[6:]
            continue
        if current_file is None or any(p in current_file for p in SKIP_PATH_PARTS):
            continue
        m = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
        if m:
            start = int(m.group(1))
            count = int(m.group(2)) if m.group(2) is not None else 1
            if count > 0:
                result.setdefault(current_file, set()).update(range(start, start + count))
    return result

def fix_line(text):
    for pattern, repl in REPLACEMENTS:
        text = pattern.sub(repl, text)
    return text

def main():
    base = get_base_ref()
    targets = added_line_numbers_by_file(base)
    if not targets:
        print("No added .html/.md content in this PR; nothing to check.")
        return

    changed_files = []
    for path, line_numbers in targets.items():
        try:
            with open(path, encoding="utf-8") as f:
                lines = f.readlines()
        except FileNotFoundError:
            continue  # file was deleted in this PR
        touched = False
        for ln in line_numbers:
            idx = ln - 1
            if idx < 0 or idx >= len(lines):
                continue
            original = lines[idx]
            fixed = fix_line(original)
            if fixed != original:
                lines[idx] = fixed
                touched = True
        if touched:
            with open(path, "w", encoding="utf-8") as f:
                f.writelines(lines)
            changed_files.append(path)

    if not changed_files:
        print("Humanizer check: no em/en dashes or curly quotes found in added content.")
        return

    print("Humanizer auto-fix applied to:")
    for f in changed_files:
        print(f"  - {f}")

    subprocess.run(["git", "config", "user.name", "eea-humanizer-bot"], check=True)
    subprocess.run(["git", "config", "user.email", "actions@github.com"], check=True)
    subprocess.run(["git", "add"] + changed_files, check=True)
    subprocess.run(
        ["git", "commit", "-m",
         "Auto-fix: straighten quotes, remove em/en dashes (humanizer)\n\n"
         "Automated by the humanizer CI check. Only lines this PR added were touched."],
        check=True,
    )
    import os
    head_ref = os.environ.get("GITHUB_HEAD_REF")
    if head_ref:
        subprocess.run(["git", "push", "origin", f"HEAD:{head_ref}"], check=True)
    else:
        subprocess.run(["git", "push"], check=True)
    print("Pushed auto-fix commit to this PR branch.")

if __name__ == "__main__":
    main()
