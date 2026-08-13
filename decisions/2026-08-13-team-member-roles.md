# Decision: `_teams.yaml` carries `maintainers` alongside `members`

`data/<org>/_teams.yaml` gains a second optional list, `maintainers`, holding
usernames granted the team's `maintainer` role. `members` keeps its meaning —
a plain list of usernames granted `member`. `modules/org/teams.tf` renders one
`dynamic "members"` block per list.

The same change switches `github_team_members` from `team_id` to `team_slug`.

## Context

`docs/superpowers/specs/2026-08-12-ycst-org-uk-migration-design.md` decided
against roles, under "Decisions taken without further input":

> **Flat member list, no `maintainer`/`member` roles.** The provider defaults a
> member's role to `member`, and `robinbowes` already administers the team by
> virtue of org ownership, so roles would add configuration surface for no
> behaviour. Add them when a team needs a maintainer who is not an org owner.

PR #64 created `ycst-org-uk/admins` with that flat list. The apply reported
`3 added, 0 changed, 0 destroyed`, but the next plan was not clean:

```
module.org_ycst_org_uk.github_team_members.this["admins"]
  robinbowes: maintainer → member
```

GitHub makes whoever creates a team its maintainer. `github_team_members` is
authoritative and the config named no role, so the provider default `member`
became a standing instruction to demote the creator.

The same apply raised a provider deprecation: `team_id` is deprecated in favour
of `team_slug` and "will be made computed only in a future version". The root
module's `version = "~> 6.0"` permits that release, so the config would break
on a routine provider bump.

## Alternatives considered

- **Apply the demotion.** Let `robinbowes` become a plain member. Minimal
  config, and the original reasoning survives — org ownership administers the
  team regardless of team role.
- **One `members` list whose entries may be a string or a `{username, role}`
  object.** Keeps a single list, at the cost of a heterogeneous type that
  Terraform reasons about poorly and that every reader has to decode.
- **Every member an object with an explicit `role`.** Uniform, but verbose for
  the common case of a team with no maintainers.
- **`lifecycle { ignore_changes }` on the members block.** Silences the diff
  without expressing intent, and would mask genuine membership drift.
- **Defer the `team_slug` switch to a later PR.** Rejected: it touches the same
  resource, so landing both together means one plan shows their combined effect.

## Reasoning

The spec's decision was sound but its stated premise — "roles would add
configuration surface for no behaviour" — turned out to be false. Omitting the
role does have a behaviour: a standing diff. Once roles must be expressed, two
parallel lists of plain usernames cost less than a heterogeneous list, and a
team with no maintainers writes exactly what it writes today.

Declaring the reality rather than demoting the creator also keeps the YAML
honest about what GitHub shows in its UI, which is the point of an
authoritative resource.

`team_slug = github_team.this[each.key].slug` preserves the dependency edge
that orders team creation before any repo grant. The edge comes from
referencing `github_team` at all, not from which attribute is read.

Usernames under a team are written lowercase. `github_team_members` lowercases
them into state and compares case-sensitively, so `PlanetSeth` is a standing
diff where `planetseth` is stable. This is specific to team membership —
`collaborators.users` in a repo file carries GitHub's display case and has never
drifted, so the two are deliberately inconsistent rather than uniformly
lowercased.

## Trade-offs accepted

- Two lists can disagree: a username in both `maintainers` and `members`
  produces two blocks for one user. No validation guards this — consistent with
  declining the analogous non-empty-members precondition in PR #64, and plan
  review is the control.
- `maintainers` must be maintained by hand as teams change. GitHub will not
  auto-correct it, and the standing diff that revealed the problem here only
  appears at team creation.
- Reverses a decision recorded one day earlier, so the spec now contains a
  superseded claim. The spec is left unedited as a record of what was believed
  at the time; this file is the correction.

## Supersedes

Amends the "Flat member list, no `maintainer`/`member` roles" decision in
`docs/superpowers/specs/2026-08-12-ycst-org-uk-migration-design.md`. Supersedes
no prior file in `decisions/`.
