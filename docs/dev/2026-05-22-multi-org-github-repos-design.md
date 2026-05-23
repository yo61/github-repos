# Multi-org GitHub repo management — design

Date: 2026-05-22
Status: Draft, pending implementation plan

## Problem

This repository was cobbled together from an earlier Terraform setup and
partially adapted to manage personal orgs (initially `yo61`, eventually
`robinbowes`). The migration is incomplete:

- `data.tf` still references `data/repositories/*` (old path), an undeclared
  data source, missing `data/teams.yaml` and `data/linear.yaml` files, and an
  undeclared `github_team.this` resource.
- `providers.tf` hardcodes a single `owner = "robinbowes"`, with no support for
  multiple orgs.
- `main.tf` keys repos by name alone, which collides across orgs.
- `README.md`, `Taskfile.yaml`, and `imports.tf.template` still describe the
  previous AWS + terragrunt workflow inherited from the source setup.

Work has begun migrating to `data/<ORG>/<REPO>.yaml` (one repo present:
`data/yo61/go-udap.yaml`) but the Terraform code has not caught up.

## Goals

In scope:

- Manage GitHub repos across multiple orgs from a single Terraform root.
- Repos are fully data-driven from `data/<ORG>/<REPO>.yaml`.
- Adding a new org requires only a small, explicit Terraform edit (one provider
  block + one module call) plus a new data directory.
- Drift detection: GitHub repos without local YAML configs are tolerated. They
  surface as warnings during `plan` but do not block.
- State managed via `stategraph` (commands `stategraph tf plan` /
  `stategraph tf apply`); no Terraform `backend` block.
- Replace the previous scaffolding (terragrunt, AWS account checks, Linear
  autolinks) with code that fits a personal multi-org setup.

Out of scope:

- Linear autolinks (dropped).
- Org team data (`github_team` resources, `_teams.yaml` files). The module
  *capability* to reference teams as collaborators is retained, but no teams
  are declared yet.
- Automated integration tests against real GitHub.
- Backwards-compatibility shims or state migration (state is fresh — confirmed
  with user 2026-05-22).

## Architecture

Single Terraform state file. One root module that fans out to a thin per-org
wrapper module, which in turn instantiates the existing `modules/github-repo`
for each repo in `data/<org>/`.

```
github-repos/
├── versions.tf       # terraform + github provider versions; no backend block
├── providers.tf      # one `provider "github"` block per org, each aliased
├── main.tf           # one `module "org_<name>"` call per org
├── stategraph.json   # already present; stategraph manages state
├── data/
│   ├── yo61/
│   │   └── go-udap.yaml
│   └── robinbowes/   # added when ready
└── modules/
    ├── org/                  # NEW thin wrapper
    │   ├── versions.tf       # configuration_aliases = [github]
    │   ├── variables.tf      # var.org
    │   ├── data.tf           # YAML loading, drift query, validation
    │   └── main.tf           # for_each over repos, calls github-repo
    └── github-repo/          # existing module, minor changes
```

State keys take the form:
`module.org_<org>.module.repo["<repo>"].github_repository.this`

Repos cannot collide across orgs because the org is part of the resource path.

### Why not a single flat module with composite keys?

A `for_each` keyed by `"<org>/<repo>"` over a flat map would be simpler in
shape, but Terraform requires the `providers = { … }` argument on a module
call to be statically resolvable per call — you cannot pick a provider alias
from `each.value`. So multi-org from one `for_each` block is not possible.

### Why a per-org wrapper module rather than per-org direct calls?

The existing `main.tf` passes 35 explicit fields from each YAML to
`modules/github-repo`. Duplicating that block per org leaves a 50-line wall of
HCL per org and makes any future parameter change an N-place edit. A thin
wrapper module isolates the data-loading and parameter passthrough behind one
small interface (`org`, aliased provider in, nothing out).

## Data layout

### Per-repo files

`data/<org>/<repo>.yaml` — schema unchanged from today's `go-udap.yaml`:

```yaml
apply_default_branch_protection: false
auto_init: true
builtin_ruleset_names:
  - default_branch
collaborators:
  users:
    - permission: admin
      username: robinbowes
delete_branch_on_merge: true
name: go-udap          # must equal the filename stem
```

Two schema rules enforced by the wrapper module:

1. The `name:` field must equal the filename stem. Mismatch fails `plan` with
   an explicit error.
2. Files with leading-underscore stems (e.g. `_teams.yaml`) are reserved and
   excluded from the repo glob. This leaves room for future per-org metadata
   files without changing the directory structure.

### Org enumeration

Orgs are listed explicitly in the root `main.tf`. They cannot be derived from
`data/` alone because each org requires a provider block (which must be
static).

## Components

### Root module (`./`)

```hcl
# providers.tf
provider "github" {
  alias = "yo61"
  owner = "yo61"
}
provider "github" {
  alias = "robinbowes"
  owner = "robinbowes"
}

# main.tf
module "org_yo61" {
  source    = "./modules/org"
  org       = "yo61"
  providers = { github = github.yo61 }
}

module "org_robinbowes" {
  source    = "./modules/org"
  org       = "robinbowes"
  providers = { github = github.robinbowes }
}
```

Adding a new org: one provider block + one module call + a new data directory.

### `modules/org` (new wrapper)

Responsibility: turn `data/<org>/*.yaml` into a set of `modules/github-repo`
instances, plus per-org drift detection.

```
modules/org/
├── versions.tf
├── variables.tf
├── data.tf
└── main.tf
```

`versions.tf` declares the provider dependency normally — no
`configuration_aliases` is needed because the module uses the default
`github` provider name internally; the root maps its aliased provider into
that slot via `providers = { github = github.<org> }` in the module call.

```hcl
terraform {
  required_version = "~> 1.15"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
```

`variables.tf`:

```hcl
variable "org" {
  description = "GitHub organisation slug (matches the data/<org>/ directory)."
  type        = string
}
```

`data.tf` (sketch — final form may differ slightly):

```hcl
locals {
  # Repo-root-relative; no `path.module` prefix. stategraph auto-prepends
  # `${path.module}/../../` to file()/fileset() calls during plan, so writing
  # the prefix here would cause it to stack. Plain terraform invoked from the
  # repo root also resolves this correctly.
  data_dir = "data/${var.org}"

  # Repo files = every *.yaml excluding leading-underscore reserved names
  repo_files = toset([
    for f in fileset(local.data_dir, "*.yaml") : f
    if !startswith(f, "_")
  ])

  raw_repo_data = {
    for f in local.repo_files :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.data_dir}/${f}"))
  }

  # Names where the filename stem disagrees with the `name:` field
  name_mismatches = {
    for stem, repo in local.raw_repo_data :
    stem => repo.name if stem != repo.name
  }
}

# Drift detection: implicitly uses the provider alias bound by the caller
data "github_repositories" "org" {
  query           = "org:${var.org}"
  include_repo_id = false
}

locals {
  configured_names = toset([for stem, _ in local.raw_repo_data : stem])
  github_names     = toset(data.github_repositories.org.names)
  missing_configs  = setsubtract(local.github_names, local.configured_names)
}

# Anchors the fatal name-mismatch validation. terraform_data is a no-op resource;
# its precondition evaluates at plan time and fails the plan on violation.
resource "terraform_data" "validations" {
  lifecycle {
    precondition {
      condition     = length(local.name_mismatches) == 0
      error_message = "Org ${var.org}: YAML files where filename stem differs from `name:` field: ${jsonencode(local.name_mismatches)}"
    }
  }
}

# Unmanaged repos (exist on GitHub but have no local config) are tolerated.
# The `check` block surfaces them as warnings during plan but does not block apply.
check "unmanaged_repos" {
  assert {
    condition     = length(local.missing_configs) == 0
    error_message = "Org ${var.org}: unmanaged repos (no local config): ${jsonencode(local.missing_configs)}"
  }
}
```

Two different primitives, deliberately:

- The name-mismatch check uses a `precondition` on `terraform_data "validations"`
  because a mismatched `name:` is a configuration bug that *must* be fixed
  before apply — the resource name in state would diverge from the filename.
  `precondition` fails the plan.
- The unmanaged-repos check uses a `check` block because tolerating unmanaged
  repos is an explicit project preference: GitHub may legitimately have repos
  this Terraform setup doesn't manage. `check` blocks emit warnings without
  blocking, so the operator still sees the list at plan time but `apply`
  proceeds.

A note on `terraform destroy`: the `precondition` on `terraform_data.validations`
fires during destroy planning too. If a destroy is genuinely needed despite a
name mismatch (unlikely, since destroys are rare in this repo), the operator
uses `-target` to bypass the validation resource.

`main.tf` calls `modules/github-repo` once per repo, passing the provider
through. The 35-line parameter passthrough from today's root `main.tf` moves
here, unchanged in substance.

### `modules/github-repo` (existing — minor changes)

Changes from current state:

1. Remove the `autolinks` variable and the `github_repository_autolink_reference`
   resource. These exist only for Linear, which is dropped.
2. Flip `apply_default_branch_protection` default from `true` to `false`.
   Rulesets are the preferred mechanism; legacy branch protection is opt-in.
3. Flip `create_default_branch` default from `true` to `false`. On existing
   repos the default branch exists already; the import flow doesn't need to
   recreate or adopt it as a separate resource by default.
4. Replace the deprecated `vulnerability_alerts` argument on `github_repository`
   with a standalone `github_repository_vulnerability_alerts` resource.
5. `versions.tf` stays as-is (no `configuration_aliases` needed — the module
   uses the default `github` provider, which `modules/org` inherits from the
   root's `providers = { … }` map).
6. Branch protection (now opt-in), rulesets, collaborators all stay.

### Interface contract

| Caller | Callee | In | Out |
|--------|--------|----|-----|
| Root | `modules/org` | `var.org`, aliased `github` provider | — |
| `modules/org` | `modules/github-repo` | one YAML-decoded repo map, the org's `github` provider | — |

`modules/github-repo` has no concept of an org. `modules/org` has no concept
of rulesets, branch protection, or repository settings.

## Error handling

Three failure classes, each with one named guardrail.

**Class 1 — Drift (GitHub has a repo with no YAML config):**
Handled by a `check "unmanaged_repos"` block in `modules/org/data.tf`. Lists
every unconfigured repo in one warning message during `plan`. Does **not**
block — `apply` proceeds normally. Unmanaged repos are an explicit tolerated
state, not a failure.

**Class 2 — YAML schema problems:**

- Filename/name mismatch: `precondition` on `terraform_data "validations"`,
  listing every mismatched file in one message. Fails plan.
- Malformed YAML: `yamldecode` surfaces a parse error pointing at the file.
- Unknown keys: silently ignored (matches today's `lookup(…, null)` pattern).
  Trade-off accepted for now; a key-allowlist check is possible future work.

**Class 3 — GitHub API errors:**
Treated as transient. The provider's built-in retry applies. Auth failures
surface at the first `data.github_repositories.org` query and identify which
org's provider failed. Write failures from the provider include the repo name
and are scoped to the state path `module.org_<x>.module.repo["<name>"]`.

**Explicitly not handled:**

- No custom retry/backoff. The provider handles this.
- No "deleted YAML file → terraform destroys the repo" protection. State is
  the source of truth; the operator must read their plan output. Adding a
  guard would fight Terraform's model.
- No detection of repos manually deleted from GitHub. State diverges, plan
  shows recreate — correct behaviour, not an error to suppress.

## Testing

### Static checks (pre-commit)

Extend `.pre-commit-config.yaml` with:

- `terraform fmt` — formatting
- `terraform validate` — types, provider wiring (catches missing
  `configuration_aliases` setup)
- `yamllint` on `data/**/*.yaml`
- Filename ↔ `name:` agreement (small shell hook, mirrors the in-module
  validation but at commit time)
- `tflint` (optional but recommended)

### Plan-as-test

PRs that touch `data/` or any `.tf` file must include the relevant
`stategraph tf plan` output in their description. The author confirms the plan
does only what's intended before merge/apply. (Documented in README.)

### One-time end-to-end smoke test

After implementation, the operator runs through:

1. `stategraph tf init` succeeds.
2. `stategraph tf plan` proposes creating
   `module.org_yo61.module.repo["go-udap"]` and sub-resources matching the
   existing `go-udap.yaml`.
3. `stategraph tf apply` (with approval) creates `go-udap` on yo61.
4. Create an unconfigured repo on GitHub manually (or rename a YAML file);
   `stategraph tf plan` fails with the drift-detection error.
5. Restore; plan goes clean.

### Out of scope

- No `terraform test` / Terratest suite. Too heavy for the codebase size.
- No CI-driven integration tests. Single-operator workflow doesn't justify it.

## Acceptance criteria

The refactor is complete when:

1. `stategraph tf plan` runs cleanly with no errors when state is empty and
   only `data/yo61/go-udap.yaml` exists.
2. Adding a stub `data/robinbowes/<repo>.yaml` plus a provider/module block
   for robinbowes produces a coherent plan with no errors.
3. Removing `data/yo61/go-udap.yaml` and re-running `plan` produces a
   destroy-only plan for that repo (no cascade).
4. Manually creating a GitHub repo with no YAML triggers the
   `check "unmanaged_repos"` warning with a message listing the unmanaged
   repo. `stategraph tf plan` still exits zero — apply is not blocked.
5. All pre-commit hooks pass on a clean tree.
6. README, Taskfile, and `imports.tf.template` reflect the new workflow:
   `stategraph` (not terragrunt), no AWS account checks, state-key shape uses
   the new `module.org_<x>.module.repo["<y>"]` form.

## Files changed at a glance

| File | Change |
|------|--------|
| `providers.tf` | Replace single `owner = "robinbowes"` block with one aliased block per org |
| `main.tf` | Replace single `module "repo"` block with one `module "org_<name>"` call per org |
| `data.tf` | Delete — logic moves to `modules/org/data.tf` |
| `versions.tf` | No change (no backend block needed; stategraph handles state) |
| `imports.tf.template` | Update state-key form to `module.org_<org>.module.repo[...]` |
| `Taskfile.yaml` | Replace terragrunt + AWS-account preconditions with `stategraph tf …` |
| `README.md` | Rewrite for stategraph + multi-org |
| `.pre-commit-config.yaml` | Add `terraform fmt`, `terraform validate`, filename-name check |
| `modules/org/` | New module (versions, variables, data, main) |
| `modules/github-repo/variables.tf` | Remove `autolinks` variable |
| `modules/github-repo/main.tf` | Remove `github_repository_autolink_reference` resource |
| `data/yo61/go-udap.yaml` | No change |

## Open questions / future work

- **Team support**: if/when `yo61` or `robinbowes` actually need teams,
  introduce `data/<org>/_teams.yaml` and re-add a `github_team` resource and
  slug→id transform in `modules/org`. The repo schema already supports
  `collaborators.teams`.
- **YAML key allowlist**: a stricter validation pass that fails on unknown
  keys would catch typos like `descriptin:` silently being ignored. Possible
  to bolt on with a `setsubtract` over known keys.
- **Per-org default settings**: today every repo carries its own settings.
  A future enhancement could let `data/<org>/_defaults.yaml` set
  org-wide defaults that individual repos override.
