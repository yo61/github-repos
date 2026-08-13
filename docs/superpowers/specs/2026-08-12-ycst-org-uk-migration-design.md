# `ycst-org-uk` — second managed org, team-based admin, repo migration

Date: 2026-08-12
Status: Implemented 2026-08-13. See `decisions/2026-08-13-ycst-org-uk-migration.md`.
Finding 1 below is incomplete: `moved` cannot carry a **rename**, because
`github_repository`'s ID is the repo name. The migration recovered with
`terraform state rm` plus `import` blocks. The decision record has the detail.

## Goal

Manage the new `ycst-org-uk` GitHub organisation from this repository, grant
admin on its repos through a team rather than named users, and move the two
`ycst-*` repos out of `yo61` into it.

End state:

| Now | After |
| --- | --- |
| `yo61/ycst-admin-docs` | `ycst-org-uk/board-docs` |
| `yo61/ycst-website-testing` | `ycst-org-uk/website-testing` |
| `PlanetSeth` named as a user collaborator | `admins` team holds admin on both |

## Starting state (verified 2026-08-12)

`ycst-org-uk` exists, created 2026-08-12, **free** plan. Members: `robinbowes`
(org owner), `PlanetSeth` (member). No teams, no repos, no GitHub App
installations. `default_repository_permission` is `read`.

`yo61` is also on the free plan, so the paywall constraints in
`decisions/2026-08-10-private-repos-manual-review-gate.md` carry across
unchanged: rulesets and classic branch protection both 403 on private repos.
Both files therefore keep `builtin_ruleset_names: []`, and neither gains a
review-count or required-checks gate.

State holds eight instances for the two repos:

```
module.org_yo61.module.repo["ycst-admin-docs"].github_repository.this
module.org_yo61.module.repo["ycst-admin-docs"].github_repository_collaborators.this
module.org_yo61.module.repo["ycst-admin-docs"].github_repository_dependabot_security_updates.this["this"]
module.org_yo61.module.repo["ycst-admin-docs"].github_repository_vulnerability_alerts.this["this"]
… and the same four for ycst-website-testing
```

This repository was designed for a second org.
`docs/dev/2026-05-22-multi-org-github-repos-design.md` states the goal as
"one provider block + one module call + a new data directory", reserves
leading-underscore filenames for per-org metadata (`_teams.yaml` is named in
`modules/org/data.tf:11`), and puts teams explicitly out of scope while
retaining the module capability to reference them. `modules/github-repo`
already accepts `collaborators.teams` and a `team_ids` map; `modules/org` has
never passed either.

### Mechanism findings

Established by experiment against a scratch fixture reproducing this repo's
module shape (root → aliased provider → `modules/org` → `for_each` →
`modules/repo`), not from documentation:

1. **`moved` works across provider aliases and a renamed `for_each` key** in
   one block. A move from `module.org_a.module.repo["r1"]` to
   `module.org_b.module.repo["r1_renamed"]`, where the two org modules are
   bound to different aliases of the same provider, planned
   `0 to add, 0 to change, 0 to destroy`, preserved the resource ID, and
   rewrote the provider binding in state from `…random"].a` to `…random"].b`
   automatically. Configuration wins over the provider recorded in state.
2. **`removed` blocks reject instance keys**:
   `Error: Module instance keys not allowed — Module address must be a module
   (e.g. "module.foo"), not a module instance`. Forgetting two of `yo61`'s
   repos via a `removed` block is impossible; only all of `module.repo` at
   once. This rules out a fully declarative forget-and-reimport migration.
3. **`-target` scopes cleanly at the org module boundary.** With pending
   changes in both orgs, `-target=module.org_a` planned only org_a's change
   and `-target=module.org_b` only org_b's.
4. **A cross-org `moved` block cannot be targeted to one side**:
   `Error: Moved resource instances excluded by targeting`. Naming both
   modules works, which with two orgs is equivalent to not targeting.

Finding 1 contradicts the `quality/criteria.md` criterion "An instance address
change produces destroy+create. Stategraph ignores HCL `moved`/`removed`
blocks and has no `state mv`/`rm`." That was true of the `stategraph tf`
wrapper retired by `decisions/2026-08-04-native-terraform-http-backend.md`.
Under the native CLI against the HTTP backend, `moved` is honoured. The
criterion is amended as part of this work rather than left to mislead.

## Part 1 — team support in `modules/org`

New optional file `data/<org>/_teams.yaml`, a map keyed by team slug:

```yaml
---
admins:
  description: Administrators for York City Supporters Trust repositories
  members:
    - robinbowes
    - PlanetSeth
```

`modules/org/data.tf` loads it when present and yields `{}` when absent.
A new `modules/org/teams.tf` creates one `github_team` per key and one
`github_team_members` per team. `github_team_members` is authoritative,
matching this repo's "the YAML is the source of truth" posture.

`modules/org/main.tf` passes the resulting IDs into each repo:

```hcl
team_ids = { for slug, t in github_team.this : slug => t.id }
```

This is a **dependency edge, not an optimisation**, despite the comment at
`modules/github-repo/main.tf:161`. Passing only the slug leaves
`github_repository_collaborators` with no reference to `github_team`, so
Terraform may order a repo's team grant before the team exists. The existing
`lookup(var.team_ids, team.value.slug, team.value.slug)` fallback still covers
a slug naming a team this repository does not manage.

Repo YAML gains:

```yaml
collaborators:
  teams:
    - permission: admin
      slug: admins
```

`modules/org` also gains a precondition, alongside the existing filename/`name:`
check on `terraform_data.validations`, asserting that every team slug referenced
by a repo in the org resolves in that org's `_teams.yaml`. Without it a typo
falls through the `lookup` fallback and surfaces as an opaque API error at apply
time instead of a named failure at plan time.

**Degrades safely for `yo61`.** No `_teams.yaml` there means `github_team.this`
is an empty map, so the existing `owners` and `ubnt` teams stay unmanaged —
neither adopted nor destroyed. Bringing them under management is a follow-up,
and `owners` is a GitHub built-in that should not be managed at all.

## Part 2 — the `ycst-org-uk` org wiring

`providers.tf`:

```hcl
provider "github" {
  alias = "ycst_org_uk"
  owner = "ycst-org-uk"
}
```

`main.tf`:

```hcl
module "org_ycst_org_uk" {
  source = "./modules/org"
  org    = "ycst-org-uk"

  providers = {
    github = github.ycst_org_uk
  }
}
```

No `default_branch_ruleset_*` arguments. Both repos are private on a free org,
so `builtin_ruleset_names: []` leaves no ruleset for a bypass actor to attach
to; the module variables default to `[]`. The `Integration` bypass actor `yo61`
passes (`actor_id = 3654569`) is not carried over.

`data/ycst-org-uk/board-docs.yaml` — the current `ycst-admin-docs.yaml` with the
name changed and the `users:` block replaced by the team grant:

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

`data/ycst-org-uk/website-testing.yaml`:

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

`auto_init: true` is retained even though it only has meaning at creation: it
is in state, and dropping it would show a diff for no behavioural change.
`visibility: private` restates the module default and is likewise retained, on
the same grounds as `decisions/2026-08-04-ycst-admin-docs-private-cpanel.md` —
it is the fact the access-control design rests on.

## Part 3 — `Taskfile` per-org targeting

`task plan` accepts an optional `ORG=<org>`, converting the org slug to the
module name and guarding against a slug with no data directory. Verified
working, including `replace` in Task's templating subset:

```yaml
org-guard:
  internal: true
  silent: true
  cmds:
    - |
      if [ -n "{{.ORG}}" ] && [ ! -d "data/{{.ORG}}" ]; then
        echo "ERROR: no data/{{.ORG}} directory; ORG must name a managed org." >&2
        exit 1
      fi

plan:
  desc: Generate a plan file (ORG=<org> scopes it to one org)
  deps: [preflight, org-guard]
  vars:
    TARGET: '{{if .ORG}}-target=module.org_{{.ORG | replace "-" "_"}}{{end}}'
  cmds:
    - terraform plan -out={{.PLAN_FILE}} {{.TARGET}}
```

`task apply` is unchanged: a saved plan file carries its own targeting. The
guard matters because an unmatched `-target` produces only a soft warning and
an empty plan, which reads like "nothing to do".

Targeting costs the untargeted org's drift detection. `modules/org/data.tf`
runs `data.github_repositories` behind `check "unmanaged_repos"`, and
`terraform_data.validations` guards filename/`name:` mismatches; neither
evaluates for a module excluded by targeting. `ORG=` is therefore for scoping a
known change, not for routine planning — the unscoped `task plan` stays the
default.

## Part 4 — migration sequence

**PR 1 — plumbing and team, no repos.** Parts 1, 2 (minus the two data files)
and 3. Apply with `ORG=ycst-org-uk`, which cannot touch `yo61`:

```bash
direnv exec . task plan ORG=ycst-org-uk
direnv exec . task apply
```

Expected: creates `github_team.admins` and its two memberships. Nothing else —
`data/ycst-org-uk/` contains only `_teams.yaml` at this point.

**Step 2 — transfer and rename, out of band.** Terraform cannot do this;
`github_repository` takes its owner from the provider, so the move must happen
on GitHub first.

```bash
gh api -X POST /repos/yo61/ycst-admin-docs/transfer \
  -f new_owner=ycst-org-uk -f new_name=board-docs
gh api -X POST /repos/yo61/ycst-website-testing/transfer \
  -f new_owner=ycst-org-uk -f new_name=website-testing
```

`202 Accepted` is asynchronous. Confirm both landed before planning anything.

**PR 3 — move config and state together.** The two data files move into
`data/ycst-org-uk/` under their new stems, and `main.tf` gains one `moved`
block per repo:

```hcl
moved {
  from = module.org_yo61.module.repo["ycst-admin-docs"]
  to   = module.org_ycst_org_uk.module.repo["board-docs"]
}

moved {
  from = module.org_yo61.module.repo["ycst-website-testing"]
  to   = module.org_ycst_org_uk.module.repo["website-testing"]
}
```

One block per repo carries all four of its instances. **This plan must be
unscoped** (finding 4). Gate on it showing:

- zero destroys;
- four moves per repo;
- one substantive change — `github_repository_collaborators` on `board-docs`
  dropping `PlanetSeth`'s direct grant in favour of the team grant.

Anything else, stop and diagnose.

**Ordering.** Prepare and review PR 3, then transfer, then merge, then plan and
apply — with no apply in between. Merging PR 3 *before* the transfer creates a
window where the plan proposes to **create** `ycst-org-uk/board-docs`; applying
that leaves an empty repo whose name then blocks the real transfer. Transferring
first inverts the failure into a confusing-but-non-destructive plan against
`yo61`, since the GitHub API redirects the old path.

**PR 4 — delete the spent `moved` blocks**, plus the `quality/criteria.md`
amendment and a `decisions/2026-08-12-ycst-org-uk-migration.md` record.

## Part 5 — what Terraform does not manage

None of the following appears in any plan. All of it must be checked by hand.

**GitHub App installations do not transfer, and `ycst-org-uk` has none.** Five
apps currently reach these repos through `all`-scope installs on `yo61`:
`yo61-lastlight`, `claude`, `semantic-release-pusher`, `linear-code`,
`spacelift-io`. (`yo61-renovate` and `flux-homelab-reconciler` are
`selected`-scope and cover only `flux-homelab`, so they are unaffected.)

**Decision: reinstall none of them for now.** The consequence is that
`board-docs` loses `yo61-lastlight`, the reviewer named in
`decisions/2026-08-10-private-repos-manual-review-gate.md`. That decision's
*policy* survives — it made manual review the control precisely because
rulesets are paywalled — but the reviewer becomes human-only rather than
bot-assisted. A separate lastlight instance for YCST is a possible follow-up.

An incidental benefit that motivated the split: Actions minutes and storage for
these repos now bill against `ycst-org-uk`'s own free-plan allowance instead of
`yo61`'s.

**Secrets and environments**, inventoried 2026-08-12:

| Repo | Repo Actions secrets | Environments | Environment secrets | Protection |
| --- | --- | --- | --- | --- |
| `ycst-admin-docs` | `SSH_HOST`, `SSH_KNOWN_HOSTS`, `SSH_PORT`, `SSH_PRIVATE_KEY`, `SSH_USER` | `production`, `staging` | `DEPLOY_ROOT`, `GATE_PATH`, `SMOKE_PASSWORD`, `SMOKE_USER`, `WP_LOAD_PATH` in each | `production` carries a custom deployment-branch policy |
| `ycst-website-testing` | none | none | none | none |

Neither repo has webhooks or deploy keys. GitHub's transfer documentation
states webhooks, secrets and deploy keys remain associated, but says nothing
about environments or their secrets, so those are verified rather than assumed.

**The rename is safe from the CI side.** Neither repo's workflows reference
`yo61` or their own repository name; `deploy.yaml` refers only to
`environment:`. Redirects cover git operations against the old paths.

## Decisions taken without further input

Both are cheap to reverse and neither blocks implementation:

- **`privacy: closed`** on the `admins` team, exposed as an optional
  `_teams.yaml` field. Closed teams are visible to org members, which suits a
  team whose purpose is granting access. The provider default is `secret`, as
  are `yo61`'s existing teams.
- **Flat member list, no `maintainer`/`member` roles.** The provider defaults a
  member's role to `member`, and `robinbowes` already administers the team by
  virtue of org ownership, so roles would add configuration surface for no
  behaviour. Add them when a team needs a maintainer who is not an org owner.

## Verification

1. `prek run --files <changed>` passes.
2. After PR 1: `gh api /orgs/ycst-org-uk/teams --jq '.[].slug'` returns
   `admins`, with both members.
3. After the transfer: both repos resolve under `ycst-org-uk` at their new
   names; the old paths redirect.
4. PR 3's plan shows zero destroys and the single expected collaborator change.
5. After PR 3's apply: `PlanetSeth` holds `admin` on both repos via the team —
   `gh api /repos/ycst-org-uk/board-docs/collaborators/PlanetSeth/permission`.
6. Repo and environment secrets, and `production`'s branch policy, are present
   post-transfer; a deploy run reaches Krystal cPanel and
   `https://admin.ycst.org.uk` still serves.
7. Unscoped `task plan` is clean across both orgs, with no unmanaged-repo
   warnings.

## Out of scope

- `_teams.yaml` for `yo61` — a follow-up. `yo61` is effectively single-user, and
  `owners` is a GitHub built-in that should stay unmanaged.
- Reinstalling any GitHub App on `ycst-org-uk`, including a YCST lastlight.
- Separate Stategraph state per org. It would give real blast-radius isolation
  rather than a flag that warns, but would mean migrating `yo61`'s existing
  instances into a new state for no benefit currently required. Reconsider if
  `ycst-org-uk` gains contributors who should not be able to apply against
  `yo61`.
- Any change to the two repos' own contents, CI workflows, or deploy scripts.
- Enforced merge gates on either repo; the free-plan paywall is unchanged.
