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
- **Private repos on a free-plan org:** rulesets and secret scanning are
  paywalled — omit them. Keep `vulnerability_alerts` and
  `dependabot_security_updates`. This applies to every org managed here: all
  three (`yo61`, `ycst-org-uk`, `horopter-dev`) report `plan.name: free`, so
  the rule is not specific to the personal account.
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
- **Topics are authoritative.** `topics:` in a data file is the complete list
  for that repo. The module default is `[]`, so a topic added in the UI is
  removed on the next apply, exactly as with team membership, and an omitted
  key means "no topics" rather than "leave them alone". Add a topic by editing
  the data file. See
  `decisions/2026-09-16-topics-authoritative-empty-default.md`.
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
ruleset in all three orgs.

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

In `main.tf`, once, as `local.admin_bypass_actors`, fed to all three orgs
through two module variables:

- `default_branch_ruleset_bypass_actors` — the built-in `default_branch`
  ruleset. On `yo61` it is concatenated with the semantic-release-pusher
  Integration actor (`3654569`).
- `additional_ruleset_bypass_actors` — defaulted onto every ruleset a repo
  declares under `additional_rulesets`.

Don't restate the actor in a data file. A per-repo
`default_branch_ruleset_bypass_actors` **replaces** the org default rather
than extending it, which is how `yo61/homebrew-tap`'s config spent two months
asking for no bypass at all: PR #25 set `[]` on 2026-07-14 to drop the
Integration actor, and when the admin role became an org default two weeks
later that same `[]` excluded it too. Live had the admin actor anyway — added
out of band — so the config was proposing to remove it on every plan. That
file now names the admin role explicitly, which both keeps #25's exclusion and
matches live.

Restating the actor is correct only where a repo's bypass list must differ
from the org default. There are two such repos: `yo61/homebrew-tap` (above), and
`horopter-dev/homebrew-tap`, which adds the
`horopter-semantic-release-pusher` App (Integration `5196299`) so the release
can push casks straight to `main`. Each file must name the admin role
alongside its own change, or the replacement drops it.

To opt out, match the key to the ruleset — the two are not interchangeable.
For one of a repo's `additional_rulesets`, give that ruleset `bypass_actors:
[]`; an explicitly declared list, empty or not, is kept verbatim. For the
built-in `default_branch` ruleset the key is the top-level
`default_branch_ruleset_bypass_actors: []`.

A top-level `bypass_actors:` is **not** a module input and is dropped without
error. `modules/org/main.tf` forwards only the keys it names, and nothing
validates unknown ones — `scripts/check_repo_yaml_name.sh` checks `name:` and
yamllint has no schema. So that edit looks like it removed an admin bypass from
a security control, and produces no plan diff and no error.

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

State lives in Stategraph and is reached only through the **`stategraph`
CLI**, whose transactions are its concurrency control. There is no backend
block: Stategraph's HTTP backend has no lock endpoint, and native terraform
against it would bypass both the transactions and Stategraph's stored copy
of the configuration. Drive everything through the `Taskfile` wrappers
(`task --list` shows everything). See
`decisions/2026-11-11-stategraph-cli-for-plan-apply.md`.

```bash
task plan    # stategraph tf plan --skip-costs --out tfplan.json   (opens a transaction)
task apply   # stategraph tf apply tfplan.json                     (only after reviewing the plan)
task state:list                  # every instance address, via stategraph sql
task state:show REPO=<name>      # one repo's instances
```

The CLI needs `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY` and
`STATEGRAPH_TENANT_ID` in the environment, and binds to the state named by
the gitignored `stategraph.json`. That file holds the state's **`group_id`**,
not its `id`: `stategraph states list` shows both, and this state's `id`
(`9083e232-…`) appears in no config anywhere. `task` refuses to run if any
variable or the file is missing. No `terraform init` is needed. There is no
`ORG=` scoping: `stategraph tf plan` has no `-target`.

**Never run `terraform init`/`plan`/`apply` here.** With no backend block,
terraform falls back to a local state and plans to create every repo. A clone
that predates the backend's removal still has `.terraform/terraform.tfstate`
caching the old `http` backend, and `terraform init` there offers to migrate
state to a local file; delete that file.

Two behaviours differ from native terraform:

- **`check` warnings appear in `task apply`, not `task plan`.** `check
  "unmanaged_repos"` is silent at plan time (stategraph/releases#5). Terraform
  warnings in general seem to be held back to apply.
- **An unapplied plan leaves its transaction `previewed`.** `tfplan.json`
  holds only its `tx_id`; abort it with `stategraph tx abort --tx <id>` if you
  don't apply.

**Stategraph keeps its own copy of the configuration**, and only its CLI
updates it. After any write that bypassed it, `stategraph tf plan` fails with
"state schema out of date" or plans against stale HCL. Refresh it from the
code that is deployed: `stategraph import tf --hcl --overwrite -y --tenant
"$STATEGRAPH_TENANT_ID" --workspace default`. It replaces only the stored
configuration, not resources; `-y` is needed in a non-interactive shell,
where the y/n prompt otherwise reads as "no".

### State surgery

There is no `terraform state` here; both operations go through the plan:

- **Move** (`state mv`): `stategraph refactor start` / `step` / `complete`,
  which writes the `moved` blocks, or a hand-written `moved` block.
- **Forget** (`state rm`): a `removed` block with
  `lifecycle { destroy = false }`, then `task plan`.

A repo **rename** cannot use `moved` (see `quality/criteria.md`): forget the
old address with `removed` and adopt the new name with an `import` block.
Native terraform rejected an instance-keyed `removed`
(`module.org_yo61.module.repo["x"]`) on 2026-07-30; Stategraph's behaviour
with one is unverified, so read that first plan closely.

Always review the plan before applying; plan files are gitignored.

## Git workflow

Feature branch → commit → PR → squash-merge → apply. Use conventional-commit
subjects, e.g. `feat(<org>): add <repo> public repo`.
