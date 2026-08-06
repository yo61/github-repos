## Decision: Gate `unifi-mcp` on CI alone — drop `default_branch_ruleset_required_approving_review_count` to the module default of 0, following removal of that repo's Claude review workflow.

## Context: `unifi-mcp` is removing `.github/workflows/claude-code-review.yaml` (unifi-mcp PR #42), the only automated approver it had. The review-count rule would then be satisfiable only by a manual approval or the repo-admin bypass — and since GitHub forbids self-approval and Robin authors nearly every PR there, that means an admin merge on essentially every PR.

The investigation that led here started with release-please PR #37 stalling at `BLOCKED / REVIEW_REQUIRED` for ~40 minutes: release-please rewrites its branch whenever `main` moves, and `dismiss_stale_reviews_on_push: true` dismissed each freshly-granted approval. Auditing that turned up three facts:

- **`CLAUDE_REVIEW_ENABLED` is set on `unifi-mcp` alone** across all ten review-gated/auto-merge repos. The `claude-review` workflow gates on it, so no other repo has ever run an automated review.
- **The review requirement is satisfied by bypass, not review, everywhere else.** Verified on merged release PRs `jobhound#140`, `unifictl#18`, `unifictl#16` — each has zero reviews of any state and `merged_by: robinbowes`, i.e. the `RepositoryRole` 5 always-bypass.
- **`allow_auto_merge: true` on `unifi-mcp` has never been armed on a single PR.** The capability is enabled at repo level and has never been used, so nothing depended on an approval arriving automatically.

## Alternatives considered:

- **Keep `required_approving_review_count: 1` and admin-merge every PR.** Rejected: it makes the rule a formality that is bypassed on every single merge, which is worse than not having it — a control that is always overridden trains you to override it.
- **Set `dismiss_stale_reviews_on_push: false` in the module default.** Rejected earlier in this investigation: it is a no-op on nine repos (no approvals exist to dismiss) and removes a working control on the tenth, where `allow_auto_merge` is on and the package publishes to npm with provenance. Fixing release-PR friction by weakening the approval-to-code binding was the wrong trade.
- **Keep the review workflow and live with the friction.** Rejected in unifi-mcp PR #42: it left one repo on a pre-lastlight mechanism, spending Anthropic tokens per push, and made a fleet-wide question look like a repo-specific bug.
- **Drop the review count; keep the no-bypass status-checks ruleset as the gate.** Chosen.

## Reasoning: The `Required status checks` ruleset for `unifi-mcp` has **no bypass actors** and lists six contexts — `check (node 22)`, `check (node 24)`, `Conventional Commits`, `zizmor`, `osv-scanner`, `sbom-scan`. That is the part of the gate that actually catches problems, and it binds everyone including repo admins. The review-count rule on the built-in ruleset does have an admin bypass, so as the sole remaining human-review requirement it would be satisfied by override on every merge rather than by review.

Removing it makes the enforced policy match the practised one, and leaves the genuinely-unbypassable half in place. This is the same posture as the other nine repos, reached deliberately rather than by drift.

## Trade-offs accepted:

- No human-approval requirement on `unifi-mcp`. An external fork PR can merge on green CI alone, with no second pair of eyes. Accepted because the previous "second pair of eyes" was an automated reviewer whose approval the admin bypass could override anyway, and because CI includes `osv-scanner` and `sbom-scan` with no bypass.
- `dismiss_stale_reviews_on_push: true` stays as the module default fleet-wide. It becomes a no-op on `unifi-mcp` too, since there is no longer any approval to dismiss. The trade-off accepted in 2026-07-30 and 2026-08-03 is unchanged and not superseded.
- If an automated approver is ever reintroduced on this repo, the review count must be restored alongside it; the two only make sense together.

## Open question, not decided here: `claude-skills#34` and `gh-release-stats#19` are `merged_by: yo61-lastlight[bot]` with zero reviews, while `claude-plugin-reportlab-pdf#18` — the repo the policy was modelled on — was merged by hand. lastlight is therefore merging via some path other than `claude-review` (which cannot see Dependabot PRs by design: its sandboxed secrets do not expose the token). Two mechanisms share one bot name, which is not visible in the Terraform. Worth auditing before extending 2026-08-03.

## Supersedes: none. Narrows the application of 2026-08-03-plugin-repos-review-gated-automerge for `unifi-mcp` only; that decision's reasoning for the other repos is unaffected.
