locals {
  # Repo-root-relative path to this org's data directory. Written without
  # `path.module` because stategraph auto-prepends `${path.module}/../../` to
  # both `fileset()` and `file()` calls; including `path.module` here would
  # cause the prefix to stack and the resolved path to be wrong. When running
  # plain terraform (no stategraph), the same path works as long as terraform
  # is invoked from the repo root, which is the convention in this project.
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
