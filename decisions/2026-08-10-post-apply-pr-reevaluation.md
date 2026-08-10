## Decision: Generalise the post-apply PR step from `2026-08-04-gate-apply-ordering-and-classic-protection-drift` **(b)**. After any apply that changes a gate, re-trigger **every open PR whose blocker the apply changed** — not only already-reviewed dependency PRs. Re-arming auto-merge (`gh pr merge --disable-auto` then `--auto`) is the cheapest trigger and does not re-run CI. Treat `MERGEABLE` + `CLEAN` + all-checks-green as **insufficient** evidence that a PR will merge on its own.

## Context: `unifi-mcp#51` replaced the standalone `zizmor` job with a `lint` job running the whole pre-commit suite. The repo's ruleset required a status context named `zizmor`, so the PR could not pass: a required check with no producer never reports. `github-repos#50` swapped that requirement for `lint` and `secrets`.

The sequence:

| time (UTC) | event |
| --- | --- |
| 13:59:05 | last event on the PR |
| 14:02:44 | auto-merge armed by `robinbowes` — while still `BLOCKED` |
| 14:27:54 | ruleset updated by the apply; the block is now gone |
| — | nothing happens |
| 14:31:55 | merges, 3 seconds after auto-merge was toggled off and on |

GitHub re-evaluates a PR's mergeability on **PR events** — a push, a check run completing, a review. A repository-settings change is not a PR event. So the PR sat armed and unblocked with all seven required contexts green, and would have sat there indefinitely.

The state was actively misleading: `mergeable: MERGEABLE`, `mergeStateStatus: CLEAN`, `autoMergeRequest` present, every check `pass`. Every observable said it should merge. Diagnosis needed comparing the ruleset's `updated_at` against the PR's `updated_at` — the only two values that expose the ordering.

This is the same failure as 2026-08-04 (b), which covers *"a PR reviewed while its repo lacked `allow_auto_merge` stays stranded after the gate goes live, because nothing revisits it"*. That wording is scoped to reviews and to `allow_auto_merge`, so it did not fire here, and the rollout was followed correctly. The underlying property is broader than the instance it was written from.

## Alternatives considered:

- **Amend 2026-08-04 (b) in place.** Rejected: the decisions directory is a journal. Editing a decision to cover a case found six days later loses the fact that the original scoping was too narrow, which is itself the useful signal.
- **Push an empty commit to re-trigger.** Rejected as the default: it changes the head SHA and re-runs the full CI matrix — on `unifi-mcp` that is two Node versions plus `osv-scanner` and `sbom-scan`, several minutes, to work around a state-refresh problem. Toggling auto-merge costs one API round-trip and re-runs nothing.
- **Close and reopen the PR.** Works, but generates more notification noise and, on a release-please branch, invites the bot to recreate the PR with different content.
- **Rely on lastlight's `cron-dependabot-merge` backstop.** Rejected for the same reason 2026-08-04 rejected it: it did not recover the three stranded PRs then, and the workflow's per-head-SHA dedup makes a config change invisible to a PR already assessed at that SHA. A settings-only change never moves the SHA.
- **Automate it: sweep open PRs after an apply and re-arm any that are green-but-unmerged.** Deferred, not rejected. 2026-08-04 already deferred the automation of its own step; this widens what such a sweep would need to cover, which strengthens the case without changing that it is a follow-up.

## Reasoning: 2026-08-04's two additions were both cases of *a green rollout verification coexisting with a broken outcome*. This is a third, and the narrowest reading of (b) misses it, because (b) names a mechanism — a review, `allow_auto_merge` — rather than the property that makes the mechanism fail.

The property is that **GitHub's PR mergeability is cached against PR events, and an apply is not one**. Anything an apply changes — a required context appearing or disappearing, a review count, `allow_auto_merge` — leaves every open PR holding a verdict computed under the old rules. Whether that verdict was "blocked by a review requirement" or "blocked by a check that no longer exists" does not matter; nothing recomputes it.

Stating it that way makes the post-apply step derivable rather than a list of remembered instances, and it covers the shapes not yet seen: a required context *added* by an apply strands PRs that cannot produce it (`unifi-mcp#53` and `homelab-docs#19` both needed a rebase for exactly this reason on the same day), and a review count *lowered* leaves PRs still showing `REVIEW_REQUIRED`.

## Trade-offs accepted:

- **Still a manual step.** 2026-08-04 accepted this for its narrower version and deferred automation; widening the scope widens the manual burden in proportion. The honest position is that this is a procedure note until someone writes the sweep.
- **"Every open PR whose blocker the apply changed" requires judgement.** It is not mechanically checkable without the sweep, so in practice it means: after an apply, list open PRs across affected repos and look at anything green-but-unmerged. On a small fleet that is cheap; it would not scale.
- **Re-arming auto-merge merges the PR immediately if it is genuinely ready.** That is the intent, but it is not a dry run — the PR should be one you are content to land before toggling.
- **Diagnosis remains non-obvious.** Nothing surfaces "this verdict is stale"; it has to be inferred from timestamps. This decision tells a reader to suspect it, which is weaker than a check that detects it.

## Supersedes: none. Generalises `decisions/2026-08-04-gate-apply-ordering-and-classic-protection-drift.md` **(b)** from "re-trigger lastlight on already-reviewed dependency PRs" to "re-trigger any open PR whose blocker the apply changed". That decision's item (a), the classic-protection sweep, is unaffected.
