## Decision: make squash the only merge button on three release-please repos — `horopter-dev/horopter`, `horopter-dev/helm-charts` and `yo61/claude-plugin-lastlight-pr-gate`. `allow_merge_commit: false` and `allow_rebase_merge: false` in each data file. This is the escalation `decisions/2026-08-07-blank-merge-commit-message.md` reserved for "if squashing is forgotten again".

## Context: horopter's 0.4.0 and 0.4.1 release PRs listed every change twice, once for the commit and once for the merge commit carrying the PR title, exactly as unifi-mcp's did in August. horopter-dev was created on 2026-09-21, after the squash practice was chosen, and nothing carried the practice over: horopter has 9 merge commits in its last 30 and helm-charts 2. claude-plugin-lastlight-pr-gate, in yo61 and so covered by the practice from the start, has 11.

`merge_commit_message: BLANK` was tried again on horopter before this record was found, and failed with the same 422 the 2026-08-07 record documents. That record had already ruled out every merge-commit combination.

## Alternatives considered:

- **Keep squash as a practice, and remind.** Rejected. It has now failed on three more repos, two of them in an org created after the practice was written down. A rule nobody is shown at merge time is not followed.
- **Rebase-only, as `unifictl` chose.** Rejected for these three. horopter's releases are curated to one changelog line per PR, so squash already gives the wanted shape, and its PR links (`(#N)`). Rebase would list each commit of a multi-commit PR. `unifictl`'s reason, a PR that is both a fix and a feature, has not come up here; such a PR would be split in two.
- **Change the module defaults for every repo.** Rejected as out of proportion, as on 2026-09-04: repos without release-please have no changelog to duplicate into. `infrastructure` and `horopter-internal`, which have no release-please workflow, are left as they are.

## Reasoning: the merge method is the only lever, and only the buttons GitHub shows are enforceable. With one button, the release PRs and every feature PR squash, and release-please sees each change once.

## Trade-offs accepted:

- **A multi-commit PR's individual commits stay on the PR, not on `main`.** The squash commit's body keeps their messages (`squash_merge_commit_message: COMMIT_MESSAGES`), but release-please reads only the subject, so a `feat:` in the body is not released as one. Split such a PR instead.
- **The squash commit's subject is the PR title for multi-commit PRs** (`COMMIT_OR_PR_TITLE`), so PR titles must stay conventional. They already are.
- **Auto-merge on claude-plugin-lastlight-pr-gate is left with one method.** It had no armed PRs when this was applied; re-enabling a method later is the way to unstrand any that are armed with it.
- **The existing duplicated entries stay in the GitHub release history** for horopter v0.4.0 and v0.4.1, which were curated by hand instead.

A finding against the 2026-08-07 record: it gave "release-please regenerates CHANGELOG.md from git history, so hand-edits would be fought on the next release" as the reason not to repair old entries. horopter's hand-curated 0.4.0 section survived the 0.4.1 release unchanged; release-please prepends the new section and leaves earlier ones alone. Repairing old entries is cheaper than that record assumed.

## Supersedes: `decisions/2026-08-07-blank-merge-commit-message.md` in part, for these three repos: squash becomes enforced rather than practised. Its finding that no merge-commit configuration avoids the duplicates stands.
