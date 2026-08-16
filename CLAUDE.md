# Project

This repository declaratively manages GitHub repositories across
organizations with Terraform. State is stored in Stategraph (not local
`.tfstate`).

Each managed repo is one YAML file at `data/<org>/<name>.yaml` that records
only its **deviations** from the module defaults. The `modules/github-repo`
module turns each file into a `github_repository` plus its rulesets,
collaborators, and security settings; `modules/org` fans out over an org's
files.

## Repository layout

- `data/<org>/*.yaml` — one file per managed repo (the source of truth);
  `data/<org>/_teams.yaml` is optional per-org metadata, and leading-underscore
  filenames are reserved for it rather than read as repos
- `modules/github-repo/` — the reusable repo module; `variables.tf` lists
  every supported field and its default
- `modules/org/` — iterates an org's `data/` files
- `main.tf`, `providers.tf`, `versions.tf` — root module
- `scripts/` — import and config-generation helpers

## Adding or changing a repo

1. Create or edit `data/<org>/<name>.yaml`. State only what differs from the
   module defaults in `modules/github-repo/variables.tf`.
2. Lint it: `prek run --files <file>` (yamllint + yamlfmt; a hook checks the
   `name:` field matches the filename stem).
3. Open a PR from a feature branch — never commit on `main`.
4. After merge, apply with Stategraph (below).

### Conventions

- **State deviations only.** Don't restate values that already equal the
  module default.
- **New repos omit `create_default_branch`.** It builds a `github_branch`
  resource that needs a source commit, so it fails on a brand-new empty repo;
  `main` is established on the first push. Existing/imported repos may set it.
- **Collaborators use block style:**
  ```yaml
  collaborators:
    users:
      - permission: admin
        username: robinbowes
  ```
- **Private repos on the free-tier personal org:** rulesets and secret
  scanning are paywalled — omit them. Keep `vulnerability_alerts` and
  `dependabot_security_updates`.
- **Teams are optional and per-org.** `data/<org>/_teams.yaml` is a map keyed
  by team slug, each with `description`, `members`, `maintainers`, and an
  optional `privacy` (default `closed`). The key is used verbatim as the team
  name, and GitHub derives the slug from it, so keys must be lowercase and
  hyphenated for the two to agree. Membership is authoritative — a member added
  in the UI is removed on the next apply. A repo grants to a team with
  `collaborators.teams: [{permission: admin, slug: admins}]`; a slug with no
  team in the same org's `_teams.yaml` fails the plan.
- **List a new team's creator under `maintainers`.** GitHub makes whoever
  creates a team its maintainer, so a team whose YAML lists only `members`
  shows a standing diff demoting them. See
  `decisions/2026-08-13-team-member-roles.md`.
- **Team usernames go in lowercase.** `github_team_members` lowercases them
  into state and compares case-sensitively, so `PlanetSeth` under a team is a
  standing diff. This is specific to team membership — `collaborators.users`
  takes GitHub's display case and does not drift.

## The auto-merge policy is waiting on an approval lastlight stopped giving

The review-gated auto-merge policy (`decisions/2026-07-30-reportlab-pdf-automerge-review.md`,
`decisions/2026-08-03-plugin-repos-review-gated-automerge.md`) sets
`default_branch_ruleset_required_approving_review_count: 1` and treats
**lastlight's approval as the "vetted" clause** — the thing that separates a
bot bump from a stranger's PR.

lastlight can approve, and used to. `claude-plugin-reportlab-pdf#18` carries
`yo61-lastlight: APPROVED` dated 2026-07-30, with a review body in the
dependency-assessment agent's own voice ("Trivial and low-risk"), and the
capability is present in `packages/agentic-pi/src/extensions/github/client.ts`
(`pulls.createReview` with `event: "APPROVE"`).

It no longer does so for dependency PRs. The current `dependabot-pr-merge`
workflow (`yo61/lastlight`, `apps/server/workflows/`) runs under a repo-write
profile granting `github_enable_auto_merge`, `github_add_issue_comment`, and
`github_add_labels` — no review tool. Its prompt says it "pre-empts no
review". The router sends dependency PRs to `DEPENDABOTPRMERGE` and reserves
`REVIEW` (the path that does approve) for non-dependency PRs, so a bump never
reaches an approver.

So a green Dependabot PR ends up **armed for auto-merge and one approval
short, forever**. Observed 2026-08-15 across `yo61`: 26 open Dependabot PRs,
all `MERGEABLE` with every check green, auto-merge armed on 21 of them, and
`reviews=0` on all 26 — against a working approval on the same repo two weeks
earlier. Something between 2026-07-30 and 2026-08-11 moved the dependency path
from "approve, then merge" to "arm auto-merge only".

When checking this yourself, **do not use `gh search code` against
`yo61/lastlight`** — it is a fork of `nearform/lastlight`, and GitHub excludes
forks from the code index, so every query returns zero hits whether or not the
code is there. That false negative is what first made this look like a missing
capability rather than a regression. Grep the local clone, or search
`nearform/lastlight`.

Two consequences when reading this repo's config:

- **A repo can be fully compliant with the policy and still never merge a bot
  PR.** `unifictl` has both rulesets, the review count, the required checks,
  and `allow_auto_merge: true` — and five stranded PRs. Compliance is not
  evidence the pipeline works.
- **This is not the stale-verdict failure** from
  `decisions/2026-08-10-post-apply-pr-reevaluation.md`. That one has an
  approval present and a cached blocker, and re-arming auto-merge clears it.
  Here the approval never happened, so toggling auto-merge changes nothing.
  Same symptom, different cause; check `reviews` before reaching for the
  re-arm.

Confirmed empirically on 2026-08-15: after the apply that set
`allow_auto_merge: true` on `claude-plugin-reportlab-pdf`, all four of its
open Dependabot PRs were re-armed per
`decisions/2026-08-10-post-apply-pr-reevaluation.md` and all four stayed
`BLOCKED` at `reviews=0`. The flag was never the binding constraint.

Unresolved — the fix belongs in `yo61/lastlight` (restore approval on the
dependency path) or in this repo (drop the review count and let the no-bypass
status-checks ruleset carry the gate alone). Choosing between those is a
decision, not yet made. Since lastlight approved correctly two weeks ago, the
first is a regression to find rather than a feature to build, which argues for
fixing it there. `yo61/lastlight` is a fork with issues disabled, so nothing
tracks this yet.

## Applying changes

State lives in Stategraph, reached through its **HTTP backend** using the
native `terraform` CLI. The `stategraph` CLI is not used to plan or apply.
Drive everything through the `Taskfile` wrappers (`task --list` shows
everything).

`backend.tf` is a partial configuration: it declares the backend but omits
the address, so both the address and the API key come from the environment.
They live in `.envrc` in this directory, loaded by direnv (`direnv allow`
once per clone):

```bash
export TF_HTTP_ADDRESS="https://app.stategraph.cloud/api/v1/states/backend/<state-uuid>"
export TF_HTTP_PASSWORD="$STATEGRAPH_API_KEY"
```

`.envrc` is machine-specific and untracked. Like editor config, it belongs in
a global ignore (`~/.gitignore`) rather than this repo's `.gitignore`. Any
other way of exporting the two variables works just as well.

```bash
task init    # terraform init                    (once per clone)
task plan    # terraform plan -out tfplan        (read-only)
task apply   # terraform apply tfplan            (only after reviewing the plan)
```

`task plan ORG=<org>` scopes the plan to one org
(`-target=module.org_<org>`, hyphens become underscores). Targeting skips the
excluded org's `check "unmanaged_repos"` and its filename/`name:` validation,
so it is for scoping a known change; unscoped `task plan` stays the default.

Inspect state with `task state:list` (all instance addresses) and
`task state:show REPO=<name>` (one repo's instances). Always review the plan
before applying; plan files can contain sensitive values and are gitignored.

`task` refuses to run if either environment variable is missing. The backend
is unlocked (Stategraph exposes no lock endpoint), so avoid concurrent
applies.

## Git workflow

Feature branch → commit → PR → squash-merge → apply. Use conventional-commit
subjects, e.g. `feat(<org>): add <repo> public repo`.
