## Decision: every locally-cloned yo61, horopter-dev and ycst-org-uk repository with workflows lints them with `jdx/jactionlint` 2.2.0, except forks that track upstream

Each repository is swapped on `profile: correctness`, then moved to `profile: default` with its
findings fixed in a second PR, or in one PR when `default` reports nothing. The rollout starts
on 2026-10-21, once 2.2.0 clears the 7-day `minimumReleaseAge`. Playbook:
`docs/jactionlint-migration.md`. Repository list and order:
`docs/superpowers/plans/2026-10-15-jactionlint-rollout.md`.

## Context: on 2026-10-15 the 30 in-scope repositories ran `rhysd/actionlint` 1.7.12 (15),
the `kjanat/actionlint` fork (8), or nothing (7 with workflows but no linter). Item 3 of
`2026-10-09-yo61-dependency-update-remediation.md` had chosen kjanat, and half the yo61
repositories were never moved to it. mise's registry now marks `actionlint` deprecated in favour
of `jdx/jactionlint`. yo61/kuard moved to jactionlint the same day (its
`decisions/2026-10-15-jactionlint.md`), and the `default` profile found eight errors there,
including workflow-wide `packages: write` and a cache restored in the job that pushes the image.

Scope is the local clones under `~/code/github.com`, which stand in for "recently active".
Forks kept to sync with upstream (yo61/{brew, civicrm-core, lastlight, tns-csi},
robinbowes/PrincetonReverbUpdate) are excluded. Owned forks that have diverged (kuard,
commitlint-github-action) are included. yo61/homebrew-tap is excluded because `brew style` runs
its own actionlint.

## Alternatives considered:

Put to Robin on 2026-10-15:

- **Stay on `kjanat/actionlint` and finish moving the rhysd repositories to it.** Drop-in, but
  it has no security rules, and mise points away from it.
- **Start now on 2.2.0 with a release-age exception, or on 2.1.0 from 2026-10-17.** Rejected
  in favour of waiting until 2026-10-21, so no repository needs an exception.
- **Shared docs in `claude-plugin-dependency-updates` or left in kuard.** Rejected: this repo
  already holds the cross-org decisions.
- **commitlint-github-action on kuard's mise recipe.** Rejected: it has only Dependabot, which
  can't update a `mise.toml` pin. It gets a pre-commit config and a prek `lint` job instead.

## Reasoning: one linter across the fleet, maintained and named by mise as actionlint's
successor, whose `correctness` profile is a drop-in for what each repository checks today. The
two-phase split keeps the tooling change separate from workflow changes that can alter how a
repository builds or publishes. Each pin keeps its current updater, so no repository changes
which bot owns what.

## Trade-offs accepted:

- jactionlint is one person's project, created 2026-10-05, and v2.0.0 changed its CLI.
  Pinned by version, with releases that pass `gh attestation verify`.
- zizmor stays alongside it, though jactionlint's `default` profile overlaps it. Whether one
  replaces the other is decided after phase 2 shows the overlap.
- Up to two PRs per repository instead of one.
- Repositories on rhysd or kjanat stay there until their turn in the rollout.

## Supersedes: item 3 of `2026-10-09-yo61-dependency-update-remediation.md` (actionlint from
`kjanat/actionlint`). Items 1, 2 and 4 stand.
