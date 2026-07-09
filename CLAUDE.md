# Project

This repository declaratively manages GitHub repositories across
organizations with Terraform. State is stored in Stategraph (not local
`.tfstate`).

Each managed repo is one YAML file at `data/<org>/<name>.yaml` that records
only its **deviations** from the module defaults. The `modules/github-repo`
module turns each file into a `github_repository` plus its rulesets,
collaborators, and security settings; `modules/org` fans out over an org's
files.

## Repository layout

- `data/<org>/*.yaml` — one file per managed repo (the source of truth)
- `modules/github-repo/` — the reusable repo module; `variables.tf` lists
  every supported field and its default
- `modules/org/` — iterates an org's `data/` files
- `main.tf`, `providers.tf`, `versions.tf` — root module
- `scripts/` — import and config-generation helpers

## Adding or changing a repo

1. Create or edit `data/<org>/<name>.yaml`. State only what differs from the
   module defaults in `modules/github-repo/variables.tf`.
2. Lint it: `prek run --files <file>` (yamllint + yamlfmt; a hook checks the
   `name:` field matches the filename stem).
3. Open a PR from a feature branch — never commit on `main`.
4. After merge, apply with Stategraph (below).

### Conventions

- **State deviations only.** Don't restate values that already equal the
  module default.
- **New repos omit `create_default_branch`.** It builds a `github_branch`
  resource that needs a source commit, so it fails on a brand-new empty repo;
  `main` is established on the first push. Existing/imported repos may set it.
- **Collaborators use block style:**
  ```yaml
  collaborators:
    users:
      - permission: admin
        username: robinbowes
  ```
- **Private repos on the free-tier personal org:** rulesets and secret
  scanning are paywalled — omit them. Keep `vulnerability_alerts` and
  `dependabot_security_updates`.

## Applying changes (Stategraph)

State lives in Stategraph. Use the `stategraph` and `stategraph-change` skills
for the full workflow; the core sequence is:

```bash
stategraph info                                          # orient; find the tenant id
stategraph tf plan --tenant <TENANT_ID> --out plan.json  # plan (read-only)
stategraph tf apply plan.json                            # apply (only after review)
```

Always plan and review before applying. Plan files can contain sensitive
values and are gitignored.

## Git workflow

Feature branch → commit → PR → squash-merge → apply. Use conventional-commit
subjects, e.g. `feat(<org>): add <repo> public repo`.
