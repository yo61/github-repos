resource "github_repository" "this" {
  allow_auto_merge            = var.allow_auto_merge
  allow_merge_commit          = var.allow_merge_commit
  allow_rebase_merge          = var.allow_rebase_merge
  allow_squash_merge          = var.allow_squash_merge
  allow_update_branch         = var.allow_update_branch
  archived                    = var.archived
  auto_init                   = var.auto_init
  delete_branch_on_merge      = var.delete_branch_on_merge
  description                 = var.description
  has_discussions             = var.has_discussions
  has_issues                  = var.has_issues
  has_projects                = var.has_projects
  has_wiki                    = var.has_wiki
  homepage_url                = var.homepage_url
  is_template                 = var.is_template
  merge_commit_message        = var.merge_commit_message
  merge_commit_title          = var.merge_commit_title
  name                        = var.name
  squash_merge_commit_message = var.squash_merge_commit_message
  squash_merge_commit_title   = var.squash_merge_commit_title
  dynamic "template" {
    for_each = var.template[*]
    content {
      include_all_branches = var.template.include_all_branches
      owner                = var.template.owner
      repository           = var.template.repository
    }
  }
  visibility = var.visibility

  lifecycle {
    ignore_changes = [pages]
  }
}

resource "github_repository_pages" "this" {
  for_each = toset(var.pages == null ? [] : ["pages"])

  repository = github_repository.this.name
  build_type = var.pages.build_type
  cname      = var.pages.cname

  dynamic "source" {
    for_each = var.pages.source[*]
    content {
      branch = var.pages.source.branch
      path   = var.pages.source.path
    }
  }
}

resource "github_repository_vulnerability_alerts" "this" {
  repository = github_repository.this.name
  enabled    = var.vulnerability_alerts
}

resource "github_branch" "this" {
  for_each = toset(var.create_default_branch ? ["default"] : [])

  repository = github_repository.this.name
  branch     = var.default_branch
}

resource "github_branch_default" "this" {
  for_each = github_branch.this

  repository = github_repository.this.name
  branch     = github_branch.this[each.key].branch
}

resource "github_branch_protection" "this" {
  for_each = {
    for branch in(var.apply_default_branch_protection ? github_branch_default.this : {}) :
    branch.branch => local.branch_protection_rules
  }

  repository_id = github_repository.this.node_id

  pattern                         = each.key
  allows_deletions                = lookup(each.value, "allows_deletions", null)
  allows_force_pushes             = lookup(each.value, "allows_force_pushes", null)
  enforce_admins                  = lookup(each.value, "enforce_admins", null)
  force_push_bypassers            = lookup(each.value, "force_push_bypassers", [])
  require_conversation_resolution = lookup(each.value, "require_conversation_resolution", null)
  required_linear_history         = lookup(each.value, "required_linear_history", null)
  require_signed_commits          = lookup(each.value, "require_signed_commits", null)

  dynamic "required_pull_request_reviews" {
    for_each = lookup(each.value, "required_pull_request_reviews", null)[*]
    content {
      dismiss_stale_reviews           = lookup(each.value.required_pull_request_reviews, "dismiss_stale_reviews", null)
      dismissal_restrictions          = lookup(each.value.required_pull_request_reviews, "dismissal_restrictions", null)
      pull_request_bypassers          = lookup(each.value.required_pull_request_reviews, "pull_request_bypassers", null)
      require_code_owner_reviews      = lookup(each.value.required_pull_request_reviews, "require_code_owner_reviews", null)
      require_last_push_approval      = lookup(each.value.required_pull_request_reviews, "require_last_push_approval", null)
      required_approving_review_count = lookup(each.value.required_pull_request_reviews, "required_approving_review_count", null)
      restrict_dismissals             = lookup(each.value.required_pull_request_reviews, "restrict_dismissals", null)
    }
  }

  dynamic "required_status_checks" {
    for_each = lookup(each.value, "required_status_checks", null)[*]
    content {
      contexts = lookup(each.value.required_status_checks, "contexts", null)
      strict   = lookup(each.value.required_status_checks, "strict", null)
    }
  }

  dynamic "restrict_pushes" {
    for_each = lookup(each.value, "restrict_pushes", null)[*]
    content {
      blocks_creations = lookup(each.value.restrict_pushes, "blocks_creations", null)
      push_allowances  = lookup(each.value.restrict_pushes, "push_allowances", null)
    }
  }
}

resource "github_repository_collaborators" "this" {
  repository = github_repository.this.name

  dynamic "team" {
    # allow teams to be omitted from the collaborators structure
    for_each = toset(coalesce(var.collaborators.teams, []))

    # we can speed things up by passing in a map of team_ids, indexed on team slug
    # if no id is found for the slug, pass in the slug instead
    content {
      permission = team.value.permission
      team_id    = lookup(var.team_ids, team.value.slug, team.value.slug)
    }
  }

  dynamic "user" {
    # allow users to be omitted from the collaborators structure
    for_each = toset(coalesce(var.collaborators.users, []))
    content {
      permission = user.value.permission
      username   = user.value.username
    }
  }
}
