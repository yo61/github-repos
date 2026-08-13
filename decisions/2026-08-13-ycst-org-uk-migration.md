# Decision: manage `ycst-org-uk` as a second org, with team-based admin

`ycst-org-uk` is managed from this repository as a second org: one provider
alias, one `modules/org` call, one `data/` directory. Its repos grant admin
through an `admins` team rather than named user collaborators.

The two York City Supporters Trust repos moved out of `yo61`:

| Before | After |
| --- | --- |
| `yo61/ycst-admin-docs` | `ycst-org-uk/board-docs` |
| `yo61/ycst-website-testing` | `ycst-org-uk/website-testing` |
| `PlanetSeth` named as a user collaborator | `admins` team holds admin on both |

The repos were transferred and renamed on GitHub out of band, then re-adopted
into state with `terraform state rm` plus `import` blocks — **not** with the
`moved` blocks the design specified. See "What went wrong" below.

## Context

Trust assets were living in a personal org, with a second trustee named as an
individual collaborator. `ycst-org-uk` was created 2026-08-12 on the free plan.
This repository was designed for a second org from the start:
`docs/dev/2026-05-22-multi-org-github-repos-design.md` reserved
leading-underscore filenames for per-org metadata and kept `collaborators.teams`
in `modules/github-repo` while leaving teams out of scope.

Design: `docs/superpowers/specs/2026-08-12-ycst-org-uk-migration-design.md`.
Plan: `docs/superpowers/plans/2026-08-13-ycst-org-uk-migration.md`.
Delivered as PRs #64, #65, #66, #67.

## Alternatives considered

- **A fully declarative forget-and-reimport using `removed` blocks.** Rejected
  by experiment: `removed` rejects instance keys — *"Module address must be a
  module, not a module instance"* — so two of `yo61`'s repos cannot be forgotten
  without forgetting all of `module.repo`.
- **Destroy and recreate.** Loses issues, secrets, environments, and history.
- **Separate Stategraph state per org.** Real blast-radius isolation, but would
  mean migrating `yo61`'s existing instances into a new state for no benefit
  currently required. Reconsider if `ycst-org-uk` gains contributors who should
  not be able to apply against `yo61`.
- **Keeping named-user collaborators.** Does not scale past one trustee, and
  makes offboarding a per-repo edit.
- **Renaming the repos back so the stale IDs resolved,** then letting Terraform
  perform the rename itself. Avoids state surgery, but adds two more
  outward-facing renames and relies on unverified provider behaviour for the
  dependent alert resources, whose IDs are also the repo name.

## Reasoning

Team grants scale past one trustee and make membership a single edit in
`_teams.yaml`. Actions minutes and storage now bill against the trust's own
free-plan allowance rather than `yo61`'s.

Passing `team_ids` (IDs, not slugs) from `modules/org` into `modules/github-repo`
is what creates the dependency edge ordering team creation before a repo grant.
The edge comes from referencing `github_team` at all, not from which attribute
is read or whether the `lookup` default fires.

## What went wrong

The design established by experiment that `moved` works across provider aliases
and renamed `for_each` keys in a single block, and that finding held. What the
experiment could not show is that **`moved` cannot carry a rename when the
resource ID is the name**, because its fixture used a resource whose ID was a
random string, stable across the move.

For `github_repository` the ID *is* the repo name. After the `moved` blocks
rebound each resource to the `ycst_org_uk` provider, refresh asked GitHub for
`ycst-org-uk/ycst-admin-docs` and got 404: the rename redirect is keyed on the
original owner/name pair (`yo61/ycst-admin-docs`), not on the old name under the
new owner. Terraform read the 404 as "the resource is gone" and planned to
create two repos that already existed.

The plan's gate caught it — zero destroys, but four creates where eight moves
were expected — and nothing was applied. Recovery was `terraform state rm` for
the eight stale instances, which does not touch GitHub, followed by `import`
blocks adopting the same objects at their new addresses under their new names.
Both work against the HTTP backend; the note that Stategraph lacked `state mv`
and `state rm` described the retired `stategraph tf` wrapper, not the native CLI.

Applied result: 8 imported, 0 added, 3 changed, 0 destroyed.

Two smaller corrections came out of the same work, both recorded in
`decisions/2026-08-13-team-member-roles.md`: GitHub makes a team's creator its
maintainer, which an authoritative `github_team_members` fights unless the role
is declared; and `github_team_members` lowercases usernames into state, so mixed
case is a standing diff.

## Trade-offs accepted

- **One Stategraph state still spans both orgs.** `task plan ORG=<org>` scopes a
  plan but only warns — it does not isolate. Targeting also skips the excluded
  org's `check "unmanaged_repos"` and its filename/`name:` validation, so it is
  for scoping a known change, not routine planning.
- **`board-docs` loses `yo61-lastlight`.** GitHub App installations do not
  transfer and none were reinstalled on `ycst-org-uk`. The manual-review policy
  in `decisions/2026-08-10-private-repos-manual-review-gate.md` survives — it
  made human review the control precisely because rulesets are paywalled — but
  the reviewer is human-only rather than bot-assisted.
- **`yo61`'s `owners` and `ubnt` teams stay unmanaged.** An org with no
  `_teams.yaml` manages no teams, so they are neither adopted nor destroyed.
  `owners` is a GitHub built-in that should stay that way.
- **The free-plan paywall is unchanged.** Both repos keep
  `builtin_ruleset_names: []`; rulesets and classic branch protection 403 on
  private repos, so neither gains an enforced merge gate.
- **`website-testing` carries `auto_init: true` against an imported `false`.**
  `auto_init` is create-only and the API never reports it, so import reads
  `false` and the declared `true` was applied as a state-only correction. The
  design kept the field on the grounds that it was already in state; after
  re-import that rationale is inverted, and dropping it would now be the
  no-diff choice.

## Supersedes

Supersedes no prior record. Amends
`decisions/2026-08-04-ycst-admin-docs-private-cpanel.md` only in that the repo
now lives at `ycst-org-uk/board-docs`; that record's private-visibility
reasoning is unchanged. `decisions/2026-08-13-team-member-roles.md` amends this
migration's design decision on team member roles.
