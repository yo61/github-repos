## Decision: Squash-merge release-please repos. No merge-commit configuration can prevent duplicated changelog entries, so the merge method is the only lever. Incidentally adds `nullable = false` to the four merge/squash commit-message variables, which were declared but never actually managed.

## Context: release-please PR yo61/unifi-mcp#44 (`chore(main): release 0.2.2`) listed the same change twice:

```
* **deps:** Bump js-yaml to 4.3.1 for CVE-2026-59870 (5674005)   <- merge commit
* **deps:** Bump js-yaml to 4.3.1 for CVE-2026-59870 (bfa9057)   <- original commit
```

With `merge_commit_message: PR_TITLE`, GitHub puts the PR title in the merge commit body. Where that title is itself a conventional-commit string — the convention across these repos — release-please parses both the merge commit and the original and emits an entry for each.

Not new: `unifi-mcp` v0.2.1 shipped with two duplicated pairs, and the same pattern is visible in `unifictl` and `claude-skills`. Only `jobhound` has a clean changelog, and its entries carry `(#N)` PR references — release-please's signature for a squash merge.

## Alternatives considered:

- **`merge_commit_message: BLANK` as a module default.** Attempted and **rejected as impossible**. GitHub returns 422 `invalid_merge_commit_setting_combo`: the only valid title/message pairs are `PR_TITLE`+`PR_BODY`, `PR_TITLE`+`BLANK`, and `MERGE_MESSAGE`+`PR_TITLE`. `MERGE_MESSAGE`+`BLANK` is not permitted.
- **Any other merge-commit combination.** Rejected: all three legal pairs place the conventional PR title where release-please reads it.

  | Combination | PR title lands in | Parsed |
  | --- | --- | --- |
  | `MERGE_MESSAGE` + `PR_TITLE` | commit body | yes |
  | `PR_TITLE` + `BLANK` | commit subject | yes |
  | `PR_TITLE` + `PR_BODY` | commit subject | yes |

  There is no merge-commit configuration that avoids duplication while PR titles are conventional.
- **Stop writing conventional-commit PR titles.** Rejected: the titles are useful in the PR list, and this relies on every future contributor and agent remembering.
- **Disable merge commits (`allow_merge_commit: false`).** Rejected as heavier than needed, and it removes a method that is occasionally the right one. Revisit if squashing is forgotten repeatedly.
- **Squash-merge.** Chosen. It is the only mechanism that works, and `jobhound` already demonstrates it.

## Reasoning: Squashing produces one commit on `main` per PR, so there is nothing to duplicate. It also yields the `(#N)` cross-references that make history navigable, which the merge-commit repos lack.

This is a practice, not a control, and that is a real weakness — it was forgotten on `unifi-mcp` #43 and #36 within two days, which is what produced the duplicates in 0.2.1 and 0.2.2. It is accepted only because the config route was investigated and proven impossible, not because practice is preferred to enforcement. If it is forgotten again, the next step is `allow_merge_commit: false` on the release-please repos, which makes it enforceable.

## The four merge-message variables were never actually managed

Discovered while attempting the config route: changing the `merge_commit_message` module default produced an **empty plan**.

`modules/org/main.tf:58` passes the value through with a null fallback:

```hcl
merge_commit_message = lookup(each.value, "merge_commit_message", null)
```

An explicitly-passed `null` falls back to a variable's default **only** when the variable declares `nullable = false`. Without it the variable is genuinely `null`, the provider omits the attribute, and Terraform does not manage the setting — GitHub's own default applies.

That is why every repo reported `merge_commit_message: PR_TITLE` with no per-repo overrides. It was never Terraform's value; it was GitHub's, showing through an unmanaged attribute. All four module defaults happen to equal GitHub's defaults, which is why the inertness was undetectable until one was moved off:

| Variable | Module default | GitHub default |
| --- | --- | --- |
| `merge_commit_message` | `PR_TITLE` | `PR_TITLE` |
| `merge_commit_title` | `MERGE_MESSAGE` | `MERGE_MESSAGE` |
| `squash_merge_commit_message` | `COMMIT_MESSAGES` | `COMMIT_MESSAGES` |
| `squash_merge_commit_title` | `COMMIT_OR_PR_TITLE` | `COMMIT_OR_PR_TITLE` |

`nullable = false` is added to all four so they are genuinely managed and stop being latent traps. Verified safe: all 28 managed repos currently match the module defaults exactly, so the plan should show no attribute changes.

`default_branch_ruleset_required_approving_review_count` already carries `nullable = false`, which is why the review-count change on 2026-08-06 worked as expected. Same module, same call pattern, opposite outcome, one line apart.

Audited the remaining `lookup(..., null)` pass-throughs in `modules/org`. The others without `nullable = false` all have `default = null` — `description`, `homepage_url`, `template`, `pages`, `security_and_analysis`, `branch_protection_rules_override`, `vulnerability_alerts`, `dependabot_security_updates` — so null is the intended value. Every `data/` file sets `vulnerability_alerts` explicitly, so no security setting is left unmanaged.

## Trade-offs accepted:

- Squash-merging is a habit with no enforcement. Accepted reluctantly; see Reasoning for the escalation path.
- Existing duplicated changelog entries are not repaired. `unifi-mcp` v0.2.1, and `unifictl`/`claude-skills` history, keep theirs. release-please regenerates CHANGELOG.md from git history, so hand-edits would be fought on the next release. Fixed forward only.
- `unifi-mcp#44` will still show the duplicate: `5674005` is already written as a merge commit, and this change cannot rewrite history. 0.2.2 ships with it; 0.2.3 onward is clean if squashed.
- `nullable = false` makes Terraform start managing four attributes it previously ignored. Verified as a no-op today, but a repo whose merge settings are changed by hand in future will now be reverted on the next apply. That is the intended behaviour of managing them.

## Supersedes: none. No prior decision covers merge strategy; `decisions/` was checked before proposing this.
