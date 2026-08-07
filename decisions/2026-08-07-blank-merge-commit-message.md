## Decision: Default `merge_commit_message` to `BLANK`, and squash-merge release-please repos by preference. Fleet-wide module change: every managed repo's merge commits become title-only.

## Context: release-please PR yo61/unifi-mcp#44 (`chore(main): release 0.2.2`) listed the same change twice:

```
* **deps:** Bump js-yaml to 4.3.1 for CVE-2026-59870 (5674005)   <- merge commit
* **deps:** Bump js-yaml to 4.3.1 for CVE-2026-59870 (bfa9057)   <- original commit
```

With `merge_commit_message: PR_TITLE`, GitHub puts the PR title in the merge commit **body**. Where the PR title is itself a conventional-commit string — the convention across these repos — release-please parses both the merge commit and the original and emits an entry for each.

This is not new. `unifi-mcp` v0.2.1 shipped with two duplicated pairs, and the same pattern is visible in `unifictl` and `claude-skills`.

Three ingredients are required, and the fleet has all three: merge commits enabled, `merge_commit_message: PR_TITLE`, and conventional-commit PR titles. Removing any one stops it.

**The configuration is already uniform; the outcome is not.** All seven release-please repos (`gh-release-stats`, `claude-skills`, `unifictl`, `jobhound`, `unifi-mcp`, `claude-plugin-reportlab-pdf`, `claude-plugin-contributory-factors`) report identical settings — `allow_merge_commit: true`, `allow_squash_merge: true`, `merge_commit_message: PR_TITLE` — with no per-repo overrides in `data/`. Only `jobhound` has a clean changelog, and its entries carry `(#N)` PR references, release-please's signature for a squash merge. The divergence is which button is pressed at merge time, which the Terraform does not capture.

## Alternatives considered:

- **Squash-merge only, no config change.** Rejected as the sole fix: it is a habit, not a control. It was forgotten on `unifi-mcp` #43 and #36 within the last two days, and nothing in the repo would have caught it.
- **Set `merge_commit_message: BLANK` per-repo for the three affected.** Rejected: the setting is uniform across the fleet with no overrides, and repos adopting release-please later would inherit the broken default. Fixing the default fixes it once.
- **Stop writing conventional-commit PR titles.** Rejected: the titles are useful in the PR list, and this depends on every future contributor and agent remembering.
- **Disable merge commits entirely (`allow_merge_commit: false`).** Rejected as heavier than needed — it removes a merge method that is occasionally the right one, when the goal is only to stop the body being parseable.

## Reasoning: `BLANK` removes the cause rather than the symptom. The merge commit keeps its title (`Merge pull request #N from <branch>`, from `merge_commit_title: MERGE_MESSAGE`), which release-please ignores because it is not conventional. Nothing about the workflow changes and nothing has to be remembered.

Squash-merging is adopted alongside it as the preferred method for release-please repos, matching `jobhound`. It is complementary, not redundant: squashing also yields the `(#N)` cross-references that make history navigable, while `BLANK` is what guarantees correctness when a merge commit is used anyway.

## Trade-offs accepted:

- Fleet-wide default change: every managed repo gets `merge_commit_message = BLANK` on the next apply, not only the three with visible duplication. Intended — the setting was uniform before and stays uniform.
- Merge commit bodies lose the PR title. Minor loss of context in `git log` for merge commits, recoverable from the PR number in the title.
- Existing duplicated changelog entries are not repaired. `unifi-mcp` v0.2.1, and `unifictl`/`claude-skills` history, keep theirs. release-please regenerates CHANGELOG.md from git history, so hand-edits would be fought on the next release. Fixed forward only.
- `unifi-mcp#44` is held until this applies, so 0.2.2 ships with a clean changelog.

## Supersedes: none. No prior decision covers merge strategy; `decisions/` was checked before proposing this.
