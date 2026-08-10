## Decision: Private repos in `yo61` get a **manual** final review/approval instead of an enforced merge gate, and stay at `builtin_ruleset_names: []`. Public repos get the enforced gate — required status checks plus `required_approving_review_count: 1`.

## Context: Rolling markdown/MDX linting, prek and gitleaks across the fleet added `lint` and `secrets` jobs to four repos, and those jobs needed to become required checks to actually gate anything. Three of the fleet's repos are private — `flux-homelab`, `ycst-admin-docs`, `ycst-website-testing` — and the question was whether they could take the same gate.

They cannot. The `yo61` org is on the **free** plan, and both enforcement APIs refuse private repos:

```
GET /repos/yo61/ycst-admin-docs/rulesets
403: Upgrade to GitHub Pro or make this repository public to enable this feature.

GET /repos/yo61/ycst-admin-docs/branches/main/protection
403: (identical message)
```

Rulesets and classic branch protection are disjoint APIs (per
`2026-08-04-gate-apply-ordering-and-classic-protection-drift`), so this is not one
mechanism being unavailable — it is both. `modules/github-repo/variables.tf` already
documents the constraint on `builtin_ruleset_names`, and all three private repos
already carry `[]`. What was missing was a stated policy for what replaces the gate.

## Alternatives considered:

- **Make the private repos public.** Rejected: `ycst-admin-docs` is York City Supporters Trust board material, and `2026-08-04-ycst-admin-docs-private-cpanel` chose private deliberately, deploying to Krystal cPanel rather than Pages. Visibility is a governance decision, not a lever to pull for CI ergonomics.
- **Upgrade the org to GitHub Team.** Rejected for now: ~6 seats of recurring cost to enforce a gate on three repos, two of which see little traffic. Worth revisiting if the private set grows or one becomes multi-contributor — the cost is per-seat, so it scales with people rather than repos.
- **Declare `additional_rulesets` anyway and let apply fail.** Rejected: Terraform would 403 on every apply, turning a known platform limit into recurring breakage that masks real drift.
- **Drop CI on private repos, since it cannot gate.** Rejected: the checks still run and still report on every PR. Losing enforcement is not a reason to lose the signal.
- **Manual final review/approval, CI advisory.** Chosen.

## Reasoning: The distinction that matters is between *signal* and *enforcement*, and only enforcement is unavailable. CI runs on PRs in private repos exactly as it does elsewhere — `lint`, `secrets`, `build` all report — and lastlight can still review. What is missing is the mechanism that refuses the merge button.

Given that, the honest posture is to say so rather than to pretend. Writing an enforced-looking config that 403s, or requiring a review count with nothing to attach it to, would both produce a control that exists on paper and not in fact. `2026-08-06-unifi-mcp-ci-only-gate` already established the principle in the other direction: a rule satisfiable only by bypass is worse than no rule, because *"a control that is always overridden trains you to override it."* A control that cannot be applied at all is the same failure with extra steps.

Public repos take the full gate because they can: `civi-mcp` gains required `lint` and `secrets` plus review count 1, which is safe there specifically because lastlight already reviews that repo (it approved `civi-mcp#9`).

## Trade-offs accepted:

- **Nothing blocks a bad merge on the three private repos.** A red `lint` or `secrets` run is visible but not binding; a human can merge over it. Mitigated only by habit and by lastlight's review comment, not by the platform.
- **The fleet is deliberately inconsistent**, split by visibility rather than by intent. Anyone reading `data/yo61/*.yaml` sees some repos gated and some not; this document is the reason. The split is a billing artefact, not a judgement that private repos need less care — arguably they need more, since fewer eyes see them.
- **The policy is invisible in Terraform.** `builtin_ruleset_names: []` records the mechanism but not the intent, and nothing in the config says "a human approves here instead."
- **Re-evaluation has no trigger.** If the org ever moves to Team, these three repos should gain the same gate as the public ones, but nothing will prompt that. Worth checking whenever a private repo gains a second regular contributor.

## Supersedes: none. Generalises the repo-specific `2026-08-04-ycst-admin-docs-private-cpanel` ("private repo with no rulesets") into a fleet-wide policy for private repos, and states the review posture that decision left implicit. `2026-08-06-unifi-mcp-ci-only-gate` is unaffected — it concerns a public repo where the gate *is* enforceable and the review count was dropped for a different reason.
