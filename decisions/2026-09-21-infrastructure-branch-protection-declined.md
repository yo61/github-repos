# Decision: `horopter-dev/infrastructure` stays unprotected, because the feature is paywalled

Branch protection was requested for `horopter-dev/infrastructure` and is **not**
being added. `builtin_ruleset_names: []` stays, and the reason is now recorded in
the data file so it is not re-litigated.

The same reasoning covers `horopter-dev/horopter` and
`horopter-dev/horopter-internal`, and every private repo in `ycst-org-uk`.

## Context

`horopter-dev` is on the **free** plan with one seat, and `infrastructure` is
private. GitHub's API answers the question directly:

```
GET /repos/horopter-dev/infrastructure/rulesets
403: Upgrade to GitHub Pro or make this repository public to enable this feature.
```

Classic branch protection is paywalled on the same terms. Confirmed 2026-09-21
against both `horopter-dev/infrastructure` and, for comparison,
`ycst-org-uk/ycst-dashboard`, which returns the same 403.

This repeats what `decisions/2026-08-04-ycst-admin-docs-private-cpanel.md`
established for the first private repo brought under management, and what
`CLAUDE.md`'s "Private repos on a free-plan org" convention states. It is
recorded again because this time it was asked for as a feature rather than
discovered as a constraint, and because the alternatives deserve to be written
down rather than re-derived.

## Alternatives considered

- **Make the repository public.** Unlocks rulesets and secret scanning, and it
  would get the same `default_branch` ruleset as the public `yo61` repos.
  Rejected: it holds the Cloudflare infrastructure definitions for
  `horopter.dev`. The account id is a `TF_VAR` and not committed, but the
  topology — routes, worker names, what is deployed where — becomes public
  reading.
- **Upgrade `horopter-dev` to Pro or Team.** Keeps the repo private and unlocks
  rulesets on all three of its repos plus secret scanning. Rejected on cost, and
  because it would fork the free-plan convention that currently shapes fifteen
  data files across two orgs — some private repos could then carry rulesets and
  others could not, for reasons invisible in the YAML.
- **A CI-only gate with no ruleset.** A workflow reporting pass/fail on PRs
  without anything enforcing it. Not taken now; it remains the cheapest way to
  get *some* signal if the repo grows beyond one contributor, and it is what
  `decisions/2026-08-06-unifi-mcp-ci-only-gate.md` describes for a repo that has
  CI worth running.
- **Declaring the ruleset anyway and accepting the failure.** Rejected, and
  worth naming because it is the trap: `modules/github-repo` would render a
  `github_repository_ruleset`, the plan would look healthy — Terraform cannot
  know the endpoint 403s — and the apply would fail partway through, after
  earlier resources in the same run had already been written.

## Reasoning

**The feature is unavailable, not merely unconfigured.** There is no way to
express branch protection for this repo in `data/horopter-dev/infrastructure.yaml`
that survives an apply. Every option above is a change to the repo's visibility
or the org's billing, not to its configuration.

**Protection here would have been weaker than it looks even if it were
available.** Per `decisions/2026-09-13-admin-override-all-rulesets.md`, the
repository Admin role bypasses every ruleset in all three orgs with
`bypass_mode: always`, and `main.tf` feeds `local.admin_bypass_actors` to
`horopter-dev` automatically. A ruleset on this repo would be fully bypassable by
its only maintainer. It would guard against accident, not against intent — and
per the same record, GitHub's auto-merge ignores bypass actors, so a bypassable
requirement still blocks bot PRs indefinitely.

**The reason belongs in the data file, not only in a decision record.** Data
files already carry comments where a value is non-obvious — `homebrew-tap.yaml`
and `python-template.yaml` among them — and `builtin_ruleset_names: []` looks
like an oversight to anyone who has not read `CLAUDE.md`. The comment is on
`infrastructure.yaml` because that is the repo the question was asked about; it
points here for the two siblings rather than repeating itself three times.

## Trade-offs accepted

- **Nothing prevents a direct push to `main` on this repo.** The maintainer is
  also the only contributor, and the local Last Light review gate already blocks
  an unreviewed SHA from reaching any remote — a client-side control, not a
  server-side one, and it does not survive someone else cloning the repo.
- **The decision is dated and will go stale if the plan changes.** If
  `horopter-dev` moves to Pro or the repo goes public, this record becomes
  wrong rather than merely inapplicable. The
  post-apply-verification criterion in `quality/criteria.md` — "when a decision
  record states a condition that later changes, correct the record" — is the
  backstop.
- **Recording it a third time is mild duplication.** `CLAUDE.md`, the
  2026-08-04 record and this one all say the same thing about the paywall. Kept
  anyway: the earlier two frame it as a constraint met while doing something
  else, and neither would be found by someone searching for why this repo has no
  branch protection.

## Supersedes

Supersedes nothing. Applies
`decisions/2026-08-04-ycst-admin-docs-private-cpanel.md`'s paywall finding to a
third org, and depends on
`decisions/2026-09-13-admin-override-all-rulesets.md` for the point that a
ruleset here would have been bypassable by its only maintainer.
