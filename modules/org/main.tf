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
  create_default_branch            = lookup(each.value, "create_default_branch", null)
  default_branch                   = lookup(each.value, "default_branch", null)
  default_branch_ruleset_bypass_actors = lookup(
    each.value, "default_branch_ruleset_bypass_actors", var.default_branch_ruleset_bypass_actors
  )
  default_branch_ruleset_require_last_push_approval = lookup(
    each.value, "default_branch_ruleset_require_last_push_approval", var.default_branch_ruleset_require_last_push_approval
  )
  default_branch_ruleset_required_approving_review_count = lookup(
    each.value, "default_branch_ruleset_required_approving_review_count", var.default_branch_ruleset_required_approving_review_count
  )
  delete_branch_on_merge      = lookup(each.value, "delete_branch_on_merge", null)
  description                 = lookup(each.value, "description", null)
  has_discussions             = lookup(each.value, "has_discussions", null)
  has_issues                  = lookup(each.value, "has_issues", null)
  has_projects                = lookup(each.value, "has_projects", null)
  has_wiki                    = lookup(each.value, "has_wiki", null)
  homepage_url                = lookup(each.value, "homepage_url", null)
  is_template                 = lookup(each.value, "is_template", null)
  merge_commit_message        = lookup(each.value, "merge_commit_message", null)
  merge_commit_title          = lookup(each.value, "merge_commit_title", null)
  name                        = each.value.name
  pages                       = lookup(each.value, "pages", null)
  security_and_analysis       = lookup(each.value, "security_and_analysis", null)
  squash_merge_commit_message = lookup(each.value, "squash_merge_commit_message", null)
  squash_merge_commit_title   = lookup(each.value, "squash_merge_commit_title", null)
  template                    = lookup(each.value, "template", null)
  visibility                  = lookup(each.value, "visibility", null)
  vulnerability_alerts        = lookup(each.value, "vulnerability_alerts", null)
}
