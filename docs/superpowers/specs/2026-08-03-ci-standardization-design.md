# CI standardization + two-tier auto-merge — design spec

**Date:** 2026-08-03
**Status:** approved (design), implementation plan to follow
**Scope:** the 13 recently-active managed repos (the `civi-mcp` push-date cutoff).
Dormant managed repos (2013–2017 Puppet/Vagrant/mcollective/lambda) are
explicitly out of scope for this pass.

## Goal

Every actively-developed repo must run a meaningful CI baseline that is green
before any change merges, and auto-merge (lastlight-gated) must only be enabled
where a check meaningfully exercises what the repo produces. Today the set is in
three divergent states: fully wired, auto-merge enabled with **no** CI gate, and
no CI at all. This spec defines one policy and records, per repo, what each one
needs to reach it.

## Policy — two tiers

The policy maps onto the two ruleset pieces the repo module already supports.

- **Tier 1 — CI baseline, on every in-scope repo.** A no-bypass
  `additional_rulesets.required_status_checks` ruleset (the "CI green" clause,
  the go-udap/reportlab convention) enforcing, at minimum:
  - `Conventional Commits` (commitlint on PRs),
  - `lint` (`prek run --all-files` — uniform across every stack; every repo
    already ships a `.pre-commit-config.yaml`),
  - a stack-appropriate validation / build / test check.
  "Green before merge" means *required*, so this ruleset applies whether or not
  the repo also gets auto-merge.

- **Tier 2 — auto-merge, only where a behavioural check exists.**
  Additionally `allow_auto_merge: true` plus the built-in `default_branch`
  ruleset with `required_approving_review_count: 1` and the org-default
  admin-role bypass. lastlight (app 4367919, installed org-wide) supplies the
  approval; the no-bypass status-checks ruleset keeps release automation subject
  to CI.

### What counts as a "behavioural check" (Tier 2 gate)

Judged per repo by what the repo actually produces, not by a generic rule:

- **Application / library code** (Python, TS, Go): a test suite that runs the
  code (pytest / vitest / `go test`).
- **Docs site**: a successful `build` — it compiles and renders every page.
- **Payload-free plugin** (marketplace metadata, or a markdown skill packaged as
  a plugin): `claude plugin validate --strict` — the strongest check that can
  exist for a plugin with no executable payload; it validates `marketplace.json`
  /`plugin.json`/`SKILL.md` frontmatter and that components load. This is the
  plugin equivalent of a docs build.
- **Plugin wrapping executable code** (e.g. reportlab-pdf's Python): validation
  alone is *not* behavioural — it never runs the code — so a real test suite is
  required before Tier 2.

## First-party tooling

`claude plugin validate <dir> --strict` is first-party, headless, and CI-ready.
It validates `marketplace.json` (duplicate names, path traversal, cross-checks
each plugin) **and** `plugin.json` **and** `skills/*/SKILL.md` frontmatter,
commands, agents, hooks. It replaces the hand-rolled `jq` shape-checks in the
plugin repos. There is no standalone skill validator, but every skill in scope
is packaged as a plugin, so the plugin validator covers them.

**Open verification (Phase 2):** confirm `--strict` exits non-zero on failure —
a validator that always exits 0 is not a gate. If it does not, fall back to a
`jq`/JSON-Schema check plus `markdownlint`.

## Per-repo matrix

| Repo | Tier | Required check contexts (target) | Current state | Action |
| --- | :--: | --- | --- | --- |
| `go-udap` | 2 | test matrix, lint, govulncheck, sbom, Conventional Commits | applied | none (reference) |
| `unifi-mcp` | 2 | `check (node 22)`, `check (node 24)`, `Conventional Commits` | in code, unapplied | apply |
| `unifictl` | 2 | `Lint, typecheck, test`, `Conventional Commits` | in code, unapplied | apply |
| `gh-release-stats` | 2 | `test`, `lint`, `Conventional Commits`, `zizmor` | auto-merge ON, no gate | add gate; rename `commitlint`→`Conventional Commits` |
| `jobhound` | 2 | `Lint, typecheck, test`, `Conventional Commits`, `zizmor` | OFF, drift ruleset | enable auto-merge + in-code gate; delete `main protection` drift |
| `civi-mcp` | 2 | `Conventional Commits`, `lint`, `test` (vitest) | no CI at all | add CI workflow, then gate + auto-merge |
| `homelab-docs` | 2 | `build`, `lint`, `Conventional Commits` | `build`-only gate in code, unapplied | Phase 0: apply existing `build` gate. Phase 2: add `lint`+commitlint jobs (PR in homelab-docs), then extend gate. `build` is the behavioural check. |
| `reportlab-pdf` | 2 | `Conventional Commits`, `lint`, `validate`, `test` | ON, applied, no test | write render tests; swap jq→`claude plugin validate --strict`; gate on `test` |
| `claude-skills` | 2 | `Conventional Commits`, `lint`, `validate`, `markdownlint` | ON, no gate | add gate; swap jq→`validate --strict`; keep source-ref resolve |
| `contributory-factors` | 2 | `Conventional Commits`, `lint`, `validate`, `markdownlint` | OFF, drift ruleset | enable auto-merge + in-code gate; swap jq→`validate --strict`; delete drift |
| `github-repos` (this) | 1 | `Conventional Commits`, `lint`, `terraform` (fmt + validate) | no CI | add CI workflow + enforced gate; no auto-merge |
| `homebrew-tap` | deferred | (CI is path-filtered) | ON, no gate | deferred — revisit with an always-run aggregator job |
| `kuard` | skip | — | — | skip (adopted demo fork) |

## Standardization changes this drives

1. Uniform `lint` job = `prek run --all-files` in every repo; uniform
   `Conventional Commits` check name (fixes `gh-release-stats`'s `commitlint`).
2. `claude plugin validate --strict` replaces hand-rolled `jq` validation in the
   three plugin repos (`claude-skills`, `contributory-factors`, `reportlab-pdf`).
3. Add CI where absent: `civi-mcp` (vitest + lint + commitlint) and
   `github-repos` (terraform fmt/validate + prek + commitlint).
4. Add behavioural render tests to `reportlab-pdf` so its auto-merge is
   legitimate under the policy.
5. Delete the two orphan `main branch protection` drift rulesets (`jobhound`,
   `contributory-factors`) out-of-band after apply (Stategraph does not manage
   them). Check the other in-scope repos for the same drift during rollout.

## Sequencing

The order is chosen so the least-safe states (auto-merge ON with no gate) are
closed first, and repos that need code changes in the *target* repo are handled
after the pure-config work.

- **Phase 0 — unblock the pending apply.** Apply the already-merged config for
  `unifi-mcp`, `homelab-docs`, `unifictl` (blocked 2026-08-02 by a Stategraph
  outage). No new code needed; makes the in-code gates live. `unifi-mcp` and
  `unifictl` reach full Tier-1 here (their aggregator checks already fold in
  lint); `homelab-docs` lands its `build`-only gate here and is completed in
  Phase 2.
- **Phase 1 — config-only gating.** In this repo, add the baseline gate to the
  repos whose checks already exist: `gh-release-stats`, `jobhound`,
  `claude-skills`, `contributory-factors`. After apply, delete the `jobhound`
  and `contributory-factors` drift rulesets.
- **Phase 2 — repos needing code first.** One PR *in the target repo*, then the
  gate here: `civi-mcp` CI workflow; `github-repos` CI workflow;
  `reportlab-pdf` render tests; `homelab-docs` `lint`+commitlint jobs. Verify
  the `claude plugin validate --strict` exit-code behaviour here.
- **Deferred:** `homebrew-tap` — its `brew test-bot` / `zizmor` workflows are
  `paths:`-filtered, so a required status check hangs as "Expected" on any PR
  that does not touch the filtered paths. Requires an always-run aggregator job
  before it can back a gate. Tracked separately.

## Constraints and trade-offs

- Per-repo YAML repeats the `additional_rulesets` block across ~11 files rather
  than defaulting it once in `modules/org`; accepted because the check contexts
  are genuinely per-repo (see the extends-from decision).
- `dismiss_stale_reviews_on_push: true` on the built-in ruleset can dismiss
  lastlight's approval on a Dependabot rebase and briefly stall auto-merge until
  re-approval; acceptable at this update volume.
- Private repos (`flux-homelab`, `ycst-website-testing`) remain excluded —
  rulesets are paywalled on the free-tier personal org.

## Follow-ups (out of this pass)

- Decide whether the dormant managed tail gets any CI baseline.
- `homebrew-tap` always-run aggregator + gate.
- Revisit a `modules/org` default for the uniform parts once the check set
  stabilises.
