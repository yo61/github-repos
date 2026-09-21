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

## Last triggered: 2026-09-21 — the six adopted `ycst-org-uk` repos (PR #96).
Seventh through twelfth triggers of the free-tier private-repo criterion, and
the first time it applied to repos being *adopted* rather than created: all six
took `builtin_ruleset_names: []` and no `security_and_analysis`, and their
`vulnerability_alerts`/`dependabot_security_updates` were **off live** and are
now on. That is the criterion earning its keep in a direction it had not before
— it usually prevents declaring a paywalled feature; here it added the two
free-tier features that were missing. The deviations-only criterion also drove a
real decision: live `has_projects: true` was *not* restated, so Projects were
switched off on all six to match the org. A new observation worth watching: all
25 `data/yo61` files declare `has_projects: true`, which is a module default
overridden identically 25 times and may mean the default is wrong rather than
the files.

## Last triggered (prior): 2026-09-21 — `infrastructure`, the first repo in the new
`horopter-dev` org (PR #93). Sixth recorded trigger of the free-tier
private-repo criterion, and the first in a third org: `horopter-dev` reports
`plan.name: free` like the other two, so the file takes the established private
shape — `builtin_ruleset_names: []`, no `security_and_analysis`, keeping
`vulnerability_alerts` and `dependabot_security_updates`. The brand-new-repo
criterion kept `create_default_branch` out, so the repo was created empty and
the first push establishes `main`. No `collaborators`: admin comes from org
ownership, as with `horopter`. `visibility: private` was again kept as the
documented exception. Plan was 5 to add — the four repo instances plus the new
org's `terraform_data.validations` — 0 to change, 0 to destroy. The automated
check is still due, and the free-plan invariant now spans three orgs rather
than two, which widens the hard-coding problem that has been deferring it.

## Last triggered (prior): 2026-09-17 — `civicrm-uk-address-cleanup`. Fifth recorded
trigger of the free-tier private-repo criterion, and the first time a file was
moved from one org's shape into the other. It follows `signup_streamline` in
`ycst-org-uk`, with one change: the `collaborators.teams` grant to `admins` was
removed, because `data/yo61/` has no `_teams.yaml`. The `unknown_team_refs`
check in `modules/org/data.tf` would have failed the plan, so no new criterion
is needed. As with `horopter`, admin comes from org ownership. The file keeps
`builtin_ruleset_names: []` and leaves out `create_default_branch` so a local
history can be pushed into the empty repo. Plan was 4 to add, 0 to change, 0 to
destroy. The automated check is still due.

## Last triggered (prior): 2026-09-16 — `civicrm-ycst-theme` (PR #91). Fourth
recorded trigger of the free-tier private-repo criterion, and the first in
`ycst-org-uk` since the threshold was reached. The file takes
`signup_streamline`'s shape — `builtin_ruleset_names: []`, no
`security_and_analysis`, admin through the `admins` team — and the
brand-new-repo criterion kept `create_default_branch` and `auto_init` out,
because a local history already exists to push into the empty repo. Plan was
4 to add, 0 to change, 0 to destroy. The automated check is still due, and
still wants the decision record described below.

## Last triggered (earlier): 2026-09-16 — `horopter-internal` (PR #88). Third
recorded trigger of the free-tier private-repo criterion, which meets this
file's own threshold for promotion to an automated check. The file took the
same shape as `horopter` the day before: `builtin_ruleset_names: []`, no
`additional_rulesets`, no `security_and_analysis`. The invariant now holds
across all eight private files in both orgs, and both orgs report
`plan.name: free`, so a static check is well-founded.

Promotion is deliberately NOT done here. A hook reading `visibility: private`
as implying paywalled features hard-codes the current plan tier and would need
revising the day either org moves to Pro or Team; keying it to the live plan
instead would put a network call in a pre-commit hook. That trade-off wants a
decision record and its own PR, so it is logged as due rather than silently
skipped.

## Last triggered (earlier): 2026-09-15 — `horopter` (PR #87). The free-tier
private-repo criterion shaped the whole file, its second recorded trigger:
`builtin_ruleset_names: []` because the module default `["default_branch"]`
makes the rulesets API return 403 on a private repo in this org, no
`additional_rulesets`, and no `security_and_analysis` — `data.tf:10` computes
secret scanning for `visibility: public` only, so declaring it on a private repo
restates the unmanaged default. The brand-new-repo criterion kept
`create_default_branch` and `auto_init` out, so the repo is created empty and
the first push establishes `main`. `visibility: private` was again kept as the
documented exception below. Plan was 4 to add, 0 to change, 0 to destroy.

## Last triggered (earlier): 2026-08-25 — `helm-charts` (PR #76), twice. First
on the sweep below. Then again in review: the new file declared
`security_and_analysis`, which `data.tf` already supplies for public repos.
It was missed because the criterion named only `variables.tf`, where the
default is `null` — the criterion has been widened to name `data.tf` too.
Six existing public repos (`unifictl`, `kuard`, `go-udap`, `homelab-docs`,
`python-template`, `civi-mcp`) restate the same block and are untouched so
far.

## Last triggered (earlier, same PR): 2026-08-25 — `helm-charts` (PR #76). The
brand-new-repo criterion kept `create_default_branch` out of the file, and the
deviations-only criterion drove a sweep of the existing data: eight files
restated `delete_branch_on_merge: true`, already the module default at
`modules/github-repo/variables.tf:190`. Removing it planned as a no-op —
`modules/org` passes `lookup(..., null)` for an absent key and the child
variable is `nullable = false`, so Terraform substitutes the default.
`commitlint-github-action`'s `delete_branch_on_merge: false` is a real
deviation and was kept. Two `default_branch: main` restatements (`kuard`,
`go-udap`) were found and left for a separate PR.

## Last triggered (earliest): 2026-08-04 — `ycst-admin-docs`. The free-tier
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
    - The `required_status_checks` ruleset carries the org-wide admin bypass
      and nothing else. It is inherited from `additional_ruleset_bypass_actors`
      in `main.tf`, never restated per repo; put `bypass_actors` in a data
      file only to opt one ruleset out with `[]`. Any *other* actor added
      there skips CI too, which is still the thing to avoid.
    - Never expect a bypass actor to make auto-merge work. Auto-merge ignores
      bypasses — a PR whose only unmet requirement is one the merger could
      bypass by hand stays `BLOCKED` indefinitely. To make bot PRs merge
      themselves the requirement must be *absent*, not bypassable.

## Severity: blocking

## Source: `decisions/2026-08-03-ci-baseline-two-tier-policy.md`;
`decisions/2026-07-30-reportlab-pdf-automerge-review.md`; the bypass criteria
rewritten by `decisions/2026-09-13-admin-override-all-rulesets.md`

## Last triggered: 2026-09-13 — the no-bypass criterion was **contradicted**,
not met. lastlight was switched off, leaving `required_approving_review_count:
1` unsatisfiable on fifteen repos, and the chosen fix put an admin bypass on
the status-checks rulesets the criterion protected. Demoted and rewritten
rather than violated silently; see
`decisions/2026-09-13-admin-override-all-rulesets.md` for what was traded. The
auto-merge criterion above was added in the same pass, from the observation
that `claude-plugin-reportlab-pdf`'s four Dependabot PRs stayed `BLOCKED` at
`reviews=0` while the admin bypass was already live.

## Last triggered (prior): 2026-08-25 — `helm-charts` (PR #76) declared no
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
`decisions/2026-09-03-rebase-only-merge-policy.md` adopted rebase-only the
day before, and the live settings matched it. Applying would have undone it.
Added because the existing criteria all assume the managed repo is the side
that drifted.

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

## Last triggered: 2026-09-21 — the `ycst-org-uk` adoption (PR #96), where the
create-vs-exists criterion fired **before** a plan rather than after one, and
found a cause it does not name. `scripts/generate_yo61_configs.sh` emitted
`module.org_${ORG}` verbatim, so `ycst-org-uk` produced
`module.org_ycst-org-uk` — hyphens are invalid in a module label, the import
blocks would not have resolved, and the plan would have proposed creating six
repos that already exist. The criterion sends you to the backend or to a
resource ID that no longer resolves; here it was neither, but a generated
address that was never valid. Widened in spirit: **when a plan proposes creating
what exists, verify the address as well as the backend and the ID.** The fix
also made `ORG` required rather than defaulted, since a default silently
generates the right-shaped blocks for the wrong org.

## Last triggered (prior): 2026-09-21 — the `horopter-dev` transfers (PR #94), where the
two `moved` criteria were **met rather than violated**, and the rename
criterion's scope was confirmed as exact rather than conservative. `horopter`
and `horopter-internal` were transferred between orgs *without* being renamed,
so the resource ID — the repo name — stayed valid, refresh resolved
`horopter-dev/horopter` directly, and two module-instance `moved` blocks
produced 8 moves, 0 to add, 0 to change, 0 to destroy, every one a `no-op`. The
`state rm` plus `import` fallback was pre-authorised and never needed. Two
mechanics worth keeping: one block per *module instance* carries resources a
hand-written list of four would miss, and `previous_address` is the only field
in the plan JSON that evidences a move, since a move is not an action — filter
on `actions != ["no-op"]` alone and eight moves report as "0 changes". See
`decisions/2026-09-21-horopter-dev-org.md`.

## Last triggered (prior): 2026-08-25 — `python-template` (PR #77). Its `template`
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

## Last triggered: 2026-09-21 — the six adopted ycst repos verified against the
GitHub API after apply, not against the data files: `has_projects` false,
`delete_branch_on_merge` true, descriptions and topics set, `admins` team
holding admin, **no direct collaborators left**, and `vulnerability-alerts` 204
plus `automated-security-fixes` true on all six. The outcome-not-config
criterion mattered most on access: the apply removed `PlanetSeth`'s direct
grant, and only
`GET /repos/.../collaborators/PlanetSeth/permission` returning `admin` proves
the team grant actually replaced it rather than simply deleting his access.

## Last triggered (prior): 2026-09-21 — `horopter-dev/infrastructure` confirmed against
the GitHub API after apply (private, issues on, the three topics, description,
`vulnerability-alerts` 204) rather than by re-reading the data file that
produced it. The transfers were verified on both sides before planning — the
repos resolving directly under the new owner, their security settings intact —
and afterwards with `terraform state list`, which also confirmed the negative:
nothing left under `module.org_yo61`. A move leaves no trace in apply output
(`0 added, 0 changed, 0 destroyed` is what success looks like), so the state
listing is the only evidence it happened.

## Last triggered (prior): 2026-08-25 — the `python-template` swap (PR #77) was
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

## Last triggered: 2026-09-21 — `decisions/2026-09-21-horopter-dev-org.md`
logged for the third org, and three stale org-count claims corrected in the same
PR that made them false: `CLAUDE.md` said the admin bypass covered "both orgs"
and was "fed to both orgs", and the `local.admin_bypass_actors` comment in
`main.tf` said "in both orgs". A fourth correction came with them —
`CLAUDE.md`'s free-tier convention was scoped to "the free-tier personal org"
when the paywall applies to all three, none of which is a personal account
except `yo61`. The existing-decisions criterion fired before any code was
written: `2026-08-13-ycst-org-uk-migration.md` supplied the whole transfer
procedure, and reading it closely is what showed its `moved` conclusion was
scoped to *renames* rather than to transfers — new information that narrowed a
prior decision rather than invalidating it.

## Last triggered (prior): 2026-08-25 — two records logged for PR #77 (the archived
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
