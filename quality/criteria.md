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
      key against `modules/github-repo/variables.tf` **and** the computed
      defaults in `modules/github-repo/data.tf`; delete any key whose value
      already equals that default. `variables.tf` alone is not enough:
      `security_and_analysis` defaults to `null` there, but `data.tf` turns
      that into `secret_scanning` + `secret_scanning_push_protection` for
      every `visibility: public` repo, so declaring them restates the
      effective default.
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

## Last triggered: 2026-08-25 — `helm-charts` (PR #76), twice. First on the
sweep below. Then again in review: the new file declared
`security_and_analysis`, which `data.tf` already supplies for public repos.
It was missed because the criterion named only `variables.tf`, where the
default is `null` — the criterion has been widened to name `data.tf` too.
Six existing public repos (`unifictl`, `kuard`, `go-udap`, `homelab-docs`,
`python-template`, `civi-mcp`) restate the same block and are untouched so
far.

## Last triggered (same PR): 2026-08-25 — `helm-charts` (PR #76). The
brand-new-repo criterion kept `create_default_branch` out of the file, and the
deviations-only criterion drove a sweep of the existing data: eight files
restated `delete_branch_on_merge: true`, already the module default at
`modules/github-repo/variables.tf:190`. Removing it planned as a no-op —
`modules/org` passes `lookup(..., null)` for an absent key and the child
variable is `nullable = false`, so Terraform substitutes the default.
`commitlint-github-action`'s `delete_branch_on_merge: false` is a real
deviation and was kept. Two `default_branch: main` restatements (`kuard`,
`go-udap`) were found and left for a separate PR.

## Last triggered (prior): 2026-08-04 — `ycst-admin-docs`. The free-tier
private-repo criterion determined the whole file: rulesets, the review gate,
secret scanning, and Pages were all dropped from the `homelab-docs` shape it was
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

## Last triggered: 2026-08-25 — `helm-charts` (PR #76) declared no
`required_status_checks` ruleset. The repo is created empty, so any context
named now would sit `Expected` forever and block its first PR. The gate
follows once CI exists, matching the Phase 2 sequencing in the two-tier
policy.

## Last triggered (prior): 2026-08-03 — `homebrew-tap` deferred because its
CI is `paths:`-filtered; `reportlab-pdf` and `claude-skills` held back from
Tier 2 for lacking a behavioural check.

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
    - Establish which side is stale before reconciling a plan diff. A diff
      is not automatically drift to revert: the managed repo may have
      adopted the value deliberately, making this repo the stale side.
      Check the target repo's own `decisions/` and `CLAUDE.md`, and its
      commit log around the setting, before applying. If it was decided
      there, record the value in the data file instead.

## Severity: blocking

## Source:
`decisions/2026-08-04-gate-apply-ordering-and-classic-protection-drift.md`;
the stale-side criterion from
`decisions/2026-09-04-unifictl-rebase-only-merge-buttons.md`.

## Last triggered: 2026-08-04 — classic protection found on `unifi-mcp`
(3 undeclared contexts) and `claude-skills` (fully redundant); both since
deleted.

## Last triggered (stale-side): 2026-09-04 — `unifictl`. The plan proposed
`allow_merge_commit`/`allow_squash_merge` `false -> true`, which reads as
drift to revert. `unifictl`'s own
`decisions/2026-09-03-rebase-only-merge-policy.md` had turned both off the
previous day. Applying would have undone it. Added because the existing
criteria all assume the managed repo is the side that drifted.

---

## Category: Plan and apply discipline

## Criteria:

    - Run `task plan` and read the diff before `task apply`. Use the
      `Taskfile` wrappers, not the underlying CLI.
    - A plan proposing to *create* resources that already exist means either
      the backend is misconfigured or a resource's ID no longer resolves.
      Both look identical in the plan. Check the backend first, then check
      whether refresh can still reach the object under the ID in state. Do
      not apply either way.
    - An instance address change needs a `moved` block, and its plan must
      show the move rather than a destroy+create. Under the native CLI
      against the HTTP backend `moved` is honoured, including across
      provider aliases and renamed `for_each` keys in one block. The
      retired `stategraph tf` wrapper ignored it.
    - A `moved` block cannot carry a **rename** when the resource ID is the
      name — as it is for `github_repository` and everything keyed on it.
      Terraform rewrites the address and the provider binding but never the
      ID, so refresh looks for the old name under the new owner, 404s, and
      plans a create. Use `terraform state rm` plus `import` blocks instead;
      both work against the HTTP backend. `removed` blocks cannot substitute
      for the `state rm` — they reject instance keys.
    - A diff that reappears after being applied is a provider `Read`/`Update`
      asymmetry, not drift. Read the provider source for that field before
      applying it a second time — a field `Update` never sends, on a resource
      whose `Update` ends by calling `Read`, can never converge. Applying
      repeatedly is the failure mode: it looks like progress and changes
      nothing. Fix it by making config match reality, by `ignore_changes`, or
      by changing the underlying object — not by re-applying.
    - Plan files may contain sensitive values and are gitignored. Never
      commit one.
    - Never echo a credential to verify it is set. Test with `${VAR:+set}`,
      never `${VAR:-...}` — the latter prints the value when the variable is
      set.

## Severity: blocking

## Source: `CLAUDE.md`; Stategraph state-mutation gaps;
`decisions/2026-08-04-native-terraform-http-backend.md`;
`decisions/2026-08-13-ycst-org-uk-migration.md`

## Last triggered: 2026-08-25 — `python-template` (PR #77). Its `template`
block had been diffing on every plan. Applying the removal was tested and the
diff returned on the next plan: provider v6.13.0 `Read` sets `template` from
the API unconditionally, `Update` never sends it, and `Update` ends by calling
`Read`. `template_repository` is immutable server-side, so the repo was
recreated. The read-the-plan criterion also carried the reconciliation — the
plan showed the swap needed no `state rm`, contrary to what had been planned.
This category's new first criterion was written from this.

## Last triggered (prior): 2026-08-13 — the `ycst-org-uk` migration. `moved`
blocks rebound both repos to the new provider but left the old names as IDs,
so the plan proposed to create two repos that already existed. The
create-vs-exists criterion caught it and nothing was applied; the backend was
fine, which is why that criterion now names the second cause. Recovered with
`terraform state rm` plus `import` blocks. Also 2026-08-13, second trigger of
the credential criterion: `${GITHUB_TOKEN:+yes}${GITHUB_TOKEN:-no}` printed a
PAT in full — the `:+` guard was written correctly and then undone by a `:-`
fallback on the same line. Token rotated. One more trigger promotes it to an
automated check; consider a hook matching `\$\{[A-Z_]*(TOKEN|PASSWORD|KEY|
SECRET)[A-Z_]*:-`.

## Last triggered (prior): 2026-08-04 — a gitignored backend file meant a
clone without it would silently use local state and plan to recreate all 130
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

## Last triggered: 2026-08-25 — the `python-template` swap (PR #77) was
confirmed against the GitHub API (`template_repository: null`, both rulesets
active, Pages at the original URL, `main` SHA matching the backup) rather than
by re-reading the config that produced it.

## Last triggered (prior): 2026-08-04 — `unifi-mcp` #31/#32/#33 sat approved
and unmerged after the gate went live; PR #40 recorded "apply is blocked" when
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

## Last triggered: 2026-08-25 — two records logged for PR #77 (the archived
exclusion and the `python-template` recreation), and `CLAUDE.md` plus the
`default_branch_ruleset_non_fork_bypass_actors` description were updated in the
same PR that changed the query they describe.

## Last triggered (prior): 2026-08-04 — `CLAUDE.md` documented `stategraph tf`
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
