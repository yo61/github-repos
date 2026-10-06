## Decision: make squash the only merge button on `yo61/flux-homelab`. `allow_merge_commit: false` and `allow_rebase_merge: false` in `data/yo61/flux-homelab.yaml`.

## Context: flux-homelab does not run release-please, so `decisions/2026-10-06-squash-only-release-please-repos.md`'s reason does not apply. Its commit subjects matter for a different reason: Horopter records every commit Flux reconciles as a change, and source-controller's `NewArtifact` event names the commit by its subject, truncated to about 50 characters. That subject is what a Grafana annotation of the rollout can say.

With merge commits, the subject Flux reports is `Merge pull request #589 from yo61/fix/horopter-v0....` — the branch name, cut off. With squash, it is the PR title, `fix(horopter): roll out v0.5.2`, which already follows Conventional Commits here and fits within the truncation.

## Alternatives considered:

- **Keep merge commits and read the PR title from the merge commit's body.** Rejected: Flux's event carries only the truncated subject line, not the body.
- **Rebase-only, as `unifictl`.** Rejected: a multi-commit PR would reconcile as several revisions in quick succession, and the one Flux reports last need not describe the PR.
- **Record the change some other way in Horopter** (reading Helm values or Kubernetes objects). Rejected for now as a new capability rather than a fix.

## Reasoning: one commit per PR, titled by the PR, is both what Flux reports and what a reader of the annotation needs to recognise the change.

## Trade-offs accepted:

- **A multi-commit PR's individual commits stay on the PR, not on `main`.** flux-homelab's history becomes one commit per PR.
- **PR titles must stay short and descriptive**, since about 50 characters of them reach the annotation.
- **Renovate's automerge now squashes.** Its `automergeStrategy` is the default `auto`, which uses the method the repo allows; no open PR had auto-merge armed when this was applied.

## Supersedes: none. Extends the practice of `decisions/2026-10-06-squash-only-release-please-repos.md` to a repo outside its scope, for its own reason.
