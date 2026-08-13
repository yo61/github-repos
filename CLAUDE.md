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

- `data/<org>/*.yaml` — one file per managed repo (the source of truth);
  `data/<org>/_teams.yaml` is optional per-org metadata, and leading-underscore
  filenames are reserved for it rather than read as repos
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
- **Teams are optional and per-org.** `data/<org>/_teams.yaml` is a map keyed
  by team slug, each with `description`, `members`, and an optional `privacy`
  (default `closed`). The key is used verbatim as the team name, and GitHub
  derives the slug from it, so keys must be lowercase and hyphenated for the
  two to agree. Membership is authoritative — a member added in the UI is
  removed on the next apply. A repo grants to a team with
  `collaborators.teams: [{permission: admin, slug: admins}]`; a slug with no
  team in the same org's `_teams.yaml` fails the plan.

## Applying changes

State lives in Stategraph, reached through its **HTTP backend** using the
native `terraform` CLI. The `stategraph` CLI is not used to plan or apply.
Drive everything through the `Taskfile` wrappers (`task --list` shows
everything).

`backend.tf` is a partial configuration: it declares the backend but omits
the address, so both the address and the API key come from the environment.
They live in `.envrc` in this directory, loaded by direnv (`direnv allow`
once per clone):

```bash
export TF_HTTP_ADDRESS="https://app.stategraph.cloud/api/v1/states/backend/<state-uuid>"
export TF_HTTP_PASSWORD="$STATEGRAPH_API_KEY"
```

`.envrc` is machine-specific and untracked. Like editor config, it belongs in
a global ignore (`~/.gitignore`) rather than this repo's `.gitignore`. Any
other way of exporting the two variables works just as well.

```bash
task init    # terraform init                    (once per clone)
task plan    # terraform plan -out tfplan        (read-only)
task apply   # terraform apply tfplan            (only after reviewing the plan)
```

`task plan ORG=<org>` scopes the plan to one org
(`-target=module.org_<org>`, hyphens become underscores). Targeting skips the
excluded org's `check "unmanaged_repos"` and its filename/`name:` validation,
so it is for scoping a known change; unscoped `task plan` stays the default.

Inspect state with `task state:list` (all instance addresses) and
`task state:show REPO=<name>` (one repo's instances). Always review the plan
before applying; plan files can contain sensitive values and are gitignored.

`task` refuses to run if either environment variable is missing. The backend
is unlocked (Stategraph exposes no lock endpoint), so avoid concurrent
applies.

## Git workflow

Feature branch → commit → PR → squash-merge → apply. Use conventional-commit
subjects, e.g. `feat(<org>): add <repo> public repo`.
