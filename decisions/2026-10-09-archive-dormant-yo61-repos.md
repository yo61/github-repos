## Decision: archive twelve dormant `yo61` repositories by setting `archived: true` in each data file: `demo_profile_activemq`, `lambda-copy-db-snapshot`, `mcollective-plugin-power`, the five `puppet-*` repositories, `terraform-aws-lambda_function`, `vagrant-puppet-cluster`, `vagrant-zookeeper` and `CiviCRM_Stripe_Allow_Promotional_Codes`.

## Context: auditing `yo61`'s repositories for dependency updates on 2026-10-09 (the `dependency-updates` skill's rule: every pin has exactly one owner) found eleven repositories last pushed between 2013 and 2017. Robin added `CiviCRM_Stripe_Allow_Promotional_Codes`, last pushed 2025-12-12, as inactive too. Giving their pins owners would mean update pull requests against code nobody maintains.

## Alternatives considered:

Put to Robin on 2026-10-09:

- **Archive them, then audit the live repositories** (taken).
- **Audit all of them**, giving each pin an owner or a recorded reason.
- **Exclude them from the audit without archiving**, noting why in its report.

## Reasoning: an archived repository is read-only, so it carries no pin anyone is expected to move, and the audit covers the repositories that are live. Setting `archived: true` in the existing data file is one write per repository; afterwards the plan is a no-op as long as nothing else in the file changes, since GitHub rejects writes to an archived repository (`decisions/2026-08-25-exclude-archived-from-drift-detection.md`).

## Trade-offs accepted:

- **Unarchiving is a manual step in GitHub's settings**: the provider cannot unarchive.
- **Any later change to these data files fails at apply** while the repositories stay archived, so they are left alone.

## Supersedes: none.

## Amended 2026-10-09: the archived repositories are forgotten, not managed

The first plan after archiving proposed an update to all twelve: archiving had switched
secret-scanning push protection off on each, and the module's public-repository default wants it
on. GitHub rejects that write on an archived repository, so every later apply would have failed
on them. Robin chose to stop managing them: their data files are deleted and their module
instances removed from state with `terraform state rm`, so GitHub keeps the repositories,
archived, and Terraform no longer knows them. This is how `python-template-archived` is held, and
the drift check already skips archived repositories
(`decisions/2026-08-25-exclude-archived-from-drift-detection.md`).

`removed { lifecycle { destroy = false } }` could not do it: Terraform 1.15 rejects a module
instance key in `from` ("Module instance keys not allowed"). The state was backed up first
(serial 94), and the removal ran just before this change merged, so no plan from `main` saw the
config without the state or the state without the config.

The first record's last trade-off no longer holds: these data files are gone rather than left
alone. Unarchiving a repository now means unarchiving it in GitHub and importing it again.
