# `yo61/ycst-admin-docs` — private docs repo on Krystal cPanel

**Date:** 2026-08-04
**Status:** approved

## Goal

Bring `yo61/ycst-admin-docs` under management: declare it in this repo, create
it on GitHub, and publish the Fumadocs site that already exists on disk at
`~/code/github.com/yo61/ycst-admin-docs` as its initial commit.

The brief was "similar to `homelab-docs`, but deploying to a cPanel site on
Krystal hosting". The hosting change forces a visibility change, and the
visibility change removes most of what `homelab-docs` carries. Rationale for
the resulting shape is recorded in
`decisions/2026-08-04-ycst-admin-docs-private-cpanel.md`.

## Starting state

- `gh api repos/yo61/ycst-admin-docs` → 404. Nothing exists on GitHub.
- `~/code/github.com/yo61/ycst-admin-docs` exists and is **not** a git repo. It
  holds a complete Fumadocs/Next.js static-export site: `content/docs/`
  organised on Diátaxis, `deploy/gate/{index.php,.htaccess}` (the WordPress
  gatekeeper), `.github/workflows/{ci,deploy}.yaml`, and `.github/dependabot.yml`.
- `.gitignore` already covers everything that must not be committed:
  `node_modules` (495M), `.source`, `*.tsbuildinfo`, `/out/`, `/.next/`.

## Part 1 — the Terraform declaration

`data/yo61/ycst-admin-docs.yaml`:

```yaml
---
builtin_ruleset_names: []
dependabot_security_updates: true
description: "Board admin hub and docs for York City Supporters Trust."
has_issues: true
homepage_url: https://admin.ycst.org.uk
name: ycst-admin-docs
visibility: private
vulnerability_alerts: true
```

### What is deliberately absent

`modules/org/main.tf` reads every field with `lookup(each.value, "<key>", null)`,
so an absent key passes `null` and the module default in
`modules/github-repo/variables.tf` applies. Omission is the mechanism for
selecting a default, not an oversight.

| `homelab-docs` field | Here | Why |
|---|---|---|
| `pages: {build_type: workflow}` | omitted | Deploy is rsync-to-cPanel. Pages is also paywalled on private free-tier repos. |
| `additional_rulesets` (`build` gate) | omitted | Rulesets 403 on free-tier private repos. |
| `default_branch_ruleset_required_approving_review_count: 1` | omitted | Same paywall; `builtin_ruleset_names: []` disables the built-in ruleset. |
| `allow_auto_merge: true` | omitted (default `false`) | Nothing to auto-merge behind without a gate. |
| `security_and_analysis` | omitted | Secret scanning requires GHAS on private repos (422). |
| `collaborators` | omitted | Owner access already covers it; only 4 of 27 data files set this. |
| `visibility: public` | `private` | Board-internal content. |
| — | `auto_init` omitted | The repo must start **empty** so the local history pushes without an unrelated-histories conflict. |
| — | `create_default_branch` omitted | Project convention: `main` is established by the first push. |

`name` is required — `variables.tf` gives it no default, and the local
`repo-yaml-name-check` prek hook asserts it matches the filename stem.

`visibility: private` restates the module default and so conflicts with the
blocking "deviations only" criterion in `quality/criteria.md`. Kept
deliberately; see the decision record's trade-offs.

## Part 2 — pre-push fixes to the site repo

Three changes land in the working tree *before* `git init`, so the initial
commit meets the standard rather than needing a follow-up PR:

1. **SHA-pin the actions** in `ci.yaml` and `deploy.yaml`, which currently use
   floating `@v4` tags. Pin to the versions `homelab-docs` runs today, with
   version comments: `actions/checkout` v7.0.0, `actions/setup-node` v7.0.0,
   `pnpm/action-setup` v6.0.9. This is a real v4 → v7 bump, not just a pin.
2. **Add `.pre-commit-config.yaml`**, copied from `homelab-docs` (same stack):
   conventional-commits, gitleaks, detect-private-key, check-yaml,
   end-of-file-fixer, trailing-whitespace, check-added-large-files,
   check-merge-conflict, actionlint, zizmor. `.github/dependabot.yml` already
   declares a `pre-commit` ecosystem that currently has no config to read.
3. **Fix the template-injection that (2) will surface.** `deploy.yaml`'s
   "Set up SSH" step interpolates `${{ secrets.SSH_PRIVATE_KEY }}` and
   `${{ secrets.SSH_KNOWN_HOSTS }}` directly into a `run:` block, which zizmor
   flags. The rsync step already does this correctly by passing secrets through
   `env:`; apply the same treatment to the SSH setup step.

Deploy secrets themselves (`SSH_PRIVATE_KEY`, `SSH_KNOWN_HOSTS`, `SSH_HOST`,
`SSH_USER`, `SSH_PORT`, `DEPLOY_PATH`) are out of scope — configured
out-of-band by Robin.

## Part 3 — sequencing

Ordering matters: the GitHub repo must exist and be empty before the push.

**In `github-repos`** (branch `feat/ycst-admin-docs`):

1. Add the YAML, the decision record, and this spec.
2. `prek run --files <changed>`.
3. Commit, push the branch, open a PR.
4. Robin merges.
5. `direnv exec . task plan` — review the diff. It should create exactly the
   `github_repository`, `github_repository_dependabot_security_updates`, and
   `github_repository_vulnerability_alerts` instances for this repo, and touch
   nothing else.
6. `direnv exec . task apply`.

**In `ycst-admin-docs`** (after apply):

7. Apply the three fixes from Part 2.
8. `git init`, `prek install`, `prek run --all-files`, fix anything flagged.
9. One conventional initial commit.
10. `git remote add origin`, then `git push -u origin main` — a one-time
    exception to the never-push-`main` rule, explicitly authorised, because an
    empty repo has no branch to open a PR against. Every subsequent change goes
    feature branch → PR.

## Verification

- `gh api repos/yo61/ycst-admin-docs --jq '{visibility,has_issues,homepage}'`
  returns `private`, `true`, `https://admin.ycst.org.uk`.
- `gh api repos/yo61/ycst-admin-docs/rulesets` returns `[]` — confirming the
  `builtin_ruleset_names: []` opt-out held and nothing 403'd.
- `gh api repos/yo61/ycst-admin-docs/vulnerability-alerts` returns 204.
- The pushed tree contains no `node_modules`, `.source`, `out/`, or
  `*.tsbuildinfo`.
- The CI workflow runs green on a subsequent PR. It cannot be a *required*
  check on this plan — that is the accepted trade-off.

## Out of scope

- Configuring the six Actions deploy secrets.
- Verifying an end-to-end deploy to `admin.ycst.org.uk`.
- Any change to the WordPress side (the `view_admin_docs` capability or the
  Trust Board role).
