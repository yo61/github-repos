# Dependency updates — hypotheses (need more data)

Promote to `rules.md` after three confirmations; record each one below.

## Merge the broadest Renovate security PR first

When Renovate opens several `[security]` PRs for modules in the same family (e.g.
`golang.org/x/*`), the one whose diff moves the most modules is a superset of the rest.
Merging it first leaves the others redundant, avoiding a conflict on every one of them.

What would disprove it: a narrower PR that pins some module *higher* than the broad one does,
so closing it would lose a fix.

Confirmations:

- 2026-10-12 — kuard #45 (x/net) superseded #43, #44 and #46.

## Swap a linter on its compatible profile first, tighten in a second PR

Moving a repository to a stricter linter goes cleanly in two pull requests: the first swaps the
tool on the profile that matches the old one (jactionlint's `correctness`), with no workflow
changes; the second turns on the stricter profile and fixes its findings. Each PR stays
reviewable, and the second can change how the repository builds or publishes without being
hidden in a tooling change. Playbook: `../../docs/jactionlint-migration.md`. Rollout:
`../../docs/superpowers/plans/2026-10-15-jactionlint-rollout.md`.

What would disprove it: a repository where the compatible profile still fails on day one (for
example, an `actionlint.yaml` without `profile` silently selecting `default`), or where the
second PR's findings were trivial enough that splitting only added overhead.

Confirmations:

- 2026-10-15 — kuard: #60 (swap) and the follow-up (default profile, 8 findings).
