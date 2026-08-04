# `yo61/ycst-admin-docs` — private docs repo on Krystal cPanel

**Date:** 2026-08-04
**Status:** implemented — repo created and initial commit pushed 2026-08-04.
Outstanding: merge PR #45 so the declaration reaches `main`, and configure the
six deploy secrets.

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
   floating `@v4` tags. Pin to current stable with version comments:
   `actions/checkout` v7.0.1, `actions/setup-node` v7.0.0, `pnpm/action-setup`
   v6.0.10. This is a real v4 → v7 bump, not just a pin. Two of these are newer
   than the SHAs `homelab-docs` carries; a new repo should not start behind, and
   Dependabot converges them within the week.

   Gotcha worth recording: `pnpm/action-setup` v6.0.10 is an **annotated** tag,
   so `repos/…/git/ref/tags/<tag>` returns the *tag object* SHA
   (`ff378ebe…`), not the commit (`0977fd99…`). Pinning to a tag-object SHA
   does not resolve at run time. Use `repos/…/commits/<tag>`, which
   dereferences either kind. `actions/checkout` uses lightweight tags, so both
   endpoints agree there — which is what makes the mistake easy to miss.
2. **Add `.pre-commit-config.yaml`**, copied from `homelab-docs` (same stack):
   conventional-commits, gitleaks, detect-private-key, check-yaml,
   end-of-file-fixer, trailing-whitespace, check-added-large-files,
   check-merge-conflict, actionlint, zizmor. `.github/dependabot.yml` already
   declares a `pre-commit` ecosystem that currently has no config to read.
3. **Pass the SSH secrets through `env:`.** `deploy.yaml`'s "Set up SSH" step
   interpolates `${{ secrets.SSH_PRIVATE_KEY }}` and
   `${{ secrets.SSH_KNOWN_HOSTS }}` directly into a `run:` block. The rsync step
   already passes its secrets through `env:`; apply the same treatment here,
   plus `set -euo pipefail` and a subshell `umask 077` so the private key is
   never briefly world-readable.

   Note: this is **not** a zizmor finding. Verified by running zizmor against
   the unmodified file — zero findings, nine suppressed. Its template-injection
   audit targets attacker-controllable contexts (`github.event.*`,
   `github.head_ref`); `secrets.*` is trusted input. The change is still
   worthwhile on its own merits — direct interpolation bakes the secret into a
   temp script on the runner's disk, and a multi-line PEM interpolated into a
   shell script is a quoting hazard — but it fixes a latent footgun, not a
   flagged vulnerability.

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

All checked 2026-08-04, post-apply and post-push:

- `gh api repos/yo61/ycst-admin-docs` → `private`, `has_issues: true`,
  `homepage: https://admin.ycst.org.uk`. ✅
- `gh api repos/yo61/ycst-admin-docs/rulesets` → **403 "Upgrade to GitHub Pro
  or make this repository public"**. ✅ Expected. This is the positive
  confirmation that `builtin_ruleset_names: []` was necessary: had the module
  attempted the default `default_branch` ruleset, the apply would have failed
  on this exact 403. The spec originally predicted `[]`; the endpoint refuses
  outright rather than returning an empty list.
- `gh api repos/yo61/ycst-admin-docs/vulnerability-alerts` → 204. ✅
- `git/trees/main?recursive=1` → 46 blobs, matching the 46 tracked files
  locally; no `node_modules`, `.source/`, `out/`, or `*.tsbuildinfo`. ✅
- `prek run --all-files` → all 9 hooks pass. ✅
- The CI workflow runs green on a subsequent PR. It cannot be a *required*
  check on this plan — that is the accepted trade-off.

## Out of scope

- Configuring the six Actions deploy secrets.
- Verifying an end-to-end deploy to `admin.ycst.org.uk`.
- Any change to the WordPress side (the `view_admin_docs` capability or the
  Trust Board role).
