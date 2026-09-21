# Decision: adopt six of `ycst-org-uk`'s unmanaged repos, and leave `ycst-wp-dev` alone

Six repos that `check "unmanaged_repos"` had been reporting are now managed:
`ycst-dashboard`, `ycst-events`, `ycst-governance-report`, `ycst-member-card`,
`ycst-member-discounts`, `ycst-protected-files`. All six are WordPress plugins.

`ycst-wp-dev` is deliberately left unmanaged, so the check keeps naming it.

Applied 2026-09-21: **24 imported, 0 added, 24 changed, 0 destroyed.**

## Context

The seven repos had been warning on every plan since `ycst-org-uk` came under
management. They exist on GitHub with content, so this is an adoption, not a
creation — a data file alone would have Terraform try to create repos that exist
and get a 422.

Delivered as PR #96 and the cleanup PR that removes its one-shot import blocks.

## Alternatives considered

- **Declaring `has_projects: true` to preserve live state.** All seven had
  Projects on; the module default is `false` and the six already-managed ycst
  repos have it off. Rejected: consistency within the org was preferred over
  preserving a feature nothing was using.
- **Keeping `PlanetSeth` as a direct collaborator**, matching live exactly.
  Rejected as re-adopting the pattern
  `decisions/2026-08-13-ycst-org-uk-migration.md` moved away from; it does not
  scale and makes offboarding a six-file edit.
- **Adopting `ycst-wp-dev` with a placeholder description.** Written and then
  reverted — see below.
- **Deleting `ycst-wp-dev`.** Not chosen: nobody currently knows what it is, and
  that is an argument for finding out, not for deleting.
- **Hand-writing the 24 import blocks** instead of fixing the generator.
  Rejected: the generator exists for this, and the bug found in it (below) would
  have been reproduced by hand anyway.

## Reasoning

**Two changes to live state were chosen, and two came free with management.**
Chosen: `has_projects` `true -> false`, and admin moving from the direct
collaborator to the `admins` team. Access is preserved because `PlanetSeth` is
already an `admins` member — verified after apply, `permission=admin`.
Unchosen but inherent: `delete_branch_on_merge` and `allow_update_branch` both
`false -> true`, the module defaults asserting themselves on repos created
outside management.

**`vulnerability_alerts` and `dependabot_security_updates` were off on all six**
and are now on. Nothing in the drift warning revealed that: `check
"unmanaged_repos"` reports the absence of a data file, not the settings behind
it. The security posture of an unmanaged repo is invisible until it is adopted,
which is an argument for adopting sooner rather than later.

**Descriptions were taken from each plugin's own `Description:` header** rather
than inferred from filenames, since `topics` and `description` become
authoritative on the first apply.

**`ycst-wp-dev` is left unmanaged because a placeholder would become the source
of truth.** The repo is completely empty — no commits, no README — so nothing in
it describes its purpose, and the description in the first revision of PR #96
was written from the repo name alone. Adopting it would have fixed a guess into
the authoritative record. The standing `check "unmanaged_repos"` warning is the
reminder to establish what it is or delete it; the check warns and does not
block.

## Trade-offs accepted

- **The drift check never goes fully quiet.** One repo keeps it warning on every
  plan, which is the cost of not guessing. If the warning becomes noise, the fix
  is to answer the question, not to adopt the repo.
- **Projects were switched off on six live repos.** Reversible by declaring
  `has_projects: true`, but the boards, if any held content, are not restored by
  re-enabling.
- **`scripts/generate_yo61_configs.sh` was renamed and changed** as part of a
  feature PR rather than its own. It became `generate_import_blocks.sh`: `ORG` is
  now required rather than hardcoded, and the module address applies the
  hyphen-to-underscore substitution `main.tf` uses. Without that fix every
  generated address read `module.org_ycst-org-uk` — an invalid module label —
  and the plan would have proposed creating six repos that already exist. That
  is the ycst migration's failure signature from an unrelated cause, and the
  criterion in `quality/criteria.md` names two suspects, neither of which would
  have been it.
- **`prek` still configures no shell hooks**, which is why that script drifted
  from the project's `shfmt` standard unnoticed. Adding `shellcheck`/`shfmt`
  currently fails on `scripts/check_repo_yaml_name.sh` and
  `scripts/migrate_vulnerability_alerts/classify.sh`, so it is logged as due
  rather than done here.

## Supersedes

Supersedes nothing. Extends `decisions/2026-08-13-ycst-org-uk-migration.md`,
whose team-based admin decision is applied here to six more repos, and
`decisions/2026-08-25-exclude-archived-from-drift-detection.md`, which
established that the drift check reports only repos that could actually be
managed — the reason all seven appeared in it at all.
