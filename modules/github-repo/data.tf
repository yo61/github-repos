locals {
  branch_protection_rules_default = {
    allows_deletions                = false
    allows_force_pushes             = false
    enforce_admins                  = true
    force_push_bypassers            = []
    require_conversation_resolution = false
    required_linear_history         = false
    require_signed_commits          = true
    required_pull_request_reviews = {
      dismiss_stale_reviews           = true
      require_code_owner_reviews      = false
      require_last_push_approval      = false
      required_approving_review_count = 1
    }
  }
  branch_protection_rules = merge(
    local.branch_protection_rules_default,
    var.branch_protection_rules_override
  )

  # Read built-in rulesets from file
  rulesets_file    = "${path.module}/data/rulesets.yaml"
  builtin_rulesets = yamldecode(file(local.rulesets_file))

  # build a map of all selected built-in rulesets
  selected_builtin_rulesets = {
    for name, data in local.builtin_rulesets : name => data
    if contains(var.builtin_ruleset_names, name)
  }

  # merge the selected built-in rulesets and any additional rulesets into one map
  rulesets = merge(
    local.selected_builtin_rulesets,
    var.additional_rulesets
  )
}
