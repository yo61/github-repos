locals {
  # Secret scanning and push protection are free on public repos and require
  # GHAS on private ones, where the API returns 422. Default them on for public
  # repos so a new repo is protected without having to remember, and leave
  # private repos unmanaged. An explicit security_and_analysis in the repo's
  # YAML still wins.
  #
  # Push protection is the part worth having: it blocks a secret at push time,
  # which no CI job can do — a scanner only reports what is already pushed.
  security_and_analysis_default = var.visibility == "public" ? {
    advanced_security               = null
    secret_scanning                 = true
    secret_scanning_push_protection = true
  } : null

  security_and_analysis = var.security_and_analysis != null ? var.security_and_analysis : local.security_and_analysis_default

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
  rulesets_file        = "${path.module}/data/rulesets.yaml"
  builtin_rulesets_raw = yamldecode(file(local.rulesets_file))

  # Inject variable-driven fields into the default_branch built-in ruleset
  # (bypass_actors, required_approving_review_count). Kept out of the YAML so
  # each org / repo can supply its own without forking the ruleset catalog.
  # Other built-ins (when added) pass through unchanged via the outer merge.
  # Assumes every rule in the default_branch ruleset has a pull_request block.
  builtin_rulesets = merge(local.builtin_rulesets_raw, {
    default_branch = merge(local.builtin_rulesets_raw["default_branch"], {
      bypass_actors = var.default_branch_ruleset_bypass_actors
      rules = [
        for rule in local.builtin_rulesets_raw["default_branch"].rules : merge(rule, {
          pull_request = merge(rule.pull_request, {
            require_last_push_approval      = var.default_branch_ruleset_require_last_push_approval
            required_approving_review_count = var.default_branch_ruleset_required_approving_review_count
          })
        })
      ]
    })
  })

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
