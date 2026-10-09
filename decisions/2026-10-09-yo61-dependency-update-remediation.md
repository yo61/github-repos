## Decision: four choices for bringing yo61's live repositories under the `dependency-updates` rule (every pin has exactly one owner):

1. **A new private `yo61/infrastructure` repository holds yo61's Renovate workflow**, covering every live yo61 repository, flux-homelab included, with no policy of its own: each repository carries its own `renovate.json5`. It runs as a new `yo61-renovate` GitHub App whose credentials live in 1Password.
2. **Workflows pin `runs-on: ubuntu-26.04`**, and Renovate proposes the next image.
3. **actionlint comes from the maintained fork `kjanat/actionlint`** (module `actionlint.kjanat.dev`), pinned by version, in pre-commit and in CI.
4. **The commitlint hook's `@commitlint/config-conventional` is pinned exactly**, with a Renovate regex manager grouped with the hook's `rev`.

## Context: the audit of 2026-10-09 (24 live yo61 repositories, after the twelve dormant ones were archived in `decisions/2026-10-09-archive-dormant-yo61-repos.md`) found most unowned pins were Renovate's kind, and no Renovate workflow covered any yo61 repository but flux-homelab. flux-homelab's workflow passes its own `renovate.json5` as the global config, so pointing it at other repositories would give them flux-homelab's automerge and cluster-specific rules as defaults. Its App's credentials are not in 1Password.

`ubuntu-latest` floated everywhere. Ubuntu 26.04 has been generally available since 2026-09-17, and `ubuntu-latest` moves to it between 2026-10-19 and 2026-11-19 (actions/runner-images#14748). Upstream actionlint's last release, 1.7.12 (2026-03-30), rejects the `ubuntu-26.04` label, its last commit is from 2026-04-19, and rhysd/actionlint#719 records the author as inactive and points to `kjanat/actionlint`, which released v1.13.0 to v1.17.0 since. v1.17.0 accepts `ubuntu-26.04` and lints horopter-dev's workflows clean, checked on 2026-10-09.

`@commitlint/config-conventional@^21.2.3` in `additional_dependencies` floated in about twelve repositories, and neither bot moves it.

## Alternatives considered:

Put to Robin on 2026-10-09:

- **Where the Renovate workflow lives:** extend flux-homelab's (rejected: its config would become every repository's defaults); a second workflow in github-repos beside flux-homelab's; move flux-homelab's into github-repos. Robin chose a new `yo61/infrastructure`, matching horopter-dev and the skill, which keeps it out of github-repos' Terraform work.
- **`runs-on`:** pin `ubuntu-24.04` and move later, or keep `ubuntu-latest` and record why. Robin chose `ubuntu-26.04`.
- **actionlint with `ubuntu-26.04`:** stay on upstream with an `actionlint.yaml` declaring the label in every repository, or use the fork. Robin chose the fork. No other tool replaces actionlint's expression type-checking and ShellCheck integration; zizmor, check-jsonschema, action-validator, ghalint and poutine each cover a narrower job.
- **commitlint:** keep the range and record why, or pin exactly with Renovate (taken).

## Reasoning: one Renovate workflow per org, with policy only in each repository, is the shape horopter-dev runs and the skill prescribes. Pinning the runner image makes its change a reviewed pull request rather than GitHub's switch. The fork is the one maintained actionlint, and it removes the per-repository workaround. An exact commitlint pin is a pin with an owner.

## Trade-offs accepted:

- **actionlint is now one person's fork** (44 stars on 2026-10-09). Pinned by version, with build-provenance-attested releases.
- **Two Renovate Apps exist until flux-homelab moves to `yo61-renovate`**, and flux-homelab's own workflow is removed in the same change that adds it to the new one's targets.
- **Each repository carries a full `renovate.json5`**, as in horopter-dev.

## Supersedes: none.
