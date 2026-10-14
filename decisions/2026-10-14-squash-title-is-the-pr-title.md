## Decision: the squash commit's subject is always the PR title. The module default for `squash_merge_commit_title` becomes `PR_TITLE`, from `COMMIT_OR_PR_TITLE`, on every managed repo.

## Context: Robin, on 2026-10-14: "Set squash titles to PR_TITLE in github-repos". Writing the `horopter-dev` organisation's `CONTRIBUTING.md` (horopter-dev/.github #4) found every repo on `COMMIT_OR_PR_TITLE`, under which a single-commit PR squashes under the commit's own subject and only a multi-commit PR takes the PR title. `horopter-dev/horopter`'s and `horopter-dev/helm-charts`' `CONTRIBUTING.md` both tell contributors the PR title is what lands on `main`, which held only for multi-commit PRs.

## Alternatives considered:

- **Keep `COMMIT_OR_PR_TITLE` and correct the contributing guides** to ask for conventional commit subjects as well as titles. Rejected: two lines decide one subject, and which one wins depends on how many commits the PR has.
- **`horopter-dev` only**, as a per-repo setting in each data file. Rejected for the reason `decisions/2026-10-09-squash-only-by-default.md` gives for squash-only itself: one rule everywhere is stated as a module default, and a new repo inherits it.

## Reasoning: `decisions/2026-10-09-squash-only-by-default.md` chose "one commit per small PR, titled by the PR". `PR_TITLE` makes that literal. The title is the line a reviewer sees, the one GitHub's merge dialog pre-fills, and the one release-please reads once squashed. Under `COMMIT_OR_PR_TITLE` an unconventional commit subject on a one-commit PR reached `main`, and release-please, however good the title.

## Trade-offs accepted:

- **The module default now differs from GitHub's**, which `decisions/2026-08-07-blank-merge-commit-message.md` noted all four commit-message defaults shared. A repo outside Terraform keeps GitHub's `COMMIT_OR_PR_TITLE`.
- **The apply touches all 46 managed repos**, each with this one attribute and nothing else (plan of 2026-10-14: 0 to add, 46 to change, 0 to destroy).
- **The squash body is unchanged**: `squash_merge_commit_message: COMMIT_MESSAGES` still lists the PR's commits.

## Supersedes: `decisions/2026-10-06-squash-only-release-please-repos.md`'s trade-off "The squash commit's subject is the PR title for multi-commit PRs (`COMMIT_OR_PR_TITLE`)"; it is now the PR title for every PR. Amends the default table in `decisions/2026-08-07-blank-merge-commit-message.md`.
