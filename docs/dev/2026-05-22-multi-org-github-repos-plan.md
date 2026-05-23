# Multi-org GitHub repo management — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor this repo to manage GitHub repositories across multiple orgs (initially `yo61`, prepared for `robinbowes`) driven by `data/<org>/<repo>.yaml`.

**Architecture:** Single Terraform state managed by `stategraph`. A root module declares one aliased `github` provider per org. A new thin wrapper module (`modules/org`) loads `data/<org>/*.yaml`, runs validation + drift detection via `terraform_data` preconditions, and instantiates the existing `modules/github-repo` once per repo.

**Tech Stack:** Terraform `~> 1.15`, `integrations/github ~> 6.0` provider, `local ~> 2.0` provider, `stategraph` for state, `pre-commit` for static checks, `Task` for command shortcuts.

**Source of truth:** See [the design spec](./2026-05-22-multi-org-github-repos-design.md) for the rationale behind every architectural choice. This plan implements that spec.

**Branch:** All commits land on `design/multi-org-spec` (already created, with the spec doc as its root commit). Rename or merge to a long-lived branch when implementation is complete.

**Required env:** A `GITHUB_TOKEN` with org-read scope on `yo61` is needed for `stategraph tf plan` (the `data "github_repositories"` query). Validation steps that don't need GitHub auth use `terraform validate`.

---

## File structure (target state)

```
github-repos/
├── .pre-commit-config.yaml      # MODIFIED: drop AWS-specific arg, drop black, add filename-name check
├── .gitignore                   # unchanged
├── README.md                    # already rewritten in cleanup turn
├── Taskfile.yaml                # already rewritten in cleanup turn
├── versions.tf                  # unchanged
├── providers.tf                 # REPLACED: aliased provider per org
├── main.tf                      # REPLACED: one module "org_<name>" call per org
├── data.tf                      # DELETED: logic moves to modules/org/data.tf
├── imports.tf.template          # REPLACED: new state-key shape
├── stategraph.json              # unchanged
├── data/
│   └── yo61/go-udap.yaml        # unchanged
├── modules/
│   ├── org/                     # NEW
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── data.tf              # YAML load, drift query, validations
│   │   └── main.tf              # for_each over repos → modules/github-repo
│   └── github-repo/             # MODIFIED: drop autolinks
│       ├── versions.tf          # unchanged
│       ├── variables.tf         # MODIFIED: remove `autolinks` variable
│       ├── main.tf              # MODIFIED: remove autolink resource
│       ├── data.tf              # unchanged
│       ├── rulesets.tf          # unchanged
│       ├── outputs.tf           # unchanged
│       ├── README.md            # unchanged (terraform_docs will regen if it changes)
│       └── data/rulesets.yaml   # unchanged
```

---

## Task 1: Tidy `.pre-commit-config.yaml` and add the filename↔name check

**Files:**
- Modify: `.pre-commit-config.yaml`
- Create: `scripts/check_repo_yaml_name.sh`

Removes the `AWS_DEFAULT_REGION` arg (it existed for the original AWS-bound workflow) and the unused `black` hook (no Python in this repo). Adds a local shell hook that catches filename↔`name:` mismatches at commit time, mirroring the spec's static-check requirement (the in-module precondition catches the same problem later at plan time — pre-commit just makes the feedback faster).

- [ ] **Step 1: Create the filename↔name check script**

```bash
mkdir -p scripts
```

Create `scripts/check_repo_yaml_name.sh`:

```bash
#!/usr/bin/env bash
# Verify every data/<org>/<repo>.yaml file's `name:` field equals its filename stem.
# Files whose basename starts with `_` are reserved metadata files and are skipped.

set -euo pipefail

status=0
for file in "$@"; do
  base="$(basename "$file" .yaml)"
  case "$base" in
    _*) continue ;;
  esac
  name="$(awk -F': *' '/^name:/ { print $2; exit }' "$file" || true)"
  name="${name%\"}"
  name="${name#\"}"
  name="${name%\'}"
  name="${name#\'}"
  if [[ -z "$name" ]]; then
    echo "ERROR: $file is missing a top-level \`name:\` field" >&2
    status=1
  elif [[ "$name" != "$base" ]]; then
    echo "ERROR: $file has name=\"$name\" but filename stem is \"$base\"" >&2
    status=1
  fi
done
exit "$status"
```

```bash
chmod +x scripts/check_repo_yaml_name.sh
```

- [ ] **Step 2: Replace the contents of `.pre-commit-config.yaml`**

```yaml
---
repos:
- repo: https://github.com/pre-commit/pre-commit-hooks
  rev: v6.0.0
  hooks:
  - id: check-json
  - id: check-merge-conflict
  - id: check-yaml
  - id: trailing-whitespace
  - id: end-of-file-fixer

- repo: https://github.com/adrienverge/yamllint.git
  rev: v1.37.1
  hooks:
  - id: yamllint
    args: [--format, parsable, --strict]

- repo: https://github.com/jumanjihouse/pre-commit-hook-yamlfmt
  rev: 0.2.3
  hooks:
  - id: yamlfmt
    args: [--mapping, '2', --sequence, '2', --offset, '0', --width, '150']

- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.103.0
  hooks:
  - id: terraform_validate
  - id: terraform_fmt
  - id: terraform_docs

- repo: local
  hooks:
  - id: repo-yaml-name-check
    name: Verify data/<org>/<repo>.yaml name field matches filename stem
    entry: scripts/check_repo_yaml_name.sh
    language: script
    files: ^data/[^/]+/[^/]+\.yaml$
```

- [ ] **Step 3: Do NOT install hooks yet**

`pre-commit install` is deliberately deferred to Task 11. The existing `data.tf` references undeclared resources, so `terraform_validate` would block every commit between now and Task 8. Hooks get installed once the working tree is consistent.

- [ ] **Step 4: Commit**

```bash
git add .pre-commit-config.yaml scripts/check_repo_yaml_name.sh
git commit -m "Tidy pre-commit config and add filename-name check hook"
```

---

## Task 2: Remove autolinks from `modules/github-repo`

**Files:**
- Modify: `modules/github-repo/variables.tf` (remove `autolinks` variable)
- Modify: `modules/github-repo/main.tf` (remove autolink resource)

The Linear autolinks feature is dropped (see spec, "Out of scope").

- [ ] **Step 1: Remove the `autolinks` variable from `modules/github-repo/variables.tf`**

Delete this block (currently lines 64–69):

```hcl
variable "autolinks" {
  description = "issue autolink configuration set"
  type        = list(object({ key_prefix = string, target_url_template = string, is_alphanumeric = bool }))
  default     = []
  nullable    = false
}
```

- [ ] **Step 2: Remove the autolink resource from `modules/github-repo/main.tf`**

Delete this block (currently lines 134–141):

```hcl
resource "github_repository_autolink_reference" "this" {
  for_each = { for al in var.autolinks : al.key_prefix => al }

  repository          = github_repository.this.name
  key_prefix          = each.value.key_prefix
  target_url_template = each.value.target_url_template
  is_alphanumeric     = each.value.is_alphanumeric
}
```

- [ ] **Step 3: Validate the module syntactically**

```bash
cd modules/github-repo && terraform init -backend=false && terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 4: Reset the temporary `.terraform/` dir created by the validate step**

```bash
rm -rf modules/github-repo/.terraform modules/github-repo/.terraform.lock.hcl
```

- [ ] **Step 5: Commit**

```bash
git add modules/github-repo/variables.tf modules/github-repo/main.tf
git commit -m "Remove autolinks support from github-repo module"
```

---

## Task 3: Create the `modules/org` skeleton (versions + variables)

**Files:**
- Create: `modules/org/versions.tf`
- Create: `modules/org/variables.tf`

- [ ] **Step 1: Create `modules/org/versions.tf`**

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

Note: no `configuration_aliases` — the root passes its aliased provider into this module's default `github` slot via `providers = { github = github.<org> }`.

- [ ] **Step 2: Create `modules/org/variables.tf`**

```hcl
variable "org" {
  description = "GitHub organisation slug. Must match the data/<org>/ directory name."
  type        = string
  nullable    = false
}
```

- [ ] **Step 3: Commit**

```bash
git add modules/org/versions.tf modules/org/variables.tf
git commit -m "Add modules/org skeleton (versions + variables)"
```

---

## Task 4: Implement `modules/org/data.tf`

**Files:**
- Create: `modules/org/data.tf`

Loads `data/<org>/*.yaml`, runs the schema-validation and drift-detection checks via a `terraform_data` resource with `precondition` blocks.

- [ ] **Step 1: Create `modules/org/data.tf`**

```hcl
locals {
  # Repo-root-relative; no `path.module` prefix. stategraph auto-prepends
  # `${path.module}/../../` to file()/fileset() calls during plan, so writing
  # the prefix here would cause it to stack. Plain terraform invoked from the
  # repo root also resolves this correctly.
  data_dir = "data/${var.org}"

  # Repo files: every *.yaml in the org's directory excluding leading-underscore
  # reserved names (e.g. _teams.yaml in the future).
  repo_files = toset([
    for f in fileset(local.data_dir, "*.yaml") : f
    if !startswith(f, "_")
  ])

  raw_repo_data = {
    for f in local.repo_files :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.data_dir}/${f}"))
  }

  # Files where the filename stem disagrees with the YAML `name:` field.
  name_mismatches = {
    for stem, repo in local.raw_repo_data :
    stem => repo.name if stem != repo.name
  }
}

# Drift detection: implicitly uses the aliased github provider bound by the caller.
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

# Unmanaged repos (exist on GitHub but have no local config) are tolerated: the
# `check` block surfaces them as warnings during plan but does not block apply.
check "unmanaged_repos" {
  assert {
    condition     = length(local.missing_configs) == 0
    error_message = "Org ${var.org}: unmanaged repos (no local config): ${jsonencode(local.missing_configs)}"
  }
}
```

- [ ] **Step 2: Validate the module syntactically**

```bash
cd modules/org && terraform init -backend=false && terraform validate
```

Expected: `Success! The configuration is valid.`

(Validation does not contact GitHub or evaluate the data source. Full evaluation happens at plan time from the root.)

- [ ] **Step 3: Reset the temporary `.terraform/` dir**

```bash
rm -rf modules/org/.terraform modules/org/.terraform.lock.hcl
```

- [ ] **Step 4: Commit**

```bash
git add modules/org/data.tf
git commit -m "Add modules/org data loading and validation"
```

---

## Task 5: Implement `modules/org/main.tf` (instantiates github-repo per repo)

**Files:**
- Create: `modules/org/main.tf`

Mirrors the existing root `main.tf` parameter passthrough but iterates over the wrapper's loaded data and receives the aliased provider.

- [ ] **Step 1: Create `modules/org/main.tf`**

```hcl
locals {
  # Strip non-repo-config keys before passing the map into the child module.
  repo_data = {
    for name, repo in local.raw_repo_data :
    name => {
      for k, v in repo : k => v
      if k != "collaborators"
    }
  }

  collaborators = {
    for name, repo in local.raw_repo_data :
    name => lookup(repo, "collaborators", {})
  }
}

module "repo" {
  source = "../github-repo"

  for_each = local.repo_data

  additional_rulesets              = lookup(each.value, "additional_rulesets", null)
  allow_auto_merge                 = lookup(each.value, "allow_auto_merge", null)
  allow_merge_commit               = lookup(each.value, "allow_merge_commit", null)
  allow_rebase_merge               = lookup(each.value, "allow_rebase_merge", null)
  allow_squash_merge               = lookup(each.value, "allow_squash_merge", null)
  allow_update_branch              = lookup(each.value, "allow_update_branch", null)
  apply_default_branch_protection  = lookup(each.value, "apply_default_branch_protection", null)
  archived                         = lookup(each.value, "archived", null)
  auto_init                        = lookup(each.value, "auto_init", null)
  branch_protection_rules_override = lookup(each.value, "branch_protection_rules_override", null)
  builtin_ruleset_names            = lookup(each.value, "builtin_ruleset_names", null)
  collaborators                    = lookup(local.collaborators, each.key, {})
  create_default_branch            = lookup(each.value, "create_default_branch", true)
  default_branch                   = lookup(each.value, "default_branch", null)
  delete_branch_on_merge           = lookup(each.value, "delete_branch_on_merge", null)
  description                      = lookup(each.value, "description", null)
  has_discussions                  = lookup(each.value, "has_discussions", null)
  has_issues                       = lookup(each.value, "has_issues", null)
  has_projects                     = lookup(each.value, "has_projects", null)
  has_wiki                         = lookup(each.value, "has_wiki", null)
  homepage_url                     = lookup(each.value, "homepage_url", null)
  is_template                      = lookup(each.value, "is_template", null)
  merge_commit_message             = lookup(each.value, "merge_commit_message", null)
  merge_commit_title               = lookup(each.value, "merge_commit_title", null)
  name                             = each.value.name
  pages                            = lookup(each.value, "pages", null)
  squash_merge_commit_message      = lookup(each.value, "squash_merge_commit_message", null)
  squash_merge_commit_title        = lookup(each.value, "squash_merge_commit_title", null)
  template                         = lookup(each.value, "template", null)
  visibility                       = lookup(each.value, "visibility", null)
  vulnerability_alerts             = lookup(each.value, "vulnerability_alerts", null)
}
```

Notes vs the existing root `main.tf`:

- `name = each.value.name` (not `lookup(..., "name", null)`) — `name` is mandatory; we already validated it equals the filename stem.
- `collaborators` is read from the simpler `local.collaborators` map (no team-id translation, since no teams are managed yet — see spec "Open questions" for the path to re-add this).
- `builtin_ruleset_names` is alphabetised with the other variables.
- No `autolinks` (removed in Task 2).

- [ ] **Step 2: Validate the module syntactically**

```bash
cd modules/org && terraform init -backend=false && terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Reset the temporary `.terraform/` dir**

```bash
rm -rf modules/org/.terraform modules/org/.terraform.lock.hcl
```

- [ ] **Step 4: Commit**

```bash
git add modules/org/main.tf
git commit -m "Add modules/org main.tf instantiating github-repo per repo"
```

---

## Task 6: Replace root `providers.tf`

**Files:**
- Modify: `providers.tf` (replace contents)

- [ ] **Step 1: Replace the contents of `providers.tf`**

```hcl
provider "github" {
  alias = "yo61"
  owner = "yo61"
}
```

Only `yo61` is enabled for now. The `robinbowes` provider block is left for a later, deliberate addition (the spec's "Files changed at a glance" table lists this as the only multi-org-related change to providers.tf when the second org is wanted).

- [ ] **Step 2: Commit**

```bash
git add providers.tf
git commit -m "Replace root providers.tf with aliased github provider per org"
```

---

## Task 7: Replace root `main.tf`

**Files:**
- Modify: `main.tf` (replace contents)

- [ ] **Step 1: Replace the contents of `main.tf`**

```hcl
module "org_yo61" {
  source = "./modules/org"

  org = "yo61"

  providers = {
    github = github.yo61
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add main.tf
git commit -m "Replace root main.tf with module org_yo61 call"
```

---

## Task 8: Delete the old root `data.tf`

**Files:**
- Delete: `data.tf`

All of its logic has been re-homed in `modules/org/data.tf` and `modules/org/main.tf`. The remaining content references undeclared resources (`github_team.this`) and missing files (`data/teams.yaml`, `data/linear.yaml`) — deletion is the cleanup.

- [ ] **Step 1: Remove the file**

```bash
git rm data.tf
```

- [ ] **Step 2: Validate the root module**

```bash
terraform init -backend=false && terraform validate
```

Expected: `Success! The configuration is valid.`

(If validation complains about a missing `local` or data reference that wasn't migrated, return to the relevant task and add what's missing before continuing.)

- [ ] **Step 3: Reset the temporary `.terraform/` dir**

```bash
rm -rf .terraform .terraform.lock.hcl
```

- [ ] **Step 4: Commit**

```bash
git commit -m "Delete root data.tf (logic moved to modules/org)"
```

---

## Task 9: Update `imports.tf.template`

**Files:**
- Modify: `imports.tf.template`

The state-key shape changed from `module.repo["foo"]` to `module.org_<org>.module.repo["foo"]`. Update the template so future imports use the right keys.

- [ ] **Step 1: Replace the contents of `imports.tf.template`**

```hcl
# Replace <ORG> with the GitHub org (e.g. yo61) and <REPO> with the repo name.

import {
  to = module.org_<ORG>.module.repo["<REPO>"].github_repository.this
  id = "<REPO>"
}

import {
  to = module.org_<ORG>.module.repo["<REPO>"].github_branch.this["default"]
  id = "<REPO>:main"
}

import {
  to = module.org_<ORG>.module.repo["<REPO>"].github_branch_default.this["default"]
  id = "<REPO>"
}

import {
  to = module.org_<ORG>.module.repo["<REPO>"].github_repository_collaborators.this
  id = "<REPO>"
}

# Uncomment if the repo has branch protection rather than rulesets:
# import {
#   to = module.org_<ORG>.module.repo["<REPO>"].github_branch_protection.this["main"]
#   id = "<REPO>:main"
# }
```

- [ ] **Step 2: Commit**

```bash
git add imports.tf.template
git commit -m "Update imports.tf.template for multi-org state-key shape"
```

---

## Task 10: Stage the pre-commit cleanup turn's changes

The earlier turn rewrote `README.md`, `Taskfile.yaml`, deleted `examples/`, edited `modules/github-repo/README.md`, and modified `data.tf` (now deleted in Task 8). Those edits are untracked / uncommitted at the start of this plan. They need to land in their own commit(s) for a clean history.

**Files:**
- Stage: `README.md`, `Taskfile.yaml`, `modules/github-repo/README.md`, and the deletion of `examples/`

- [ ] **Step 1: Verify what's still untracked or modified**

```bash
git status
```

Expected: shows modifications to `README.md`, `Taskfile.yaml`, `modules/github-repo/README.md`, and a deleted `examples/` directory. (`data.tf`'s modification is moot — Task 8 already removed the file.)

- [ ] **Step 2: Stage the README, Taskfile, module README, and the deleted examples dir**

```bash
git add README.md Taskfile.yaml modules/github-repo/README.md
git add -A examples/
```

- [ ] **Step 3: Commit**

```bash
git commit -m "Update README, Taskfile, and remove dead examples for multi-org refactor"
```

- [ ] **Step 4: Confirm clean working tree**

```bash
git status
```

Expected: `nothing to commit, working tree clean` (the `.gitignore`, `.pre-commit-config.yaml`, `stategraph.json`, `versions.tf`, `data/`, and `modules/` are tracked; nothing else is outstanding).

---

## Task 11: End-to-end verification

This is the smoke test from the spec ("acceptance criteria"). It requires `GITHUB_TOKEN` to be set.

**Files:** none modified

- [ ] **Step 1: Confirm `GITHUB_TOKEN` is set**

```bash
test -n "${GITHUB_TOKEN:-}" && echo "token present" || echo "missing GITHUB_TOKEN — set it before continuing"
```

Expected: `token present`.

- [ ] **Step 2: One-time stategraph state setup (if not already done)**

Stategraph has no `init` subcommand. State is set up via `stategraph states create` or `stategraph import tf` — consult the [Stategraph docs](https://stategraph.com/docs/velocity/setup) for the exact command for your tenant. Skip if state already exists for this project.

- [ ] **Step 3: Run plan and inspect**

```bash
stategraph tf plan --out tfplan.json
```

The plan command writes a JSON plan file; review it (and the human-readable plan summary printed to stdout) before applying.

Plan output depends on what already exists on GitHub. There are three cases — handle the one that matches your situation.

**Case A — `go-udap` does NOT exist on `yo61` GitHub yet:**

Plan proposes creating `module.org_yo61.module.repo["go-udap"].github_repository.this` and its sub-resources. No drift errors. Apply (Step 5) will create the repo on GitHub.

**Case B — `go-udap` already exists on `yo61` GitHub:**

Plan also proposes creating it, but `apply` will fail with "name already exists on this account" because the repo is unmanaged-by-Terraform. You need to import it first. Copy the template and substitute the org and repo:

```bash
cp imports.tf.template imports-go-udap.tf
sed -i '' -e 's/<ORG>/yo61/g' -e 's/<REPO>/go-udap/g' imports-go-udap.tf
```

Re-run the plan — the imports will adopt the existing resources into state, and the plan should now show "no changes" or only diffs reflecting what the YAML asks to update. Once the plan looks clean:

```bash
stategraph tf plan --out tfplan.json
stategraph tf apply tfplan.json     # applies the imports (and any setting changes)
rm imports-go-udap.tf               # imports are one-shot; remove after applying
```

**Case C — `yo61` has OTHER repos on GitHub without YAML files:**

Plan succeeds, but emits a warning: `Warning: Check block assertion failed — Org yo61: unmanaged repos (no local config): [...]` listing each one. Apply still works. This is the tolerated-drift behaviour — unmanaged repos are flagged but do not block the workflow.

- [ ] **Step 4 (optional): Verify the name-mismatch precondition**

Temporarily edit `data/yo61/go-udap.yaml` and change `name: go-udap` to `name: wrong-name`. Run:

```bash
stategraph tf plan --out tfplan.json
```

Expected: plan fails (no tfplan.json written) with `Org yo61: YAML files where filename stem differs from `name:` field: {"go-udap":"wrong-name"}`.

Restore the file:

```bash
git checkout data/yo61/go-udap.yaml
```

Re-run the plan command — expected to be clean (or back to the drift error from Step 3 if applicable).

- [ ] **Step 5: Apply (operator decision)**

If the plan from Step 3 looks correct **and you want to commit the change to real GitHub state**, run:

```bash
stategraph tf apply tfplan.json
```

Expected: `go-udap` exists on the `yo61` org with the settings declared in `data/yo61/go-udap.yaml`.

If you'd rather not apply yet, delete `tfplan.json` and revisit before declaring the refactor done.

- [ ] **Step 6: Install pre-commit hooks and run them**

The working tree is now consistent, so it's safe to install hooks.

```bash
pre-commit install
pre-commit run --all-files
```

Expected: all hooks pass. If `terraform_docs` modifies `modules/github-repo/README.md`, stage and commit those changes:

```bash
git add modules/github-repo/README.md
git commit -m "Regenerate module docs"
```

- [ ] **Step 7: Verify acceptance criteria 1–5 from the spec**

Mark each off:

1. `stategraph tf plan` runs cleanly when state is empty and only `data/yo61/go-udap.yaml` exists. (Caveat: depends on whether yo61 has untracked repos on GitHub — see Step 3.)
2. Adding a stub `data/robinbowes/<repo>.yaml` plus a provider/module block produces a coherent plan. (Optional bonus check — not required for the refactor to be considered done.)
3. Removing `data/yo61/go-udap.yaml` and re-running `plan` produces a destroy-only plan for that repo (test only after applying in Step 5; revert before continuing).
4. Manually creating a GitHub repo with no YAML triggers the `check "unmanaged_repos"` warning at plan time, but does NOT block apply. (Step 3 Case C effectively tests this when yo61 has untracked repos.)
5. `pre-commit run --all-files` passes (verified in Step 6).

---

## Wrap-up

When all tasks above are complete:

- The branch `design/multi-org-spec` contains the spec doc plus the implementation.
- `git log --oneline` should show ~11 commits (1 spec + 10 implementation).
- The repo can be `stategraph tf plan`-ed cleanly.
- Adding `robinbowes` is straightforward: add a `data/robinbowes/` directory, add a provider block in `providers.tf` aliased to `robinbowes`, add a `module "org_robinbowes"` block in `main.tf` passing that provider. No other changes needed.

To rename the branch to something more accurate for its final state:

```bash
git branch -m design/multi-org-spec multi-org-refactor
```
