## Decision: Standardise the `reportlab-pdf` review-gated auto-merge policy across the recently-active **public** repos (civi-mcp cut-off, 13 repos), so lastlight lands Dependabot/bot PRs unattended without per-repo manual merges. Each repo gets: `allow_auto_merge: true`; the built-in `default_branch` ruleset with `required_approving_review_count: 1` plus a repo-admin (`RepositoryRole` 5) bypass; and a no-bypass in-code `additional_rulesets` "Required status checks" ruleset listing that repo's own check contexts. Private repos and repos with no CI checks are excluded.

## Context: `claude-plugin-contributory-factors` PR #18 (a green Dependabot bump) sat unmerged because the repo had `allow_auto_merge: false` and none of the review-gated machinery from PR #30 — the same chore lastlight (app 4367919, installed org-wide, `repository_selection: all`) was built to eliminate. Auditing the recently-active repos found three divergent states rather than one policy: `reportlab-pdf` and `go-udap` fully wired; `claude-skills`/`gh-release-stats`/`homebrew-tap` with `allow_auto_merge: true` but **no required checks** (auto-merge would land bot PRs with no CI gate); and the rest with auto-merge off. `contributory-factors` also carries an untracked `main branch protection` drift ruleset holding the sole copy of its required checks — the same drift PR #30 cleaned up on reportlab.

Scope was set by activity: Robin picked `civi-mcp` (last push 2026-06-11) as the cut-off. That selects 15 repos; the two private ones are then excluded (below), leaving 13 public repos:
`unifi-mcp, go-udap, homelab-docs, gh-release-stats, claude-skills, github-repos, claude-plugin-reportlab-pdf, claude-plugin-contributory-factors, jobhound, homebrew-tap, kuard, unifictl, civi-mcp`.

Current state and per-repo work:

| State | Repos | Work |
| --- | --- | --- |
| Done (flag + in-code CI-gate) | `claude-plugin-reportlab-pdf`, `go-udap` | none (templates) |
| Auto-merge ON, no CI gate | `claude-skills`, `gh-release-stats`, `homebrew-tap` | add required-checks ruleset |
| Auto-merge OFF, gate exists | `claude-plugin-contributory-factors` (drift), `jobhound` | add flag + review-count; convert drift→in-code |
| Auto-merge OFF, no CI gate | `unifi-mcp`, `homelab-docs`, `github-repos`, `kuard`, `unifictl`, `civi-mcp` | add flag + build a gate (designate a required check) |

## Alternatives considered:
- **Include the private repos (`flux-homelab`, `ycst-website-testing`).** Rejected: on the free-tier personal org, rulesets/branch-protection are paywalled (confirmed 403 "Upgrade to GitHub Pro"), so no CI gate can be enforced — auto-merge would degrade to merge-on-lastlight-approval with no checks. `flux-homelab` uses Renovate (not Dependabot) and only validates; `ycst-website-testing`'s e2e suite is currently red and unenforceable. Neither has open bot PRs, so there is no chore to solve there. Excluding them is Robin's "no auto-merge on private repos without tests" rule plus the harder billing constraint.
- **Enable `allow_auto_merge` alone, repo-by-repo.** Rejected: without a required-checks gate this is the `claude-skills` failure mode — bot PRs merge on approval with no CI. The flag is necessary but not sufficient; the gate is the point.
- **Express the whole policy as a module default in `modules/org`/`modules/github-repo`.** Rejected for the check contexts: `modules/org` fans out over *all* yo61 files including the dormant 2013–2017 tail, and required-check *contexts* differ per repo (`go-udap` has 8, `jobhound` 3, the plugins 3, several have none) — there is no single shared check list to default. The uniform parts (admin-role bypass) are already a module default from PR #32.
- **Fold checks into the built-in `default_branch` ruleset (one ruleset).** Rejected for the same reason as PR #30: ruleset bypass is per-ruleset all-or-nothing, so `semantic-release-pusher` would then also bypass CI. The separate no-bypass status-checks ruleset is what keeps release automation exempt from signatures while still bound by CI.

## Reasoning: The `reportlab-pdf` pattern (decision 2026-07-30) already solved this correctly for one repo; the divergent states above are drift from not having applied it consistently. The three-part policy maps to three guarantees: `allow_auto_merge` provides the merge mechanism; `required_approving_review_count: 1` on the built-in ruleset makes lastlight's approval the "vetted" clause (random/human PRs get no lastlight approval → blocked by GitHub, not by trusting an agent); the no-bypass status-checks ruleset is the "CI green" clause. The repo-admin bypass lets Robin self-merge without a second approval while still bound by CI. Per-repo YAML (the `additional_rulesets` block, as in `go-udap.yaml`) is the right expression because it naturally carries each repo's own heterogeneous check contexts, needs no module surgery, and matches the existing convention.

The four-state table drives execution order: the **auto-merge-ON-no-gate** repos (`claude-skills`, `gh-release-stats`, `homebrew-tap`) are the priority — they are currently the least safe, merging bot PRs with no CI gate. The **no-CI-gate** repos need a check designated required before the gate is meaningful; a repo with no CI check cannot have an enforceable gate, so any such repo is deferred until it has one rather than given ungated auto-merge.

## Trade-offs accepted:
- Per-repo YAML means the policy is repeated across ~11 files rather than defaulted once; accepted because the check contexts are genuinely per-repo and the uniform parts are small. Future plugin repos must copy the block (or we revisit a module default once the check set stabilises).
- Each in-code status-checks ruleset must be paired with deleting the corresponding untracked `main branch protection` drift ruleset out-of-band after apply (Stategraph does not manage it), starting with `contributory-factors`. Other repos in the set should be checked for the same drift during rollout.
- `dismiss_stale_reviews_on_push: true` on the built-in ruleset can dismiss lastlight's approval on a Dependabot rebase and briefly stall auto-merge until re-approval; acceptable at this update volume (carried over from PR #30).
- Repos with no CI checks (`kuard`, possibly `unifi-mcp`/`unifictl`/`homelab-docs`/`civi-mcp`/`github-repos`) get no auto-merge until they have a required check — they stay manual, which is the safe default, not a regression.
- Private repos remain a manual chore by necessity until they move off the free tier or public.

## Supersedes: none. Extends decision 2026-07-30-reportlab-pdf-automerge-review from one repo to the recently-active public set.
