# CI Gate Rollout (this repo) — Phases 0–1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the review-gated CI baseline live on every config-ready in-scope repo — apply the stalled `unifi-mcp`/`homelab-docs`/`unifictl` config, then add the required-status-checks gate (and, where missing, auto-merge) to `gh-release-stats`, `jobhound`, `claude-skills`, `contributory-factors` — closing every "auto-merge ON, no gate" hole.

**Architecture:** Each managed repo is one `data/yo61/<name>.yaml` recording deviations from the module defaults. A Tier-2 gate = an in-code `additional_rulesets.required_status_checks` block (no-bypass "CI green" ruleset) + `allow_auto_merge: true` + `default_branch_ruleset_required_approving_review_count: 1` on the built-in ruleset. The admin-role bypass is already a module default (PR #32); lastlight (app 4367919) supplies the approving review. State is applied via Stategraph (`task plan`/`task apply`), not local tfstate. Changes land via feature-branch → PR → squash-merge → apply.

**Tech Stack:** Terraform + `modules/github-repo`, Stategraph (via `Taskfile` wrappers), `gh` CLI, `prek` (yamllint/yamlfmt + name-stem hook), GitHub repository rulesets.

## Global Constraints

- **State deviations only** — never restate a value that equals the module default (`modules/github-repo/variables.tf`).
- **Ruleset idiom is fixed** — copy the exact `additional_rulesets.required_status_checks` block from `data/yo61/claude-plugin-reportlab-pdf.yaml`, changing only the `required_check` `context:` list. Do not add `builtin_ruleset_names` (defaulted) or a per-repo bypass (org default).
- **Gate on check contexts that already run on PRs** in this phase — the exact job `name:` strings verified from each repo's live CI. Context-name upgrades (rename `commitlint`→`Conventional Commits`, `jq`→`claude plugin validate`) are Phase-2 target-repo work, out of this plan.
- **Never commit on `main`** — `git branch --show-current` must show a feature branch before any commit. Config work uses a new `feat/` branch, separate from the docs branch this plan is committed on.
- **`prek run --files <file>` must pass** on every edited YAML (yamlfmt normalizes key order/spacing; the name-stem hook checks `name:` matches the filename).
- **Verification is read-only-first** — `task plan` shows the intended ruleset/flag diff without mutating state; only `task apply` mutates, and only after PR merge and plan review.
- **Stategraph known-bug caveat** — if `task plan`/`task apply` fails server-side with `FETCH_BUNDLE`/`NO_STATES` (cleanup-only diffs) or a `/logs/append` 404, stop and report; these are tracked upstream (stategraph/releases#3) and are not a config error to debug locally.

**Context contract per repo (Phase 1, existing PR check names):**

| Repo | `required_check` contexts | auto-merge already set? | drift ruleset to delete after apply |
| --- | --- | --- | --- |
| `gh-release-stats` | `test`, `lint`, `commitlint`, `zizmor` | yes | none |
| `jobhound` | `Lint, typecheck, test`, `Conventional Commits`, `zizmor` | **no — add** | `main protection` (id 16287941) |
| `claude-skills` | `Conventional Commits`, `lint`, `Marketplace JSON validation`, `Check plugin source refs resolve` | yes | none |
| `claude-plugin-contributory-factors` | `Conventional Commits`, `plugin.json validation`, `lint` | **no — add** | `main branch protection` (id 16547942) |

---

### Task 1: Apply the stalled Phase-0 config (unifi-mcp / homelab-docs / unifictl)

The gate config for these three is already in `main` (PR #36) but was never applied (Stategraph outage 2026-08-02). Applying it now makes their gates live **and** confirms Stategraph has recovered before we add more.

**Files:** none (operational — no working-tree change).

**Interfaces:**
- Consumes: the merged `additional_rulesets` blocks already in `data/yo61/{unifi-mcp,homelab-docs,unifictl}.yaml`.
- Produces: live `Required status checks` rulesets on those three repos (later tasks assume Stategraph is working).

- [ ] **Step 1: Confirm you are on latest `main` for the plan/apply**

Run: `git fetch origin && git log --oneline -1 origin/main`
Expected: shows commit `ffba6bd` (PR #36) or later.

- [ ] **Step 2: Read-only plan**

Run: `task plan`
Expected: the plan includes creation of the `Required status checks` ruleset for `unifi-mcp`, `homelab-docs`, `unifictl` (and their `allow_auto_merge`/review-count where not yet live). If the plan errors server-side, STOP — see the Stategraph caveat.

- [ ] **Step 3: Review the plan, then apply**

Review the printed plan. Run: `task apply`
Expected: apply succeeds; ruleset resources created.

- [ ] **Step 4: Verify the gates are live**

Run:
```bash
for r in unifi-mcp homelab-docs unifictl; do
  echo "== $r =="
  gh api "repos/yo61/$r/rulesets" --jq '.[].name'
  gh api "repos/yo61/$r" --jq '"allow_auto_merge=\(.allow_auto_merge)"'
done
```
Expected: each lists both `Default Branch` and `Required status checks`; `allow_auto_merge=true`.

- [ ] **Step 5: No commit** — this task changed no files. Proceed.

---

### Task 2: Start the Phase-1 config branch + gate `gh-release-stats`

`gh-release-stats` already has `allow_auto_merge: true` but no gate — the least-safe state. Add the required-checks ruleset and the review count.

**Files:**
- Modify: `data/yo61/gh-release-stats.yaml`

**Interfaces:**
- Consumes: the ruleset idiom from `data/yo61/claude-plugin-reportlab-pdf.yaml`.
- Produces: `gh-release-stats.yaml` carrying an `additional_rulesets.required_status_checks` block with contexts `test`, `lint`, `commitlint`, `zizmor`, plus `default_branch_ruleset_required_approving_review_count: 1`.

- [ ] **Step 1: Create the config feature branch**

Run:
```bash
git checkout main && git pull --ff-only
git checkout -b feat/ci-gate-phase-1
git branch --show-current
```
Expected: prints `feat/ci-gate-phase-1`.

- [ ] **Step 2: Add the gate block to `gh-release-stats.yaml`**

Add these top-level keys (yamlfmt will sort them into place — leave `allow_auto_merge: true` as-is):

```yaml
additional_rulesets:
  required_status_checks:
    enforcement: active
    name: Required status checks
    target: branch
    conditions:
      - ref_name:
          exclude: []
          include:
            - ~DEFAULT_BRANCH
    rules:
      - creation: false
        deletion: false
        non_fast_forward: false
        required_signatures: false
        update: false
        update_allows_fetch_and_merge: false
        required_status_checks:
          strict_required_status_checks_policy: false
          required_check:
            - context: test
            - context: lint
            - context: commitlint
            - context: zizmor
default_branch_ruleset_required_approving_review_count: 1
```

- [ ] **Step 3: Lint the file**

Run: `prek run --files data/yo61/gh-release-stats.yaml`
Expected: all hooks Pass (yamlfmt may reformat; re-stage if it does).

- [ ] **Step 4: Verify the intended diff via plan**

Run: `task plan`
Expected: plan shows a new `Required status checks` ruleset for `gh-release-stats` with exactly those four contexts, and the review-count change on its `Default Branch` ruleset. No destroy/recreate of unrelated resources.

- [ ] **Step 5: Commit**

```bash
git add data/yo61/gh-release-stats.yaml
git commit -m "feat(yo61): required-checks gate for gh-release-stats"
```

---

### Task 3: Gate + enable auto-merge on `jobhound`

`jobhound` has real pytest CI and a green-but-untracked drift ruleset. Add the in-code gate + auto-merge; the drift ruleset is deleted in Task 6 after apply.

**Files:**
- Modify: `data/yo61/jobhound.yaml`

**Interfaces:**
- Produces: `jobhound.yaml` with the required-checks block (contexts `Lint, typecheck, test`, `Conventional Commits`, `zizmor`), `allow_auto_merge: true`, and `default_branch_ruleset_required_approving_review_count: 1`.

- [ ] **Step 1: Add the gate block + auto-merge to `jobhound.yaml`**

Add these top-level keys:

```yaml
additional_rulesets:
  required_status_checks:
    enforcement: active
    name: Required status checks
    target: branch
    conditions:
      - ref_name:
          exclude: []
          include:
            - ~DEFAULT_BRANCH
    rules:
      - creation: false
        deletion: false
        non_fast_forward: false
        required_signatures: false
        update: false
        update_allows_fetch_and_merge: false
        required_status_checks:
          strict_required_status_checks_policy: false
          required_check:
            - context: "Lint, typecheck, test"
            - context: Conventional Commits
            - context: zizmor
allow_auto_merge: true
default_branch_ruleset_required_approving_review_count: 1
```

- [ ] **Step 2: Lint**

Run: `prek run --files data/yo61/jobhound.yaml`
Expected: Pass.

- [ ] **Step 3: Verify the intended diff via plan**

Run: `task plan`
Expected: plan shows the new `Required status checks` ruleset for `jobhound` (three contexts), `allow_auto_merge` true, review-count 1. It will NOT touch the untracked `main protection` drift ruleset (Stategraph does not manage it) — that is deleted manually in Task 6.

- [ ] **Step 4: Commit**

```bash
git add data/yo61/jobhound.yaml
git commit -m "feat(yo61): review-gated auto-merge for jobhound"
```

---

### Task 4: Gate `claude-skills`

`claude-skills` has `allow_auto_merge: true` but no gate. Add the required-checks ruleset (on its existing validation/lint checks) + review count.

**Files:**
- Modify: `data/yo61/claude-skills.yaml`

**Interfaces:**
- Produces: `claude-skills.yaml` with the required-checks block (contexts `Conventional Commits`, `lint`, `Marketplace JSON validation`, `Check plugin source refs resolve`) + `default_branch_ruleset_required_approving_review_count: 1`.

- [ ] **Step 1: Add the gate block to `claude-skills.yaml`**

```yaml
additional_rulesets:
  required_status_checks:
    enforcement: active
    name: Required status checks
    target: branch
    conditions:
      - ref_name:
          exclude: []
          include:
            - ~DEFAULT_BRANCH
    rules:
      - creation: false
        deletion: false
        non_fast_forward: false
        required_signatures: false
        update: false
        update_allows_fetch_and_merge: false
        required_status_checks:
          strict_required_status_checks_policy: false
          required_check:
            - context: Conventional Commits
            - context: lint
            - context: Marketplace JSON validation
            - context: Check plugin source refs resolve
default_branch_ruleset_required_approving_review_count: 1
```

- [ ] **Step 2: Lint**

Run: `prek run --files data/yo61/claude-skills.yaml`
Expected: Pass.

- [ ] **Step 3: Verify the intended diff via plan**

Run: `task plan`
Expected: new `Required status checks` ruleset for `claude-skills` with those four contexts + review-count 1.

- [ ] **Step 4: Commit**

```bash
git add data/yo61/claude-skills.yaml
git commit -m "feat(yo61): required-checks gate for claude-skills"
```

---

### Task 5: Gate + enable auto-merge on `contributory-factors`

Add the in-code gate + auto-merge; drift ruleset deleted in Task 6 after apply.

**Files:**
- Modify: `data/yo61/claude-plugin-contributory-factors.yaml`

**Interfaces:**
- Produces: `claude-plugin-contributory-factors.yaml` with the required-checks block (contexts `Conventional Commits`, `plugin.json validation`, `lint`), `allow_auto_merge: true`, and review-count 1.

- [ ] **Step 1: Add the gate block + auto-merge**

```yaml
additional_rulesets:
  required_status_checks:
    enforcement: active
    name: Required status checks
    target: branch
    conditions:
      - ref_name:
          exclude: []
          include:
            - ~DEFAULT_BRANCH
    rules:
      - creation: false
        deletion: false
        non_fast_forward: false
        required_signatures: false
        update: false
        update_allows_fetch_and_merge: false
        required_status_checks:
          strict_required_status_checks_policy: false
          required_check:
            - context: Conventional Commits
            - context: plugin.json validation
            - context: lint
allow_auto_merge: true
default_branch_ruleset_required_approving_review_count: 1
```

- [ ] **Step 2: Lint**

Run: `prek run --files data/yo61/claude-plugin-contributory-factors.yaml`
Expected: Pass.

- [ ] **Step 3: Verify the intended diff via plan**

Run: `task plan`
Expected: new `Required status checks` ruleset (three contexts), `allow_auto_merge` true, review-count 1. Does not touch the `main branch protection` drift ruleset.

- [ ] **Step 4: Commit**

```bash
git add data/yo61/claude-plugin-contributory-factors.yaml
git commit -m "feat(yo61): review-gated auto-merge for contributory-factors"
```

---

### Task 6: PR, merge, apply, and delete drift rulesets

**Files:** none (integration task).

**Interfaces:**
- Consumes: the four commits from Tasks 2–5.
- Produces: live gates on all four repos; the two orphan drift rulesets removed.

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin feat/ci-gate-phase-1
gh pr create --fill --base main
```

- [ ] **Step 2: Merge after review**

Squash-merge once CI + review are green (this repo's own gate is added in a later Phase-2 plan, so merge is manual here).

- [ ] **Step 3: Plan + apply from merged `main`**

```bash
git checkout main && git pull --ff-only
task plan
```
Review, then: `task apply`
Expected: `Required status checks` rulesets created for `gh-release-stats`, `jobhound`, `claude-skills`, `contributory-factors`; `allow_auto_merge`/review-count set on `jobhound` and `contributory-factors`.

- [ ] **Step 4: Verify all four gates live**

```bash
for r in gh-release-stats jobhound claude-skills claude-plugin-contributory-factors; do
  echo "== $r =="
  gh api "repos/yo61/$r/rulesets" --jq '.[].name'
  gh api "repos/yo61/$r" --jq '"allow_auto_merge=\(.allow_auto_merge)"'
done
```
Expected: each lists `Required status checks`; `allow_auto_merge=true` on all four.

- [ ] **Step 5: Delete the two orphan drift rulesets (only AFTER apply confirms the in-code gate is live)**

```bash
gh api -X DELETE "repos/yo61/jobhound/rulesets/16287941"
gh api -X DELETE "repos/yo61/claude-plugin-contributory-factors/rulesets/16547942"
```

- [ ] **Step 6: Confirm drift gone (only the two managed rulesets remain)**

```bash
gh api "repos/yo61/jobhound/rulesets" --jq '.[].name'
gh api "repos/yo61/claude-plugin-contributory-factors/rulesets" --jq '.[].name'
```
Expected: each prints exactly `Default Branch` and `Required status checks` — no `main protection` / `main branch protection`.

---

## Phase 2 — follow-up plans (out of this plan)

Each is target-repo work (a PR in that repo) that must land before its gate context here can be upgraded; each needs the target repo explored to write real test/workflow code, so each gets its own plan:

- **`reportlab-pdf` behavioural tests** — add pytest render tests (render a PDF, assert on output/structure), swap `jq`→`claude plugin validate --strict`, then update its gate contexts here to include `test`.
- **`civi-mcp` CI workflow** — new `.github/workflows/ci.yaml` (vitest `test`, `prek` `lint`, `commitlint`), then add its `data/yo61/civi-mcp.yaml` gate + auto-merge.
- **`github-repos` (this repo) CI workflow** — new `.github/workflows/ci.yaml` (`prek run --all-files` `lint`, `terraform fmt -check`/`validate`, `commitlint`), then a Tier-1 gate on this repo (no auto-merge).
- **`homelab-docs` completion** — add `lint`(prek) + `commitlint` jobs to its CI, extend its gate contexts here beyond `build`.
- **Context-name standardization** — rename `gh-release-stats`'s `commitlint` job → `Conventional Commits`, then update its gate context here; swap the plugin repos' `jq` validation → `claude plugin validate --strict` and update `claude-skills`/`contributory-factors` gate contexts.
- **`homebrew-tap`** — add an always-run aggregator job so a required check can't hang on path-filtered PRs, then gate.

## Self-Review

- **Spec coverage (Phases 0–1):** Task 1 = spec Phase 0; Tasks 2–5 = spec Phase 1 gating of the four config-ready repos; Task 6 = apply + the drift-deletion trade-off from the spec. Phase 2 spec items are enumerated as follow-up plans. ✓
- **Placeholder scan:** every YAML block is complete and copy-ready; every verification step has an exact command and expected output. No TBD/TODO. ✓
- **Consistency:** contexts in each task match the Global-Constraints contract table and the repos' live CI job `name:` strings; ruleset block is byte-identical to the `reportlab-pdf` reference except the `required_check` list. ✓
