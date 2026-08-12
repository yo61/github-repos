## Decision: Make `dismiss_stale_reviews_on_push` a per-repo variable (module default unchanged at `true`) and set it `false` on `homebrew-tap` alone

`homebrew-tap`'s release automation pushes a commit to the PR branch *after* the
approving review and then merges that branch. With dismissal on, the push
dismisses the very approval the merge depends on, and the release cannot land.
The knob was hardcoded in `modules/github-repo/data/rulesets.yaml`, so there was
no way to change it for one repo. It is now variable-driven — the same treatment
`required_approving_review_count` and `require_last_push_approval` already get —
defaulting to `true`, so every other repo is unaffected.

## Context

`eabc303` ("bring homebrew-tap and reportlab-pdf back under the policy", #62)
set `default_branch_ruleset_required_approving_review_count: 1` on the tap at
2026-08-11 22:05 UTC; the ruleset applied at 22:37:56 UTC. `homebrew-tap#104`
(an automated jobhound 0.18.0 bump) was opened at 23:38 UTC — the first release
bump to run under the new policy. It failed:

1. `publish-bottles.yaml` builds bottles, uploads them to the release, then
   commits the `bottle do` block to the bump branch via `createCommitOnBranch`.
2. That push dismissed `yo61-lastlight[bot]`'s approval
   (`dismiss_stale_reviews_on_push: true`).
3. The workflow's squash-merge then failed five times over ~35s with
   `Repository rule violations found — At least 1 approving review is required
   by reviewers with write access` (HTTP 405).
4. lastlight re-approved at 01:23:20 UTC, ~40s after the workflow gave up.
5. The automatic retry (a second `workflow_run` from the push) failed *earlier*,
   at `brew pr-upload`: `Validation Failed: ReleaseAsset already_exists`. The
   upload step is not idempotent, so the pipeline cannot recover on its own.

The bottle assets, the bottle commit, and green CI all exist; only the merge is
blocked. This is structural, not a one-off: every release bump pushes after
review, so every release would fail the same way.

## Alternatives considered

- **Set `dismiss_stale_reviews_on_push: false` in the module default.** Rejected:
  `[[2026-08-06-unifi-mcp-ci-only-gate]]` already rejected exactly this ("Fixing
  release-PR friction by weakening the approval-to-code binding was the wrong
  trade") and recorded that the `true` default "stays as the module default
  fleet-wide". Nothing has changed to invalidate that reasoning for the other
  repos — the tap is distinctive in that its automation pushes after review.
- **Drop the tap's `required_approving_review_count` to 0**, the
  `[[2026-08-06-unifi-mcp-ci-only-gate]]` shape: with no approval to dismiss,
  dismissal becomes a no-op. Rejected here: #62 deliberately brought this repo
  *under* the review policy a day earlier, and reverting that within 24 hours
  discards the intent rather than accommodating it. Also worth noting the tap's
  own `2026-07-13-signed-commits-via-api-drop-bypass` recorded 0 approvals, so
  this would have been a return to the prior state, not a novel relaxation.
- **Leave Terraform alone; fix the pipeline** — widen `publish-bottles.yaml`'s
  merge retry past lastlight's ~2min re-review and make the asset upload
  idempotent. Not chosen as the primary fix (it leaves the workflow racing a
  dismissal it causes itself), but the idempotency half remains worth doing
  independently; see Trade-offs.

## Reasoning

- **The dismissal rule and this pipeline are incompatible by construction.** The
  rule exists to stop code changing after a human approved it. Here the approver
  is a bot, and the post-approval push is a machine-generated bottle block whose
  content is derived from the very CI run that approved the branch. The property
  the rule protects is not the property at risk.
- **Per-repo, not fleet-wide, keeps the earlier decision intact.** Adding the
  variable with `default = true` means the other nine repos produce an identical
  plan; only `homebrew-tap` deviates, and it says so in its own YAML with a
  comment pointing at #104.
- **Follows the established plumbing.** `bypass_actors`,
  `required_approving_review_count` and `require_last_push_approval` are already
  injected from variables rather than hardcoded in the ruleset catalog; the
  in-code comment states the reason ("so each org / repo can supply its own
  without forking the ruleset catalog"). Moving `dismiss_stale_reviews_on_push`
  out of the YAML into a variable extends that pattern rather than inventing one.

## Trade-offs accepted

- On `homebrew-tap`, an approval now survives *any* later push to the branch,
  including a hand-pushed one, not just the bottle commit. Accepted: the repo's
  approvals come from lastlight on every push anyway, and its status-check gate
  is unchanged.
- `publish-bottles.yaml` keeps a non-idempotent upload step, so a failed run
  still cannot be re-run cleanly. This change removes the cause of the failure
  rather than making recovery work; the retry path is a separate fix.
- One more knob on the module surface. Bounded — it mirrors three existing ones
  and defaults to current behaviour.

## Supersedes

None. `[[2026-08-06-unifi-mcp-ci-only-gate]]` stands unchanged: its rejection was
of altering the *module default*, which this preserves at `true`.
