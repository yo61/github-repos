locals {
  # Repo-root-relative path to this org's data directory. Written without
  # `path.module` because stategraph auto-prepends `${path.module}/../../` to
  # both `fileset()` and `file()` calls; including `path.module` here would
  # cause the prefix to stack and the resolved path to be wrong. When running
  # plain terraform (no stategraph), the same path works as long as terraform
  # is invoked from the repo root, which is the convention in this project.
  data_dir = "data/${var.org}"

  # Optional per-org metadata. Absent file means the org manages no teams, so
  # its existing teams are left alone rather than adopted or destroyed.
  teams_file = "${local.data_dir}/_teams.yaml"
  teams      = fileexists(local.teams_file) ? coalesce(yamldecode(file(local.teams_file)), {}) : {}

  # Repo files: every *.yaml in the org's directory excluding leading-underscore
  # reserved names (e.g. _teams.yaml).
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
# Repos in the org that are expected to carry local config. Fork and archive
# status are GitHub's source of truth. Drives two things: scoping the
# admin-role bypass, and drift detection.
#
# Forks are intentionally unmanaged. Archived repos are frozen — GitHub rejects
# writes to them, so a data file could not be applied even if one existed, and
# the bypass would be inert. Excluding both keeps `missing_configs` to repos
# that can actually be managed.
#
# The name stays `non_fork` because `default_branch_ruleset_non_fork_bypass_actors`
# is part of this module's public interface; the set is now narrower than the
# name suggests.
data "github_repositories" "non_fork" {
  query           = "org:${var.org} fork:false archived:false"
  include_repo_id = false
}

locals {
  configured_names = toset([for stem, _ in local.raw_repo_data : stem])
  non_fork_names   = toset(data.github_repositories.non_fork.names)
  missing_configs  = setsubtract(local.non_fork_names, local.configured_names)

  # Team slugs a repo grants to that this org does not manage. Without this
  # check the `lookup(var.team_ids, slug, slug)` fallback in
  # modules/github-repo/main.tf sends the bare slug to the API, and a typo
  # surfaces as an opaque apply-time error instead of a named plan failure.
  unknown_team_refs = flatten([
    for name, collab in local.collaborators : [
      for team in coalesce(lookup(collab, "teams", []), []) : "${name}: ${team.slug}"
      if !contains(keys(local.teams), team.slug)
    ]
  ])
}

# Anchors the fatal name-mismatch validation. terraform_data is a no-op resource;
# its precondition evaluates at plan time and fails the plan on violation.
resource "terraform_data" "validations" {
  lifecycle {
    precondition {
      condition     = length(local.name_mismatches) == 0
      error_message = "Org ${var.org}: YAML files where filename stem differs from `name:` field: ${jsonencode(local.name_mismatches)}"
    }

    precondition {
      condition     = length(local.unknown_team_refs) == 0
      error_message = "Org ${var.org}: repos grant to team slugs absent from ${local.teams_file}: ${jsonencode(local.unknown_team_refs)}"
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
