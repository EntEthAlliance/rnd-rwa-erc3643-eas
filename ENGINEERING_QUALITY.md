# Engineering Quality Framework

> Copy this file into a repository's root and tailor the bracketed parts.
> It makes a change's final intent, documentation responsibilities, review
> evidence, and deployment status explicit. Technology neutral.

## Outcome we want

Every merged change is understandable, evidence-backed, documented where it
affects people or operations, and safe to deploy. A pull request is a concise
statement of the final intended change, not a record of every failed approach
taken to reach it.

## Failure modes we are preventing

- **Patch stacking:** review finds a design problem and the team layers fixes
  onto an implementation whose premise is no longer sound.
- **Historical anchoring:** people or agents treat prior commits, comments, or
  code as correct merely because they already exist.
- **Documentation debt:** documentation is deferred and goes stale before it is
  updated.
- **False green:** checks pass without proving the built, deployable product
  behaves as intended.
- **AI overreach:** an AI makes or validates factual claims without enough
  evidence, context, or human accountability.

## Sources of truth

Resolve conflicts in descending order:

1. The approved issue's outcome, scope, acceptance criteria, evidence, and
   stated uncertainties.
2. The current branch's intended end state, as recorded in the pull request.
3. Executable behavior: relevant tests, build output, production-safe config.
4. Current maintained documentation.
5. Earlier commits, review comments, chat, and agent output — as evidence only.

If these sources conflict, stop and record the conflict. Do not silently select
the convenient version.

## Definition of done

- The observable outcome and non-goals match the approved issue.
- Acceptance criteria are demonstrably met, including regression behavior.
- Required documentation is updated in the same pull request, or an
  evidence-backed exemption is recorded.
- Relevant automated checks pass against the appropriate artifact.
- Reviewers can explain the final design and its trade-offs without replaying
  the branch's history.
- The merge commit has passed its release gate, and the deployment result is
  confirmed separately where deployment is in scope.

## Pull request contract

Every pull request must contain substantive answers to these sections:

```markdown
## Intended end state
<!-- Observable final behavior. Do not narrate the implementation journey. -->

## Scope and non-goals
<!-- Included surfaces, boundaries, and deliberately excluded work. -->

## Why this matters
<!-- Product, operational, user, or risk rationale. -->

## Documentation impact
<!-- Documents changed, or a specific evidence-backed reason none are needed. -->

## Review / re-baseline status
<!-- New implementation | local amendment | re-baselined | replacement PR. -->

## Testing and evidence
<!-- Commands/checks run, results, and relevant evidence. -->

## Issue
<!-- `Fixes #123`, or explain why no issue applies. -->

## Limitations or uncertainty
<!-- Material unknowns and follow-up decisions; say "None identified" if true. -->
```

## Amend versus re-baseline policy

Amend the current pull request only for a **local correction**: a typo, a
missing test, a narrowly scoped bug, an incorrect condition, or a small
accessibility/documentation gap.

Re-baseline when review changes the design, core behavior, data model, security
model, public interface, acceptance criteria, or non-goals; when several
compensating fixes have accumulated; or when the final change cannot be
explained in one coherent paragraph.

When re-baselining:

1. Pause feature additions and write a short decision note.
2. State the intended end state, what the prior approach got wrong, what is
   retained or discarded, and the new documentation/test obligations.
3. Rewrite the affected implementation cleanly, or create a replacement pull
   request if the old review history is misleading.
4. Link a replacement PR to the superseded one; do not carry approval forward.
5. Request fresh review of the final diff against the target branch.

### Re-baseline decision note

```markdown
## Re-baseline decision

**Trigger:** [What materially changed?]

**Final intended design:** [One concise paragraph.]

**Discarded assumptions or code:** [What will not be retained, and why?]

**Retained work:** [What remains valid, and evidence for that judgment.]

**Documentation and test impact:** [Exact docs/tests to update or create.]

**Review status:** [Fresh review required / replacement PR: #...]
```

## Documentation-as-done policy

Documentation is part of the feature, not follow-up work.

| Change affects | Review or update |
| --- | --- |
| User-visible behavior, routes, UI | User guide, README, product documentation |
| Domain terms, data values, taxonomy | Reference/taxonomy/framework documentation |
| Setup, CI, PR, review, deployment | Contributing guide and agent instructions |
| API, schema, integration | API/reference documentation and examples |
| Internal-only refactor | Record why external and contributor docs are unchanged |

An exemption must name the affected surface and say why existing documentation
remains accurate. "N/A" and "no docs needed" are not sufficient.

## AI and agent operating rules

Agents assist with analysis, tests, and drafts; they do not become the source of
truth or silently broaden scope.

- Start from the issue and final intended end state, not prior agent output.
- Treat historical code and comments as evidence, never as proof of correctness.
- Cite paths, tests, primary sources, or observed behavior for factual claims.
- Flag conflicts, uncertainty, and scope drift instead of guessing.
- Recommend re-baselining before adding compensating patches to a flawed design.
- Propose documentation changes with the feature; do not defer them by default.
- Review the final diff against the target branch after a material rewrite.
- Never self-approve a change, claim deployment success without evidence, or
  treat a passing retry as proof that a flaky test is healthy.

## CI/CD quality and deployment policy

CI answers **"is this change safe and correct?"** Deployment answers **"is the
verified artifact live?"** Keep them separate: deployment must not be the first
place a change is tested, and a green pull-request check is not proof that a
change reached production.

### Test tiers

| Tier | Purpose | Typical examples |
| --- | --- | --- |
| PR / issue policy | Ensures the work is reviewable and ready | Required PR sections, linked issue readiness, documentation impact |
| Lint | Catches suspicious code and style mistakes | Static linting, format policy, unsafe patterns |
| Type / static analysis | Finds incompatible assumptions before execution | Type checking, schema/static analysis |
| Unit tests | Proves focused rules and data transformations | Validation, calculations, generated-file freshness |
| Build | Produces the deployable artifact | Production bundle/static output, asset checks |
| End-to-end tests | Proves key user flows at a real boundary | Routes, interaction, errors, permissions |
| Post-deploy smoke check | Confirms the published version is healthy | Live URL, expected version, key path/status |

Run the ordered gate locally when practical:

```text
lint → type/static analysis → unit tests → production build → end-to-end tests
```

End-to-end tests must exercise the **built artifact**, not only a development
server.

### Pull-request CI policy

| Change category | Minimum checks |
| --- | --- |
| Documentation/process only | PR policy, doc lint/link/reference checks |
| Tooling, test harness, configuration | Lint, static analysis, unit tests; build/E2E if runtime or artifact behavior can change |
| Application/data/build input | Lint, static analysis, unit tests, production build |
| Browser-visible behavior, routes, critical flow | All above plus E2E against the built artifact |
| Dependency, infrastructure, auth, release config | Full gate plus security/integration checks |

Path selection is a speed optimization, not an escape hatch. Keep its mapping
unit-tested, reviewed, and conservative: uncertain changes select more checks.
Provide one stable aggregate result (for example, `CI result`) as the branch
protection requirement.

Cancel obsolete runs for superseded commits where safe, but preserve an
auditable result for the final commit under review. Do not use automatic test
retries to hide flakes.

### Artifact and test reliability rules

- Build once, retain the verified artifact, and use that same artifact for E2E
  tests and deployment when the platform permits.
- Keep tests hermetic: control time, isolate test data, block or explicitly
  allow third-party network dependencies.
- Retain failure artifacts long enough to diagnose: reports, screenshots,
  traces, logs, built-artifact metadata.
- Fail on stale generated files; regeneration belongs in the same PR.
- Give each CI job only the permissions it needs. The build/test job should not
  receive production deployment credentials.

### Main-branch release gate

```text
Pull-request gate passes
→ required human approval and merge
→ full CI on the exact main-branch commit
→ immutable deployable artifact is selected
→ deployment runs with narrowly scoped credentials
→ post-deploy smoke check confirms the live version
```

The deployment workflow must wait for the successful CI result for the **same
commit**. Do not trigger an independent deployment on a push to main if it can
race ahead of CI.

Serialize production deployments and record the commit SHA, artifact
identifier, environment, start/end time, and published URL.

### Deployment evidence and rollback

Every production deployment should leave evidence answering:

- Which exact commit and immutable artifact are live?
- Which CI run and test results authorized it?
- What URL/environment was updated and when?
- Did the post-deploy smoke check pass?
- What is the tested rollback target and who can invoke it?

If deployment fails, do not infer that the site is unchanged or partially
changed. Inspect the deployment record and live response, then repair and
redeploy the same verified change or roll back to the last known-good artifact.

## Review checklist

- [ ] Is the final intent clear without reading branch history?
- [ ] Did scope change enough to require re-baselining or a replacement PR?
- [ ] Are issue acceptance criteria met with evidence?
- [ ] Are documentation changes complete, or is the exemption sound?
- [ ] Do tests prove the relevant behavior, including regression behavior?
- [ ] Are AI claims supported by code, tests, or primary sources?
- [ ] Does deployment wait for verification of the exact commit?
- [ ] Do E2E tests run against the built artifact?
- [ ] Did the post-deploy smoke check confirm the intended live version?

## Ownership and cadence

- **Author:** owns a coherent final diff, documentation impact statement, evidence.
- **Reviewer:** owns independent verification of final intent and factual
  accuracy; does not approve inherited history blindly.
- **Maintainer/release owner:** owns branch protection and deployment policy.
- **Monthly:** lightweight review of README, onboarding, and operations docs.
- **Quarterly:** deeper audit for stale claims, broken links, obsolete process.
- **Before a release or handoff:** validate the full user/contributor path.
