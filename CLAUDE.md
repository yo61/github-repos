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
- **Archived repos sit outside drift detection.** The `modules/org` query is
  `fork:false archived:false`, so an archived repo with no data file is not
  reported by `check "unmanaged_repos"`. Archiving a repo that *is* managed is
  the trap: its data file keeps being rendered, so the plan proposes
  `archived: true -> false` and tries to un-archive it. Set `archived: true`
  in the data file, and expect writes to its rulesets and collaborators to
  fail — GitHub rejects them on archived repos. See
  `decisions/2026-08-25-exclude-archived-from-drift-detection.md`.

## Merges are gated by CI alone, and an admin can override that

As of `decisions/2026-09-13-admin-override-all-rulesets.md` there is **no
human-approval requirement anywhere in the fleet**, and the repository Admin
role (`RepositoryRole` id 5, `bypass_mode: always`) can bypass **every**
ruleset in both orgs.

lastlight was switched off for cost. It was the only approver, so
`default_branch_ruleset_required_approving_review_count: 1` — then set on
fifteen repos — became unsatisfiable. Both halves of the fix matter:

- **The review counts were dropped**, not merely made bypassable. The counts
  are gone from the data files and fall back to the module default of `0`.
- **The admin bypass was widened** from the `default_branch` ruleset on
  non-forks to every ruleset on every repo, including each repo's
  `required_status_checks`.

### Bypass does not make auto-merge work

This is the trap, and it is why dropping the review counts was necessary
rather than optional. **GitHub's auto-merge ignores bypass actors.** A PR
whose only unmet requirement is one you personally could bypass still sits
`BLOCKED` forever; the bypass lets *you* click merge, it does not let GitHub
merge on your behalf.

Confirmed here on 2026-08-15: `claude-plugin-reportlab-pdf`'s four open
Dependabot PRs were re-armed for auto-merge per
`decisions/2026-08-10-post-apply-pr-reevaluation.md` and all four stayed
`BLOCKED` at `reviews=0` — while the org-wide admin bypass had been live since
2026-07-30. If bot PRs need to merge themselves, the requirement has to be
absent, not bypassable.

### Where the bypass is declared

In `main.tf`, once, as `local.admin_bypass_actors`, fed to both orgs through
two module variables:

- `default_branch_ruleset_bypass_actors` — the built-in `default_branch`
  ruleset. On `yo61` it is concatenated with the semantic-release-pusher
  Integration actor (`3654569`).
- `additional_ruleset_bypass_actors` — defaulted onto every ruleset a repo
  declares under `additional_rulesets`.

Don't restate the actor in a data file. A per-repo
`default_branch_ruleset_bypass_actors` **replaces** the org default rather
than extending it, which is exactly how `homebrew-tap` lost its admin bypass
for two months: PR #25 set `[]` to drop the Integration actor in July, before
the admin role became an org default. That file now names the admin role
explicitly — the one repo where restating it is correct.

To opt a ruleset out, give it `bypass_actors: []` in YAML; an explicitly
declared list, empty or not, is kept verbatim.

### What still binds

Required status checks still run, still report, and still block anyone who is
not a repo admin — including outside contributors. For a maintainer, CI is
advisory. The `default_branch` rules (`deletion`, `non_fast_forward`,
`required_signatures`) are likewise admin-bypassable. Treat the fleet as
having no enforced gate against yourself.

If an approver is ever reintroduced, the review counts must come back with it;
the two only make sense together, per
`decisions/2026-08-06-unifi-mcp-ci-only-gate.md`.

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
