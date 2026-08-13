# `ycst-org-uk` Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manage the `ycst-org-uk` GitHub organisation from this repository,
grant admin on its repos through an `admins` team, and move the two `ycst-*`
repos out of `yo61` into it without destroying and recreating them.

**Architecture:** `modules/org` gains optional team support driven by a new
`data/<org>/_teams.yaml`, and passes the resulting team IDs into each repo so
Terraform orders team creation before the grant that needs it. The root module
gains a second aliased provider and a second `modules/org` call. The repos
themselves are transferred and renamed out of band with `gh api`, then their
state instances are carried to the new addresses with `moved` blocks — verified
by experiment to work across provider aliases and renamed `for_each` keys under
the native Terraform CLI.

**Tech Stack:** Terraform 1.15.x, `integrations/github` 6.13.0, Stategraph HTTP
backend via the native `terraform` CLI, Task, prek (yamllint, yamlfmt,
terraform_fmt/validate/docs), `gh`.

**Spec:** `docs/superpowers/specs/2026-08-12-ycst-org-uk-migration-design.md`

## Global Constraints

- Both orgs are on GitHub's **free** plan. Rulesets and classic branch
  protection 403 on private repos. Every `ycst-org-uk` repo file keeps
  `builtin_ruleset_names: []` and gains no review-count or required-checks
  gate.
- `data/<org>/*.yaml` states **deviations only** from
  `modules/github-repo/variables.tf` defaults. Two deliberate exceptions carry
  over from the existing files: `visibility: private` and `auto_init: true`.
- Leading-underscore filenames in `data/<org>/` are reserved metadata.
  `modules/org/data.tf:12-15` already excludes them from `repo_files` and
  `scripts/check_repo_yaml_name.sh:10-13` already skips them.
- Terraform is invoked from the repo root; `file()`/`fileset()`/`fileexists()`
  paths in `modules/org` are repo-root-relative, not `path.module`-relative.
- `TF_HTTP_ADDRESS` / `TF_HTTP_PASSWORD` come from `.envrc`; the Bash tool does
  not load direnv, so every `task` invocation is prefixed
  `direnv exec . task …`.
- Never `git push` to `main`. Feature branch → PR → squash-merge → apply.
- Never commit `tfplan`.

## Corrections to the spec

Three points where implementation reality differs from the design doc. Each is
applied in the task that hits it; the spec is not edited.

1. **PR 1's apply creates three resources, not two.** `modules/org` contains
   `terraform_data.validations`, which is a managed resource — confirmed in
   state as `module.org_yo61.terraform_data.validations`. A new org module
   instance therefore adds it alongside `github_team.this["admins"]` and
   `github_team_members.this["admins"]`.
2. **PR 3's plan carries two collaborator changes, not one.** The design gates
   on `board-docs` swapping `PlanetSeth`'s direct grant for the team grant.
   `website-testing` also changes: verified live 2026-08-13, its only
   collaborator is `robinbowes` (via org ownership) and it has no team, so its
   `github_repository_collaborators.this` goes from empty to one `team` block.
3. **`privacy` defaults to `closed` in the module, and `_teams.yaml` omits
   it.** The design fixes `privacy: closed` for `admins` and exposes the field
   as optional. Putting the default in `modules/org/teams.tf` rather than the
   YAML follows this repo's deviations-only convention, and makes `closed` the
   default for every future access-granting team.

## File Structure

**Created:**

| File | Responsibility |
| --- | --- |
| `modules/org/teams.tf` | `github_team` + `github_team_members` per `_teams.yaml` key |
| `data/ycst-org-uk/_teams.yaml` | The `admins` team and its members |
| `data/ycst-org-uk/board-docs.yaml` | Task 6 — moved from `data/yo61/ycst-admin-docs.yaml` |
| `data/ycst-org-uk/website-testing.yaml` | Task 6 — moved from `data/yo61/ycst-website-testing.yaml` |
| `decisions/2026-08-13-ycst-org-uk-migration.md` | Decision record (Task 9) |

**Modified:**

| File | Change |
| --- | --- |
| `modules/org/data.tf` | Load `_teams.yaml`; add the unknown-slug precondition |
| `modules/org/main.tf` | Pass `team_ids` into `module.repo` |
| `providers.tf` | Second aliased `github` provider |
| `main.tf` | Second `modules/org` call; `moved` blocks (Task 6, removed Task 9) |
| `Taskfile.yaml` | `org-guard` task; `ORG=` targeting on `plan` |
| `CLAUDE.md` | Document `ORG=` and `_teams.yaml` |
| `quality/criteria.md` | Amend the `moved`/`removed` criterion (Task 9) |

**Deleted:** `data/yo61/ycst-admin-docs.yaml`, `data/yo61/ycst-website-testing.yaml` (Task 6).

---

## Task 1: Team support in `modules/org`

**Files:**
- Create: `modules/org/teams.tf`
- Modify: `modules/org/data.tf:1-27` (locals), `modules/org/data.tf:47-54` (preconditions)
- Modify: `modules/org/main.tf:67-68` (add `team_ids` argument)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `local.teams` — `map(object)` keyed by team slug, `{}` when the org
  has no `_teams.yaml`. `github_team.this` / `github_team_members.this` — both
  `for_each`ed over `local.teams`. `local.unknown_team_refs` — `list(string)`
  of `"<repo>: <slug>"` for slugs a repo grants to that no managed team
  provides. Task 2's `data/ycst-org-uk/_teams.yaml` is the input format defined
  here; Task 6's repo YAML uses the `collaborators.teams` grant this enables.

- [ ] **Step 1: Load `_teams.yaml` in `modules/org/data.tf`**

Add to the first `locals` block, after `data_dir` and before `repo_files`
(the `_` exclusion comment on `repo_files` can drop its "in the future"):

```hcl
  # Optional per-org metadata. Absent file means the org manages no teams, so
  # its existing teams are left alone rather than adopted or destroyed.
  teams_file = "${local.data_dir}/_teams.yaml"
  teams      = fileexists(local.teams_file) ? yamldecode(file(local.teams_file)) : {}
```

- [ ] **Step 2: Add the unknown-slug local to `modules/org/data.tf`**

Add to the `locals` block at lines 39-43 (the one holding `configured_names`):

```hcl
  # Team slugs a repo grants to that this org does not manage. Without this
  # check the `lookup(var.team_ids, slug, slug)` fallback in
  # modules/github-repo/main.tf sends the bare slug to the API, and a typo
  # surfaces as an opaque apply-time error instead of a named plan failure.
  unknown_team_refs = flatten([
    for name, collab in local.collaborators : [
      for team in lookup(collab, "teams", []) : "${name}: ${team.slug}"
      if !contains(keys(local.teams), team.slug)
    ]
  ])
```

`local.collaborators` is defined in `modules/org/main.tf:11-14`; locals are
module-scoped, so the cross-file reference is fine.

- [ ] **Step 3: Add the second precondition to `terraform_data.validations`**

In `modules/org/data.tf`, inside the existing `lifecycle` block, after the
`name_mismatches` precondition:

```hcl
    precondition {
      condition     = length(local.unknown_team_refs) == 0
      error_message = "Org ${var.org}: repos grant to team slugs absent from ${local.teams_file}: ${jsonencode(local.unknown_team_refs)}"
    }
```

- [ ] **Step 4: Create `modules/org/teams.tf`**

```hcl
# Org teams from data/<org>/_teams.yaml, keyed by slug. The map key is the team
# name; GitHub derives the slug from it, so keys must be lowercase and
# hyphenated for the two to agree. Repo YAML references teams by that slug.
resource "github_team" "this" {
  for_each = local.teams

  name        = each.key
  description = lookup(each.value, "description", null)

  # Closed teams are visible to org members, which suits a team whose purpose
  # is granting access. The provider default is `secret`.
  privacy = lookup(each.value, "privacy", "closed")
}

# Authoritative, matching this repo's "the YAML is the source of truth" posture:
# a member added through the GitHub UI is removed on the next apply. Role is
# left at the provider default (`member`); org owners already administer their
# own teams.
resource "github_team_members" "this" {
  for_each = local.teams

  team_id = github_team.this[each.key].id

  dynamic "members" {
    for_each = toset(lookup(each.value, "members", []))
    content {
      username = members.value
    }
  }
}
```

- [ ] **Step 5: Pass `team_ids` into `module.repo`**

In `modules/org/main.tf`, insert between `squash_merge_commit_title` (line 67)
and `template` (line 68), keeping the alphabetical argument order:

```hcl
  team_ids = { for slug, team in github_team.this : slug => team.id }
```

Then replace the stale comment at `modules/github-repo/main.tf:161-162`:

```hcl
    # team_ids carries the id for a slug. Passing the id rather than the slug is
    # a dependency edge, not an optimisation: it is what makes terraform create
    # a team before granting a repo to it. The fallback covers a slug naming a
    # team this repository does not manage.
```

- [ ] **Step 6: Format and validate**

```bash
terraform fmt -recursive
direnv exec . terraform validate
```

Expected: `Success! The configuration is valid.` `terraform validate` needs the
existing `.terraform/`; if it complains about initialisation, run
`direnv exec . task init` first.

- [ ] **Step 7: Confirm `yo61` is unaffected**

```bash
direnv exec . task plan
```

Expected: `No changes.` — `yo61` has no `_teams.yaml`, so `local.teams` is
`{}`, `github_team.this` has no instances, and `team_ids` is `{}`, which is the
variable's existing default. `yo61`'s live `owners` and `ubnt` teams stay
unmanaged. Anything other than "No changes" means the empty-map path is not
degrading cleanly — stop and diagnose.

- [ ] **Step 8: Lint and commit**

```bash
prek run --files modules/org/teams.tf modules/org/data.tf modules/org/main.tf modules/github-repo/main.tf
git add modules/org/teams.tf modules/org/data.tf modules/org/main.tf modules/github-repo/main.tf
git commit -m "feat(org): manage teams from data/<org>/_teams.yaml"
```

If `terraform_docs` rewrites `modules/github-repo/README.md`, include it in the
commit.

---

## Task 2: Wire up the `ycst-org-uk` org

**Files:**
- Modify: `providers.tf` (append)
- Modify: `main.tf` (append)
- Create: `data/ycst-org-uk/_teams.yaml`

**Interfaces:**
- Consumes: `local.teams` and the two resources from Task 1.
- Produces: `module.org_ycst_org_uk` — the module address every later task
  targets, and the `to` side of Task 6's `moved` blocks. Provider alias
  `github.ycst_org_uk`.

- [ ] **Step 1: Add the provider alias**

Append to `providers.tf`:

```hcl
provider "github" {
  alias = "ycst_org_uk"
  owner = "ycst-org-uk"
}
```

- [ ] **Step 2: Add the org module call**

Append to `main.tf`:

```hcl
module "org_ycst_org_uk" {
  source = "./modules/org"

  org = "ycst-org-uk"

  providers = {
    github = github.ycst_org_uk
  }
}
```

No `default_branch_ruleset_*` arguments: both repos are private on a free org,
so `builtin_ruleset_names: []` leaves no ruleset for a bypass actor to attach
to. `yo61`'s `Integration` bypass actor (`actor_id = 3654569`) is not carried
over.

- [ ] **Step 3: Create `data/ycst-org-uk/_teams.yaml`**

```yaml
---
admins:
  description: Administrators for York City Supporters Trust repositories
  members:
    - robinbowes
    - PlanetSeth
```

`privacy` is omitted — `modules/org/teams.tf` defaults it to `closed`.

- [ ] **Step 4: Format, validate, and lint**

```bash
terraform fmt -recursive
direnv exec . terraform validate
prek run --files providers.tf main.tf data/ycst-org-uk/_teams.yaml
```

Expected: all pass. `scripts/check_repo_yaml_name.sh` skips `_teams.yaml`
because its basename starts with `_`; if it reports a missing `name:` field,
the hook's `files:` pattern or the script's `_*` case has regressed — fix that
before continuing.

- [ ] **Step 5: Commit**

```bash
git add providers.tf main.tf data/ycst-org-uk/_teams.yaml
git commit -m "feat(ycst-org-uk): add the org and its admins team"
```

---

## Task 3: Per-org plan targeting

**Files:**
- Modify: `Taskfile.yaml:58-62` (the `plan` task) and a new `org-guard` task
- Modify: `CLAUDE.md` (the "Applying changes" and "Conventions" sections)

**Interfaces:**
- Consumes: `module.org_ycst_org_uk` from Task 2 — `ORG=ycst-org-uk` renders
  `-target=module.org_ycst_org_uk`.
- Produces: `task plan ORG=<org>`, used by Task 4's apply.

- [ ] **Step 1: Add the `org-guard` task**

Insert into `Taskfile.yaml` after `preflight` and before `init`:

```yaml
  # An unmatched -target is only a soft warning, and the resulting empty plan
  # reads like "nothing to do". Fail on a slug with no data directory instead.
  org-guard:
    internal: true
    silent: true
    cmds:
      - |
        if [ -n "{{.ORG}}" ] && [ ! -d "data/{{.ORG}}" ]; then
          echo "ERROR: no data/{{.ORG}} directory; ORG must name a managed org." >&2
          exit 1
        fi
```

- [ ] **Step 2: Add targeting to `plan`**

Replace the `plan` task:

```yaml
  plan:
    desc: Generate a plan file via `terraform plan` (ORG=<org> scopes it to one org)
    deps: [preflight, org-guard]
    vars:
      TARGET: '{{if .ORG}}-target=module.org_{{.ORG | replace "-" "_"}}{{end}}'
    cmds:
      - terraform plan -out={{.PLAN_FILE}} {{.TARGET}}
```

`apply` is unchanged: a saved plan file carries its own targeting.

- [ ] **Step 3: Verify the templating without touching the backend**

```bash
direnv exec . task --dry plan ORG=ycst-org-uk
direnv exec . task --dry plan
```

Expected: the first prints `terraform plan -out=tfplan -target=module.org_ycst_org_uk`;
the second prints `terraform plan -out=tfplan` with no `-target`. If the second
prints `<no value>` or a bare `-target=module.org_`, the `{{if .ORG}}` guard is
not seeing an undefined var as empty — replace the condition with
`{{if ne .ORG ""}}` and add `ORG: ''` to the task's `vars`, then re-run both.

- [ ] **Step 4: Verify the guard rejects an unknown org**

```bash
direnv exec . task plan ORG=not-an-org
```

Expected: exits non-zero with
`ERROR: no data/not-an-org directory; ORG must name a managed org.` and no
`terraform plan` runs.

- [ ] **Step 5: Update `CLAUDE.md`**

In the "Applying changes" section, after the `task init/plan/apply` code block,
add:

```markdown
`task plan ORG=<org>` scopes the plan to one org
(`-target=module.org_<org>`, hyphens become underscores). Targeting skips the
excluded org's `check "unmanaged_repos"` and its filename/`name:` validation,
so it is for scoping a known change; unscoped `task plan` stays the default.
```

In the "Repository layout" section, extend the `data/<org>/*.yaml` bullet:

```markdown
- `data/<org>/*.yaml` — one file per managed repo (the source of truth);
  `data/<org>/_teams.yaml` is optional per-org metadata, and leading-underscore
  filenames are reserved for it rather than read as repos
```

In "Conventions", add:

```markdown
- **Teams are optional and per-org.** `data/<org>/_teams.yaml` is a map keyed
  by team slug, each with `description`, `members`, and an optional `privacy`
  (default `closed`). Membership is authoritative — a member added in the UI is
  removed on the next apply. A repo grants to a team with
  `collaborators.teams: [{permission: admin, slug: admins}]`; a slug with no
  team in the same org's `_teams.yaml` fails the plan.
```

- [ ] **Step 6: Lint and commit**

```bash
prek run --files Taskfile.yaml CLAUDE.md
git add Taskfile.yaml CLAUDE.md
git commit -m "feat: scope task plan to one org with ORG="
```

---

## Task 4: Ship and apply PR 1

**Files:** none — this task is review, merge, apply, and verification.

**Interfaces:**
- Consumes: Tasks 1-3, all committed on `feat/ycst-org-uk-migration`.
- Produces: a live `ycst-org-uk/admins` team with two members, and
  `module.org_ycst_org_uk.terraform_data.validations` in state. Task 6's team
  grant depends on the team existing.

- [ ] **Step 1: Confirm the branch and push**

```bash
git branch --show-current   # must not be main
git push -u origin feat/ycst-org-uk-migration
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --title "feat: manage ycst-org-uk and its admins team" --body "$(cat <<'EOF'
Adds team support to `modules/org`, wires up the `ycst-org-uk` org, and lets
`task plan` scope to a single org.

`modules/org` reads an optional `data/<org>/_teams.yaml` and creates one
`github_team` plus one authoritative `github_team_members` per key, passing the
resulting IDs into each repo so a team is created before a repo grants to it. A
plan-time precondition fails on a team slug no managed team provides. An org
without the file manages no teams.

`data/ycst-org-uk/` holds only `_teams.yaml`; the two repos move in a later PR,
after they are transferred on GitHub.

`task plan ORG=<org>` renders `-target=module.org_<org>` and refuses a slug with
no data directory. Targeting skips the excluded org's drift detection, so
unscoped `task plan` stays the default.

Design: `docs/superpowers/specs/2026-08-12-ycst-org-uk-migration-design.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Wait for CI, then squash-merge**

```bash
gh pr checks --watch
gh pr merge --squash --delete-branch
git checkout main && git pull
```

- [ ] **Step 4: Plan the apply, scoped to the new org**

```bash
direnv exec . task plan ORG=ycst-org-uk
```

Expected: **3 to add, 0 to change, 0 to destroy** —
`module.org_ycst_org_uk.github_team.this["admins"]`,
`module.org_ycst_org_uk.github_team_members.this["admins"]` with two `members`
blocks, and `module.org_ycst_org_uk.terraform_data.validations`. Any destroy,
or any `module.org_yo61.*` address in the plan, means the targeting did not
hold — stop and diagnose.

- [ ] **Step 5: Apply**

```bash
direnv exec . task apply
```

- [ ] **Step 6: Verify the team exists with both members**

```bash
gh api /orgs/ycst-org-uk/teams --jq '.[] | {slug, privacy}'
gh api /orgs/ycst-org-uk/teams/admins/members --jq '.[].login'
```

Expected: one team, `slug: admins`, `privacy: closed`; members `robinbowes` and
`PlanetSeth`.

- [ ] **Step 7: Confirm both orgs plan clean unscoped**

```bash
direnv exec . task plan
```

Expected: `No changes.` with no unmanaged-repo warning. `ycst-org-uk` has no
repos yet and `data/ycst-org-uk/` has no repo files, so the two sets match.

---

## Task 5: Transfer and rename the repos on GitHub

**Files:** none — Terraform cannot do this. `github_repository` takes its owner
from the provider, so the move happens on GitHub first.

**Interfaces:**
- Consumes: the `admins` team from Task 4 (not required by the transfer, but
  the team must exist before Task 7's apply grants to it).
- Produces: `ycst-org-uk/board-docs` and `ycst-org-uk/website-testing`, the
  repos Task 6's `moved` blocks point at.

**Do not start this task until Task 6's PR is open and reviewed.** The design's
ordering is: prepare and review PR 3 → transfer → merge → plan and apply, with
no apply in between. Merging Task 6 *before* the transfer creates a window
where the plan proposes to **create** `ycst-org-uk/board-docs`; applying that
leaves an empty repo whose name then blocks the real transfer.

- [ ] **Step 1: Re-confirm the starting state**

```bash
gh api /repos/yo61/ycst-admin-docs --jq .full_name
gh api /repos/yo61/ycst-website-testing --jq .full_name
```

Expected: `yo61/ycst-admin-docs` and `yo61/ycst-website-testing`.

- [ ] **Step 2: Record what must survive the transfer**

```bash
gh api /repos/yo61/ycst-admin-docs/actions/secrets --jq '.secrets[].name'
gh api /repos/yo61/ycst-admin-docs/environments --jq '.environments[].name'
for env in production staging; do
  echo "== $env"
  gh api "/repos/yo61/ycst-admin-docs/environments/$env/secrets" --jq '.secrets[].name'
done
gh api /repos/yo61/ycst-admin-docs/environments/production \
  --jq '.deployment_branch_policy'
```

Expected, per the 2026-08-12 inventory: repo secrets `SSH_HOST`,
`SSH_KNOWN_HOSTS`, `SSH_PORT`, `SSH_PRIVATE_KEY`, `SSH_USER`; environments
`production` and `staging`, each with `DEPLOY_ROOT`, `GATE_PATH`,
`SMOKE_PASSWORD`, `SMOKE_USER`, `WP_LOAD_PATH`; a custom deployment-branch
policy on `production`. `ycst-website-testing` has none of these. Save the
output — it is the baseline Step 5 compares against.

- [ ] **Step 3: Transfer both repos**

```bash
gh api -X POST /repos/yo61/ycst-admin-docs/transfer \
  -f new_owner=ycst-org-uk -f new_name=board-docs
gh api -X POST /repos/yo61/ycst-website-testing/transfer \
  -f new_owner=ycst-org-uk -f new_name=website-testing
```

`202 Accepted` is asynchronous.

- [ ] **Step 4: Confirm both landed before planning anything**

```bash
gh api /orgs/ycst-org-uk/repos --jq '.[].full_name'
gh api /repos/yo61/ycst-admin-docs --jq .full_name
```

Expected: the org lists `ycst-org-uk/board-docs` and
`ycst-org-uk/website-testing`; the old path redirects and reports
`ycst-org-uk/board-docs`. Re-run until both hold — do not proceed on a
`404` or on a name still under `yo61`.

- [ ] **Step 5: Verify secrets and environments survived**

Re-run Step 2's commands against `ycst-org-uk/board-docs` and diff against the
saved baseline. GitHub documents that webhooks, secrets, and deploy keys remain
associated but says nothing about environments or their secrets, so these are
checked rather than assumed. A missing environment secret must be re-created by
hand before the next deploy — it is not in Terraform and no plan will show it.

- [ ] **Step 6: Point the local clones at the new paths**

The working directories were relocated to `~/code/github.com/ycst-org-uk/` ahead
of the transfer, but still carry the old repo names and `yo61` remotes. Nothing
in this repository reads them; leaving them stale just means `git remote -v`
disagrees with reality while redirects quietly cover for it.

```bash
cd ~/code/github.com/ycst-org-uk
for pair in "ycst-admin-docs board-docs" "ycst-website-testing website-testing"; do
  set -- $pair
  git -C "$1" status --porcelain | head -1   # must be empty
  mv "$1" "$2"
  git -C "$2" remote set-url origin "https://github.com/ycst-org-uk/$2.git"
  git -C "$2" fetch origin
done
```

Expected: both `fetch` calls succeed against the new URLs. Do not `mv` a clone
with uncommitted work — commit or stash it first.

---

## Task 6: Move config and state together

**Files:**
- Create: `data/ycst-org-uk/board-docs.yaml`
- Create: `data/ycst-org-uk/website-testing.yaml`
- Delete: `data/yo61/ycst-admin-docs.yaml`, `data/yo61/ycst-website-testing.yaml`
- Modify: `main.tf` (append two `moved` blocks)

**Interfaces:**
- Consumes: `module.org_ycst_org_uk` (Task 2), the `admins` team (Task 4), and
  the transferred repos (Task 5).
- Produces: the four state instances per repo at their new addresses:
  `module.org_ycst_org_uk.module.repo["board-docs"].github_repository.this`,
  `.github_repository_collaborators.this`,
  `.github_repository_dependabot_security_updates.this["this"]`,
  `.github_repository_vulnerability_alerts.this["this"]`, and the same four for
  `website-testing`. Task 9 deletes the `moved` blocks once spent.

- [ ] **Step 1: Branch from a merged, applied `main`**

```bash
git checkout main && git pull
git checkout -b feat/ycst-repos-to-ycst-org-uk
```

- [ ] **Step 2: Move the two data files**

```bash
git mv data/yo61/ycst-admin-docs.yaml data/ycst-org-uk/board-docs.yaml
git mv data/yo61/ycst-website-testing.yaml data/ycst-org-uk/website-testing.yaml
```

- [ ] **Step 3: Rewrite `data/ycst-org-uk/board-docs.yaml`**

```yaml
---
builtin_ruleset_names: []
collaborators:
  teams:
    - permission: admin
      slug: admins
dependabot_security_updates: true
description: "Board admin hub and docs for York City Supporters Trust."
has_issues: true
homepage_url: https://admin.ycst.org.uk
name: board-docs
visibility: private
vulnerability_alerts: true
```

`PlanetSeth`'s direct user grant is replaced by the team grant. `auto_init` is
absent, as it was on the original file — the repo was created empty for its
first push.

- [ ] **Step 4: Rewrite `data/ycst-org-uk/website-testing.yaml`**

```yaml
---
auto_init: true
builtin_ruleset_names: []
collaborators:
  teams:
    - permission: admin
      slug: admins
dependabot_security_updates: true
has_issues: true
name: website-testing
visibility: private
vulnerability_alerts: true
```

`auto_init: true` only has meaning at creation, but it is in state; dropping it
would show a diff for no behavioural change.

- [ ] **Step 5: Add the `moved` blocks to `main.tf`**

Append:

```hcl
# One block per repo carries all four of that repo's instances. Verified by
# experiment: a single `moved` handles both the provider-alias change and the
# renamed for_each key, preserving the resource ID. Deleted once applied.
moved {
  from = module.org_yo61.module.repo["ycst-admin-docs"]
  to   = module.org_ycst_org_uk.module.repo["board-docs"]
}

moved {
  from = module.org_yo61.module.repo["ycst-website-testing"]
  to   = module.org_ycst_org_uk.module.repo["website-testing"]
}
```

- [ ] **Step 6: Format, validate, lint**

```bash
terraform fmt -recursive
direnv exec . terraform validate
prek run --files main.tf data/ycst-org-uk/board-docs.yaml data/ycst-org-uk/website-testing.yaml
```

Expected: all pass, including `repo-yaml-name-check` — each file's `name:`
matches its new stem.

- [ ] **Step 7: Commit and open the PR, but do not merge**

```bash
git add -A
git commit -m "feat(ycst-org-uk): move the two ycst repos out of yo61"
git push -u origin feat/ycst-repos-to-ycst-org-uk
gh pr create --title "feat(ycst-org-uk): move the two ycst repos out of yo61" --body "$(cat <<'EOF'
Moves `ycst-admin-docs` and `ycst-website-testing` from `yo61` to
`ycst-org-uk` as `board-docs` and `website-testing`, and swaps `PlanetSeth`'s
direct admin grant for the `admins` team on both.

The repos are transferred and renamed on GitHub before this merges;
`github_repository` takes its owner from the provider, so Terraform cannot do
the move. One `moved` block per repo carries all four of its state instances
across the provider alias and the renamed `for_each` key.

Merge only after the transfer has landed. The plan must be unscoped — a
cross-org `moved` block cannot be targeted to one side.

Design: `docs/superpowers/specs/2026-08-12-ycst-org-uk-migration-design.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Then go do Task 5. Return here only once both repos resolve under
`ycst-org-uk`.

---

## Task 7: Apply the move

**Files:** none.

**Interfaces:**
- Consumes: Task 6's PR, Task 5's completed transfer.
- Produces: the eight state instances living under `module.org_ycst_org_uk`.

- [ ] **Step 1: Merge**

```bash
gh pr checks --watch
gh pr merge --squash --delete-branch
git checkout main && git pull
```

- [ ] **Step 2: Plan, unscoped**

```bash
direnv exec . task plan
```

**This plan must be unscoped.** `-target` on either org errors with
`Moved resource instances excluded by targeting`, and naming both modules is
equivalent to not targeting.

- [ ] **Step 3: Gate on the plan before applying**

Expected, and nothing else:

- **zero destroys**;
- eight `moved` lines — four instances per repo, each
  `module.org_yo61.module.repo[…]` → `module.org_ycst_org_uk.module.repo[…]`;
- **two** changes, both `github_repository_collaborators.this`:
  `board-docs` dropping `PlanetSeth`'s `user` block for a `team` block, and
  `website-testing` gaining its first `team` block. (The design names only
  `board-docs`; `website-testing` had no collaborators block at all, verified
  live 2026-08-13.)

Stop and diagnose on any of: a destroy; a create for either repo (the transfer
did not land, or `main` was applied before it); a change to
`github_repository.this.name` or a `404` during refresh (the rename redirect is
not resolving for the provider); a plan touching any other `yo61` repo.

- [ ] **Step 4: Apply**

```bash
direnv exec . task apply
```

- [ ] **Step 5: Verify the state addresses moved**

```bash
direnv exec . terraform state list | rg 'board-docs|website-testing|ycst'
```

Expected: eight instances, all under `module.org_ycst_org_uk`, none under
`module.org_yo61`, and no `ycst-admin-docs` / `ycst-website-testing` keys left.

- [ ] **Step 6: Verify the team grant took effect**

```bash
gh api /repos/ycst-org-uk/board-docs/collaborators/PlanetSeth/permission --jq .permission
gh api /repos/ycst-org-uk/website-testing/collaborators/PlanetSeth/permission --jq .permission
gh api /repos/ycst-org-uk/board-docs/teams --jq '.[] | {slug, permission}'
gh api /repos/ycst-org-uk/website-testing/teams --jq '.[] | {slug, permission}'
```

Expected: `admin` on both, and `admins` holding `admin` on both. The permission
endpoint reports the effective permission whatever its source, so the `teams`
call is what proves it now comes from the team.

- [ ] **Step 7: Verify the deploy path still works**

Trigger `board-docs`'s deploy workflow and confirm it reaches Krystal cPanel and
that `https://admin.ycst.org.uk` still serves. This exercises the repo secrets,
the environment secrets, and `production`'s deployment-branch policy in one go —
the things the transfer moved that Terraform never sees. `board-docs` also lost
the `yo61-lastlight` reviewer: GitHub App installations do not transfer and
none are being reinstalled, so review on that repo is human-only from here.

- [ ] **Step 8: Confirm both orgs plan clean**

```bash
direnv exec . task plan
```

Expected: `No changes.` and no unmanaged-repo warning from either org —
`yo61`'s configured set no longer names the two repos, and `ycst-org-uk`'s now
does.

---

## Task 8: Retire the spent `moved` blocks and record the outcome

**Files:**
- Modify: `main.tf` (delete both `moved` blocks)
- Modify: `quality/criteria.md:116-118`
- Create: `decisions/2026-08-13-ycst-org-uk-migration.md`

**Interfaces:**
- Consumes: Task 7's applied state.
- Produces: nothing later depends on this.

- [ ] **Step 1: Branch and delete the `moved` blocks**

```bash
git checkout main && git pull
git checkout -b chore/retire-ycst-moved-blocks
```

Delete both `moved` blocks from `main.tf`, including the comment above them.

- [ ] **Step 2: Amend the `quality/criteria.md` criterion**

Under "Category: Plan and apply discipline", replace:

```markdown
    - An instance address change produces destroy+create. Stategraph ignores
      HCL `moved`/`removed` blocks and has no `state mv`/`rm`. Confirm that
      is intended before applying.
```

with:

```markdown
    - An instance address change needs a `moved` block, and its plan must show
      the move rather than a destroy+create. Under the native CLI against the
      HTTP backend, `moved` is honoured — including across provider aliases and
      renamed `for_each` keys, in one block. `removed` blocks reject instance
      keys, so a subset of a `for_each` cannot be forgotten declaratively. The
      retired `stategraph tf` wrapper ignored both.
```

Update that category's `Last triggered` line to name this migration and the
date.

- [ ] **Step 3: Write the decision record**

Create `decisions/2026-08-13-ycst-org-uk-migration.md` with all six headings —
Decision, Context, Alternatives considered, Reasoning, Trade-offs accepted,
Supersedes. Content to cover:

- **Decision:** manage `ycst-org-uk` as a second org from this repo; grant
  admin through an `admins` team rather than named users; transfer the two
  repos out of band and carry their state with `moved` blocks.
- **Context:** `ycst-admin-docs` and `ycst-website-testing` are York City
  Supporters Trust assets living in a personal org, with a second admin named
  as a user collaborator.
- **Alternatives considered:** a fully declarative forget-and-reimport
  (impossible — `removed` rejects instance keys); destroy and recreate (loses
  issues, secrets, and history); separate Stategraph state per org; keeping
  named-user collaborators.
- **Reasoning:** `moved` works under the native CLI; team grants scale to more
  than one trustee; billing for Actions minutes moves to the trust's own org.
- **Trade-offs accepted:** one Stategraph state still spans both orgs, so
  `ORG=` targeting warns rather than isolates; `board-docs` loses the
  `yo61-lastlight` reviewer because App installations do not transfer, leaving
  the manual review gate in
  `decisions/2026-08-10-private-repos-manual-review-gate.md` human-only;
  `yo61`'s existing `owners` and `ubnt` teams stay unmanaged.
- **Supersedes:** none. Amends
  `decisions/2026-08-04-ycst-admin-docs-private-cpanel.md` only in that the
  repo now lives at `ycst-org-uk/board-docs`; that record's private-visibility
  reasoning stands. Add a line to that file pointing here.

- [ ] **Step 4: Update the design doc status**

In `docs/superpowers/specs/2026-08-12-ycst-org-uk-migration-design.md`, change
`Status: Design, pending implementation plan` to
`Status: Implemented 2026-08-13; see decisions/2026-08-13-ycst-org-uk-migration.md`.

- [ ] **Step 5: Confirm deleting the blocks changes nothing**

```bash
terraform fmt -recursive
direnv exec . terraform validate
direnv exec . task plan
```

Expected: `No changes.` A spent `moved` block is a no-op, so removing it must
not produce a diff. If it does, the move did not fully land — stop.

- [ ] **Step 6: Lint, commit, PR, merge**

```bash
prek run --files main.tf quality/criteria.md decisions/2026-08-13-ycst-org-uk-migration.md \
  decisions/2026-08-04-ycst-admin-docs-private-cpanel.md \
  docs/superpowers/specs/2026-08-12-ycst-org-uk-migration-design.md
git add -A
git commit -m "chore: retire the ycst moved blocks and record the migration"
git push -u origin chore/retire-ycst-moved-blocks
gh pr create --title "chore: retire the ycst moved blocks and record the migration" --body "$(cat <<'EOF'
Deletes the two spent `moved` blocks, records the migration in `decisions/`,
and amends the `quality/criteria.md` criterion that said Stategraph ignores
`moved`/`removed`. That was true of the retired `stategraph tf` wrapper; under
the native CLI against the HTTP backend, `moved` is honoured across provider
aliases and renamed `for_each` keys, while `removed` still rejects instance
keys.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
gh pr checks --watch
gh pr merge --squash --delete-branch
```

No apply follows — this PR has no plan-affecting change, which Step 5 proved.

---

## Out of scope

Carried from the design, and not implemented by any task above:

- `_teams.yaml` for `yo61`. `owners` is a GitHub built-in that should stay
  unmanaged.
- Reinstalling any GitHub App on `ycst-org-uk`, including a YCST `lastlight`.
- Separate Stategraph state per org.
- Any change to the two repos' contents, CI workflows, or deploy scripts.
- Enforced merge gates on either repo — the free-plan paywall is unchanged.
