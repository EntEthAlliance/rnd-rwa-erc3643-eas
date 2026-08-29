#!/usr/bin/env python3
"""Unit tests for check_pr_contract.

The framework requires the policy mapping itself be unit-tested, since a lenient
check is worse than no check: it makes an unreviewable PR look compliant.

Run: python3 -m pytest test_check_pr_contract.py -q
"""

import check_pr_contract as c

GOOD = """
## Intended end state
The invite-list sync writes roles into column C for every matched contact.

## Scope and non-goals
Covers the Apollo enrichment path only. Does not touch the Pipedrive importer.

## Why this matters
Blank roles made the speaker shortlist unusable for outreach triage.

## Documentation impact
Updated README.md with the new --dry-run flag and its default behavior.

## Review / re-baseline status
New implementation. No prior review history to carry forward.

## Testing and evidence
Ran `pytest -q` (34 passed) and a dry-run against 20 rows; output in the PR log.

## Issue
Fixes #42

## Limitations or uncertainty
None identified
"""


def test_compliant_body_passes():
    assert c.check(GOOD) == []


def test_missing_section_is_reported():
    body = GOOD.replace("## Why this matters", "## Something else")
    problems = c.check(body)
    assert any("Why this matters" in p for p in problems)


def test_empty_section_is_reported():
    body = GOOD.replace(
        "Blank roles made the speaker shortlist unusable for outreach triage.", ""
    )
    problems = c.check(body)
    assert any("Why this matters" in p for p in problems)


def test_na_placeholder_is_rejected():
    body = GOOD.replace(
        "Updated README.md with the new --dry-run flag and its default behavior.", "N/A"
    )
    problems = c.check(body)
    assert any("Documentation impact" in p for p in problems)


def test_bare_no_docs_needed_is_rejected():
    body = GOOD.replace(
        "Updated README.md with the new --dry-run flag and its default behavior.",
        "no docs needed",
    )
    problems = c.check(body)
    assert any("Documentation impact" in p for p in problems)


def test_docs_exemption_with_evidence_is_accepted():
    body = GOOD.replace(
        "Updated README.md with the new --dry-run flag and its default behavior.",
        "Internal-only refactor of the retry helper; no external surface changed, "
        "so the contributor guide remains accurate.",
    )
    assert c.check(body) == []


def test_none_identified_allowed_only_for_uncertainty():
    body = GOOD.replace("None identified", "none identified.")
    assert c.check(body) == []

    body2 = GOOD.replace(
        "Covers the Apollo enrichment path only. Does not touch the Pipedrive importer.",
        "None identified",
    )
    assert any("Scope and non-goals" in p for p in c.check(body2))


def test_thin_answer_is_rejected():
    body = GOOD.replace(
        "The invite-list sync writes roles into column C for every matched contact.",
        "makes it work",
    )
    problems = c.check(body)
    assert any("Intended end state" in p for p in problems)


def test_html_comment_hints_do_not_count_as_answers():
    body = GOOD.replace(
        "The invite-list sync writes roles into column C for every matched contact.",
        "<!-- Observable final behavior. Do not narrate the journey. -->",
    )
    problems = c.check(body)
    assert any("Intended end state" in p for p in problems)


def test_headings_inside_code_fences_are_ignored():
    body = GOOD + "\n```markdown\n## Intended end state\nfake\n```\n"
    assert c.check(body) == []


def test_heading_normalisation_tolerates_spacing_and_case():
    body = GOOD.replace(
        "## Review / re-baseline status", "## Review/Re-baseline Status"
    )
    assert c.check(body) == []


def test_issue_section_requires_a_reference():
    body = GOOD.replace("Fixes #42", "no")
    problems = c.check(body)
    assert any("Issue" in p for p in problems)
