# Decision: manage `horopter-dev` as a third org, and move the horopter repos into it

`horopter-dev` is managed from this repository as a third org: one provider
alias, one `modules/org` call, one `data/` directory. The horopter project's
three repos live there.

| Before | After |
| --- | --- |
| `yo61/horopter` | `horopter-dev/horopter` |
| `yo61/horopter-internal` | `horopter-dev/horopter-internal` |
| — | `horopter-dev/infrastructure` (new) |

The two existing repos were transferred on GitHub out of band and then re-adopted
into state with **`moved` blocks** — the mechanism
`decisions/2026-08-13-ycst-org-uk-migration.md` had to abandon. It worked here
on the first plan: 8 instances moved, 0 to add, 0 to change, 0 to destroy, every
move a `no-op`.

## Context

The horopter project outgrew a personal account: it wanted its own org for
issues, Actions minutes and an eventual second contributor, plus a third repo
for its infrastructure definitions. `horopter-dev` was created on GitHub on
2026-09-20 on the free plan. Creating the org is out of scope for this
repository, which manages repos *within* an org.

This was the second cross-org move performed here, and the first to separate
the transfer from a rename.

Delivered as PR #93 (org wiring plus `infrastructure`), PR #94 (the two
transfers), and the PR carrying this record, which removes the spent `moved`
blocks and corrects the documentation they made stale.

## Alternatives considered

- **`terraform state rm` plus `import` blocks** — the mechanism that recovered
  the ycst migration. Held as a pre-authorised fallback and never needed. It
  mutates state outside the plan/apply cycle, so the PR diff stops telling the
  whole story, and it leaves a window in which the repos are unmanaged.
- **Destroy and recreate.** Rejected: `terraform destroy` on a
  `github_repository` deletes the repository. `horopter-internal` had 3 open
  issues at the time of the move.
- **Transferring the repos *and* renaming them**, as the ycst repos were.
  Rejected for a reason worth stating: the rename is precisely what breaks
  `moved`, and no rename was wanted here anyway.
- **Leaving the two repos at `yo61` and creating only `infrastructure` in
  `horopter-dev`.** Rejected — it splits one project across two orgs, which is
  the thing the new org exists to stop.
- **A separate Stategraph state per org.** Still deferred, on the same
  reasoning as the ycst migration: real blast-radius isolation, but it would
  mean migrating existing instances for no benefit currently required.

## Reasoning

**`moved` is the right default for an instance address change, and its one real
limit is narrower than previously recorded.** The ycst migration concluded that
`moved` was unusable for a cross-org transfer. The actual constraint is that
**`moved` cannot rewrite a resource ID.** Terraform rewrites the state address
and the provider binding, never the ID. For `github_repository` the ID *is* the
repo name, so a transfer *plus rename* leaves state holding the old name, refresh
asks the new owner for it, and GitHub 404s — its rename redirect is keyed on the
original `owner/name` pair. A transfer *alone* keeps the ID valid, so refresh
resolves directly and the move is a no-op.

Verified before planning rather than discovered afterwards: `GET
/repos/horopter-dev/horopter` and `.../horopter-internal` both resolved
directly, and `vulnerability-alerts` (204) and `automated-security-fixes`
(`true`) had survived the transfer.

**One `moved` block per repo, not per resource.** A module-instance block carries
everything inside `module.repo["<name>"]`, including resources a hand-written
list of four would miss if either repo later gained a ruleset or a pages
resource.

**Sequencing put the irreversible step in the middle, between two gated
applies.** PR #93 wired the org and created `infrastructure`, proving the
provider alias and credentials worked before any live repo depended on them. The
transfers followed. PR #94 moved the data files and the state. Each apply was
gated on
`terraform show -json tfplan | jq` over `resource_changes`, reading the
addresses rather than the summary line — the check that would have caught the
ycst migration's unexpected creates immediately instead of by eye.

## Trade-offs accepted

- **A window existed in which no apply was safe.** Between the transfer and
  #94's apply, `main` had both data files under `data/yo61/` while GitHub had the
  repos at `horopter-dev`; any apply would have proposed recreating them at
  `yo61`. Managed by not applying, not by tooling. A shorter window was
  available — transfer first, then land everything in one PR — at the cost of
  losing #93's proof that the alias worked.
- **One Stategraph state now spans three orgs.** `task plan ORG=<org>` scopes a
  plan but does not isolate it, and targeting skips the excluded orgs'
  `check "unmanaged_repos"` and filename/`name:` validation.
- **`horopter-dev` has no GitHub App installations.** Installations do not
  transfer. The `yo61` semantic-release-pusher Integration actor (`3654569`) is
  therefore absent from this org's `default_branch_ruleset_bypass_actors`, which
  gets `local.admin_bypass_actors` alone.
- **The admin bypass actors are inert here today.** All three repos are private
  on the free plan, where rulesets are paywalled, so every one carries
  `builtin_ruleset_names: []` and has no ruleset for a bypass to apply to. They
  are declared anyway to keep the fleet-wide property in
  `decisions/2026-09-13-admin-override-all-rulesets.md` true for a third org
  rather than silently ending at two.
- **No `_teams.yaml`.** Sole ownership makes admin implicit, as on `yo61`. An
  org with no `_teams.yaml` manages no teams, so adding one later is purely
  additive and needs no state surgery.
- **`infrastructure` restates `visibility: private`**, which equals the module
  default. Kept as the documented exception every private data file here takes —
  10 of 10 before this one — on the grounds that a repo's visibility is the fact
  its access model rests on and a reader should not have to know a module default
  to see it.

## Supersedes

Supersedes nothing. **Amends `decisions/2026-08-13-ycst-org-uk-migration.md`**
on one point: its "What went wrong" section is correct that `moved` cannot carry
a rename, but its framing implies `moved` is unsuitable for a cross-org transfer
generally. It is suitable when the name is unchanged, as demonstrated here. The
corresponding criterion in `quality/criteria.md` was already scoped to renames
and needed no change.
