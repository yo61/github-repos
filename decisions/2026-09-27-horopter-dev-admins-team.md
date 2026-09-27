# Decision: give `horopter-dev` an `admins` team and grant it admin on every repo

`data/horopter-dev/_teams.yaml` declares one team, `admins`, with `robinbowes`
as its sole maintainer. All four repos in the org — `helm-charts`, `horopter`,
`horopter-internal` and `infrastructure` — grant it `admin` through
`collaborators.teams`. This is the same shape `ycst-org-uk` has had since
2026-08-13, where all twelve repos grant the same team.

Landed alongside the new `horopter-dev/helm-charts` repo, which is the change
that raised the question.

## Context

`decisions/2026-09-21-horopter-dev-org.md` accepted **"No `_teams.yaml`. Sole
ownership makes admin implicit, as on `yo61`"** as a trade-off when the org was
created on 2026-09-20. That was accurate for three repos and one member, and
the record said adding a team later would be "purely additive and needs no
state surgery" — which is what this is.

Two things changed in the six days since. A fourth repo was added, and the org
was created with "an eventual second contributor" as one of its stated reasons
for existing. Access that rests on org ownership has nothing to grant a second
person short of making them an owner.

The immediate trigger was narrower: the new `helm-charts` repo needed an access
model, and picking one for a single repo would have set the org's default by
accident.

## Alternatives considered

- **Keep relying on org ownership, add no team.** The status quo from
  2026-09-21. Rejected on the second-contributor point: the only lever it
  offers is org ownership, which is org-wide and cannot be scoped per repo.
- **Grant the team on `helm-charts` only.** Minimal, and exactly what was
  asked. Rejected because it leaves horopter-dev with two access models and
  a reconciliation someone has to do later — the kind of inconsistency that
  reads as an oversight rather than a decision.
- **`collaborators.users` with `robinbowes` as admin on each repo**, as
  `data/yo61/` does. Rejected: it grants access to a person rather than to a
  role, so a second contributor means editing every data file. `yo61` is a
  personal account with no teams available, which is why it does it that way;
  `horopter-dev` is an organization and is not constrained to it.
- **A team per repo, or a team per access level** (`admins` plus a future
  `contributors`). Rejected as speculative. One team covers what exists; a
  second can be added when someone needs write-but-not-admin.

## Reasoning

**One team granted uniformly is the pattern already proven here.**
`ycst-org-uk` runs it across twelve repos and has since its migration. Copying
a working shape costs nothing and makes the two orgs readable as one system.

**Access should attach to a role, not a person.** The team is the thing repos
grant to; who is in it is one edit in one file. That is the whole reason to
prefer it over `collaborators.users` now, before there is a second contributor
rather than after.

**`robinbowes` goes under `maintainers`, not `members`.** Per
`decisions/2026-08-13-team-member-roles.md`: GitHub makes a team's creator its
maintainer, so a team whose YAML lists its creator as a member shows a standing
diff demoting them. The plan confirms the intent —
`github_team.this["admins"]` sets `create_default_maintainer = false` and
`github_team_members` supplies the maintainer explicitly, so the role is
declared rather than inherited.

**The team file and the four grants ship in one commit** because
`modules/org/data.tf` has a precondition that fails the plan on a grant to a
slug absent from that org's `_teams.yaml`. Splitting them would break `task
plan` on whichever landed first.

## Trade-offs accepted

- **Team membership becomes authoritative.** A member added through the GitHub
  UI is removed on the next apply. This is the same posture as topics and every
  other managed setting, and it is the point — but it is a new way for
  horopter-dev to surprise someone.
- **No change in effective access today.** `robinbowes` is the sole org member
  and already reaches all four repos as owner. The grant is redundant right
  now; its value is entirely in what it makes cheap later.
- **Four more resources in state**, one `github_team`, one
  `github_team_members`, and a `team` block inside each repo's existing
  `github_repository_collaborators`.
- **The org's data files now enumerate a team slug that only `_teams.yaml`
  defines.** A typo in a slug is caught by the precondition at plan time rather
  than silently granting nothing, so this is a checked coupling, not a loose
  one.
- **`helm-charts` grants the team while having no contents yet.** The repo is
  created empty; the grant applies from creation regardless.

## Supersedes

Supersedes nothing. **Amends `decisions/2026-09-21-horopter-dev-org.md`** on
one trade-off: its "No `_teams.yaml`" entry no longer describes the org. The
reasoning it gave was sound for the org as it stood, and it correctly predicted
that reversing it would be additive — creating the team and the grants plans as
2 adds and 3 in-place changes, with no state surgery and nothing destroyed.
