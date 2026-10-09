## Decision: squash is the only merge button on every managed repo. The module defaults become `allow_merge_commit = false` and `allow_rebase_merge = false`, and the data files that restated them drop those lines. `unifictl` moves from rebase-only to squash-only with the rest.

## Context: Robin, on 2026-10-09: "All repos should use squash commits - we aim to create small, focussed PRs and squash merge them, so any CHANGELOG can be curated easily."

Squash had been enforced repo by repo: three release-please repos and `flux-homelab` on 2026-10-06, each for its own reason. The rest kept all three buttons. So `horopter-dev/infrastructure` and `horopter-dev/horopter-internal` merged with merge commits while their siblings squashed. When both were switched to squash-only by API the same day, nothing here recorded it, and the next apply would have switched them back. `unifictl` had gone rebase-only on 2026-09-04, because a squash dropped a `feat:` commit from its 0.5.4 changelog.

## Alternatives considered:

Put to Robin on 2026-10-09:

- **Scope: every org, as the module default** (taken), against **`horopter-dev` only**, setting the two flags in `infrastructure.yaml` and `horopter-internal.yaml`.
- **`unifictl`: move it to squash** (taken), against **keeping it rebase-only** as the one recorded exception, with `allow_rebase_merge: true` and `allow_squash_merge: false` set explicitly against the new defaults.

## Reasoning: one button everywhere is the rule Robin stated, and a default is how this repo states a rule. A repo created later starts squash-only without anyone remembering to say so. The 2026-10-06 record rejected this as "out of proportion" because repos without release-please have no changelog to duplicate into. The reason now is broader than duplication: one commit per small PR, titled by the PR, is the history Robin wants to curate from, with or without release-please.

`unifictl`'s case for rebase was a PR that was both a fix and a feature. Small, focused PRs answer that by splitting such a PR in two, which is what `decisions/2026-10-06-squash-only-release-please-repos.md` already asked of the release-please repos.

## Trade-offs accepted:

- **A multi-commit PR's individual commits stay on the PR, not on `main`.** `squash_merge_commit_message: COMMIT_MESSAGES` keeps their messages in the squash commit's body, but release-please reads only the subject.
- **A PR that is both a `fix:` and a `feat:` must be split**, in `unifictl` too.
- **The apply touches every repo that still allows merge or rebase**: all of `ycst-org-uk`, nearly all of `yo61`, and `horopter-dev`'s `infrastructure` and `horopter-internal`. No open PR had auto-merge armed on 2026-10-09, so no armed PR loses its method.
- **`unifictl`'s own `decisions/2026-09-03-rebase-only-merge-policy.md`, in that repo, still describes rebase-only** until it is superseded there.

## Supersedes: `decisions/2026-10-06-squash-only-release-please-repos.md` (its rejection of a module-wide default) and `decisions/2026-09-04-unifictl-rebase-only-merge-buttons.md`. `decisions/2026-10-06-squash-only-flux-homelab.md` and `decisions/2026-08-07-blank-merge-commit-message.md`'s finding that no merge-commit configuration avoids duplicated changelog entries both stand; their repos are now squash-only by default.
