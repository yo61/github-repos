# Quality criteria

Evaluate a change against these before calling it complete. **Blocking**
criteria must pass; **warning** criteria are flagged and judged in context.

Most entries came from something that actually went wrong here — the `Source`
line names the decision record. Items marked *(automated)* are enforced by
`prek` and listed only so the set is complete.

Update after each evaluation: date a criterion that caught something, promote
one triggered 3+ times to an automated check, and flag never-triggered
criteria for pruning after 10+ evaluations. Propose new criteria rather than
adding them silently.

---

## Category: Repo data files (`data/<org>/*.yaml`)

## Criteria:

    - Every key states a deviation from the module default. Cross-check each
      key against `modules/github-repo/variables.tf`; delete any key whose
      value already equals that default.
    - `name:` matches the filename stem. *(automated: `repo-yaml-name-check`)*
    - A brand-new repo omits `create_default_branch`. It builds a
      `github_branch` needing a source commit, so it fails on an empty repo;
      `main` is established by the first push. Imported repos may set it.
    - A private repo on the free-tier personal org omits rulesets,
      `secret_scanning`, advanced security, and classic protection — all
      paywalled. It keeps `vulnerability_alerts` and
      `dependabot_security_updates`.
    - Collaborators use block style, not flow style.
    - File passes yamllint (120 col) and yamlfmt (100 col). *(automated)*

## Severity: blocking

## Source: `CLAUDE.md` conventions; free-tier licensing limits found while
onboarding private repos.

## Last triggered: 2026-08-04 — `ycst-admin-docs`. The free-tier private-repo
criterion determined the whole file: rulesets, the review gate, secret
scanning, and Pages were all dropped from the `homelab-docs` shape it was
modelled on. Confirmed post-apply — `GET /rulesets` returns 403, so declaring
any ruleset would have failed the apply. `auto_init` was also omitted so the
repo was created empty for the initial push. One deliberate departure:
`visibility: private` restates the module default and was kept anyway, since
it is the fact the access-control design rests on; see
`decisions/2026-08-04-ycst-admin-docs-private-cpanel.md`.

---

## Category: Required status check gates

## Criteria:

    - Every `context:` names a job that runs unconditionally on PRs to the
      default branch — no `paths:` filter, no event conditional. A filtered
      job leaves its check `Expected` forever and blocks every PR that does
      not touch those paths.
    - Context strings match the job name GitHub reports exactly, including
      matrix suffixes (`check (node 22)`, not `check`).
    - `allow_auto_merge: true` is set only where a *behavioural* check exists
      — a test suite, a real build, or a validator that exercises what the
      repo produces. Lint plus metadata validation is not sufficient.
    - The `required_status_checks` ruleset carries no bypass. The review
      requirement lives on the built-in `default_branch` ruleset. Never fold
      CI contexts into a ruleset that has a bypass actor, or that actor
      skips CI too.

## Severity: blocking

## Source: `decisions/2026-08-03-ci-baseline-two-tier-policy.md`;
`decisions/2026-07-30-reportlab-pdf-automerge-review.md`

## Last triggered: 2026-08-03 — `homebrew-tap` deferred because its CI is
`paths:`-filtered; `reportlab-pdf` and `claude-skills` held back from Tier 2
for lacking a behavioural check.

---

## Category: Drift detection and reconciliation

## Criteria:

    - Sweep both APIs before calling a repo clean. Rulesets and classic
      branch protection are disjoint: `gh api repos/<org>/<repo>/rulesets`
      cannot see classic protection, and the GraphQL `branchProtectionRules`
      query cannot see rulesets. Checking one proves nothing about the other.
    - Promote any context held only by drift into the YAML *before* deleting
      the drift, so the effective gate never weakens across the transition.
    - Express the intent in code and delete the drift. Never import a
      differently-shaped drift resource into state.
    - Confirm a deletion actually happened by re-querying, not by assuming
      the out-of-band step was performed.

## Severity: blocking

## Source:
`decisions/2026-08-04-gate-apply-ordering-and-classic-protection-drift.md`

## Last triggered: 2026-08-04 — classic protection found on `unifi-mcp`
(3 undeclared contexts) and `claude-skills` (fully redundant); both since
deleted.

---

## Category: Plan and apply discipline

## Criteria:

    - Run `task plan` and read the diff before `task apply`. Use the
      `Taskfile` wrappers, not the underlying CLI.
    - A plan proposing to *create* resources that already exist means the
      backend is misconfigured, not that the infrastructure is missing.
      Stop and fix the backend; do not apply.
    - An instance address change produces destroy+create. Stategraph ignores
      HCL `moved`/`removed` blocks and has no `state mv`/`rm`. Confirm that
      is intended before applying.
    - Plan files may contain sensitive values and are gitignored. Never
      commit one.
    - Never echo a credential to verify it is set. Test with `${VAR:+set}`,
      never `${VAR:-...}` — the latter prints the value when the variable is
      set.

## Severity: blocking

## Source: `CLAUDE.md`; Stategraph state-mutation gaps;
`decisions/2026-08-04-native-terraform-http-backend.md`

## Last triggered: 2026-08-04 — a gitignored backend file meant a clone
without it would silently use local state and plan to recreate all 130
instances; and `TF_HTTP_PASSWORD` was printed in full by a `${VAR:-}` check.

---

## Category: Post-apply outcome verification

## Criteria:

    - Verify the outcome, not the config. Confirming a ruleset exists does
      not confirm the gate works or that PRs can land.
    - After enabling `allow_auto_merge`, re-trigger review on open bot PRs
      that were approved while it was disabled. They stay stranded, and the
      daily backstop has not reliably recovered them.
    - Before recording an apply as blocked or failed, re-query live state. A
      broken wrapper does not mean the change failed to land.
    - When a decision record states a condition that later changes, correct
      the record rather than leaving a stale claim.

## Severity: blocking

## Source:
`decisions/2026-08-04-gate-apply-ordering-and-classic-protection-drift.md`;
PR #40

## Last triggered: 2026-08-04 — `unifi-mcp` #31/#32/#33 sat approved and
unmerged after the gate went live; PR #40 recorded "apply is blocked" when
the apply had in fact landed. Also 2026-08-04, PR #46 — the stale-record
criterion fired outside a post-apply context: adding a second admin to
`ycst-admin-docs` invalidated the "single maintainer" premise its decision
record used to reject a Team upgrade. Corrected in the same PR. Consider
moving that criterion to its own category if it keeps triggering here.

---

## Category: Decision records and documentation

## Criteria:

    - A decision affecting more than today's task is logged to
      `decisions/YYYY-MM-DD-<topic>.md` with all six headings: Decision,
      Context, Alternatives considered, Reasoning, Trade-offs accepted,
      Supersedes.
    - Relative dates ("last week") are converted to absolute dates.
    - `Supersedes` names the prior record or states "none".
    - Documentation naming a command is updated in the same PR that changes
      the command, so `CLAUDE.md` never describes a path that does not work.
    - Existing decisions in the area were checked before deciding, and
      followed unless new information invalidates them.

## Severity: warning

## Source: global `CLAUDE.md` decision-journal rules; the `decisions/`
convention in this repo.

## Last triggered: 2026-08-04 — `CLAUDE.md` documented `stategraph tf`
wrappers whose write path had been failing since 2026-08-02.

---

## Category: Git and PR hygiene

## Criteria:

    - `git branch --show-current` returns neither `main` nor `master` before
      committing.
    - `prek run --files <changed>` passes before committing.
    - Subject is conventional, imperative, and ≤72 characters; one logical
      change per commit.
    - The PR describes what the diff does now — not discarded approaches or
      prior iterations.
    - Plain, factual language. Avoid "critical", "crucial", "essential",
      "significant", "comprehensive", "robust", "elegant".

## Severity: blocking

## Source: global `CLAUDE.md` git workflow; project `CLAUDE.md`.

## Last triggered: never
