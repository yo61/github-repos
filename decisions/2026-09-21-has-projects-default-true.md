# Decision: `has_projects` defaults to `true`, and no data file declares it

The `modules/github-repo` default for `has_projects` moves from `false` to
`true`, and all 25 `data/yo61` declarations of `has_projects: true` are deleted.
**No data file mentions the key any more.**

Applied result: **0 added, 24 changed, 0 destroyed** — every change
`has_projects: false -> true`, and nothing else in the plan. Split 9 `yo61`,
12 `ycst-org-uk`, 3 `horopter-dev`.

## Context

25 of `data/yo61`'s 34 files declared `has_projects: true`, overriding a module
default of `false` identically 25 times. That is the smell the deviations-only
criterion in `quality/criteria.md` exists to catch, and it had a second cost: a
majority of files contradicting the default makes the default undiscoverable
from the data, so the config teaches the wrong thing. The same shape as the eight
files restating `delete_branch_on_merge: true` before PR #76 swept them.

The question arose from `decisions/2026-09-21-ycst-adopt-unmanaged.md`, which
noted the 25 overrides while doing something else, and from the observation that
Projects are not actually used in any repo.

Facts established before deciding:

- All three orgs report `has_organization_projects: true` and
  `has_repository_projects: true`.
- Config and live agreed on all 34 `yo61` repos beforehand: 25 declared `true`
  and were `true`, 9 omitted the key and were `false`. No drift.
- `GET /repos/{owner}/{repo}/projects` returns **404** on all 25 and on the org,
  so there were no classic boards to lose by changing the setting either way.

## Alternatives considered

- **`default = null`, so the setting is left unmanaged and each repo follows
  whatever GitHub gives it.** The preferred option on the face of it, and
  **rejected by experiment.** Probed on a branch: with a null default, dropping
  the declaration from a repo that was live `true` planned
  `has_projects = true -> null` — an active change, not "leave alone". The
  provider schema says why: `has_projects` is `optional=true computed=false`,
  whereas `vulnerability_alerts` is `computed=true`. Only a computed attribute
  has a representation for absence, which is exactly why the module can offer
  "leave null to leave unmanaged" for one and not the other. Nothing was applied.
- **Keep `default = false` and delete the 25 declarations**, giving projects-off
  fleet-wide. Rejected: it fights GitHub's own behaviour for no benefit, since
  the feature is unused either way and an enabled tab costs nothing.
- **Keep the 25 declarations and leave the default alone.** No drift exists and
  nothing is broken; the only cost is 25 redundant lines. Rejected because those
  lines actively mislead about what the default is.
- **Declare `has_projects: false` on the 15 private repos**, treating Projects as
  a public-repo feature. Rejected as a new convention with no motivating problem,
  and it would have re-created the restatement pattern in the other direction.

## Reasoning

**`true` matches the platform, so the fleet stops fighting it.** GitHub enables
repository projects by default for a repo in an org that permits them, which all
three orgs do. Taking the same default means the common case declares nothing.

**Not using a feature is not a reason to disable it.** The trigger for this was
"I don't use projects in any repo", which argues for not *configuring* projects,
not for switching them off. With no boards in existence anywhere — the REST
endpoint 404s — the observable difference is a tab.

**The null experiment is the part worth keeping.** It establishes a rule for this
module that is not otherwise visible: an attribute can be left unmanaged only if
the provider marks it `computed`. `vulnerability_alerts`,
`dependabot_security_updates` and `security_and_analysis` can be null-to-ignore;
`has_projects`, `has_issues`, `has_wiki` and `has_downloads` cannot, and a null
default on any of them would plan a change rather than a no-op. Applying such a
change also risks a permanent diff — config `null` against an API reporting
`false` — which `quality/criteria.md` already warns about as a provider
`Read`/`Update` asymmetry.

## Trade-offs accepted

- **The org-level kill switch is now dangerous, where before it was harmless.**
  Because `nullable = false`, every repo sends `has_projects = true` explicitly.
  GitHub errors if that is sent while an org has `has_repository_projects: false`
  — quoted in the provider docs and in the variable description — so **turning
  that org setting off would break every apply in this repository.** Under the
  old `false` default it would have been a no-op. This was raised and accepted:
  the org switch was under consideration as a belt-and-braces measure and is now
  off the table unless the default moves back.
- **Projects were enabled on 24 repos that had them off**, six of them repos
  switched off deliberately hours earlier by
  `decisions/2026-09-21-ycst-adopt-unmanaged.md`. That record is amended rather
  than left stale. The reversal was put explicitly and chosen.
- **Fifteen private repos on free-plan orgs gained a feature they will not use.**
  Harmless, but it means "private repo on a free plan" no longer implies a
  minimal feature set — the paywall shapes rulesets and secret scanning, not this.
- **A future repo that genuinely wants Projects off must declare
  `has_projects: false`**, which will look odd next to 40-odd files that declare
  nothing. That is the correct direction for the cost to fall, since it is the
  rare case.

## Supersedes

Amends `decisions/2026-09-21-ycst-adopt-unmanaged.md` on its `has_projects`
decision only; that record's amendment note points here. Supersedes nothing else.
