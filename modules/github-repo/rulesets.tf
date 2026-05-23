resource "github_repository_ruleset" "this" {
  for_each = local.rulesets

  enforcement = each.value["enforcement"]
  name        = each.value["name"]
  repository  = github_repository.this.name
  target      = each.value["target"]

  dynamic "conditions" {
    for_each = toset(lookup(each.value, "conditions", []))
    content {
      ref_name {
        exclude = conditions.value["ref_name"]["exclude"]
        include = conditions.value["ref_name"]["include"]
      }
    }
  }

  dynamic "bypass_actors" {
    for_each = toset(lookup(each.value, "bypass_actors", []))
    content {
      actor_id    = bypass_actors.value["actor_id"]
      actor_type  = bypass_actors.value["actor_type"]
      bypass_mode = bypass_actors.value["bypass_mode"]
    }
  }

  dynamic "rules" {
    for_each = each.value["rules"]
    content {
      creation                      = rules.value["creation"]
      deletion                      = rules.value["deletion"]
      non_fast_forward              = rules.value["non_fast_forward"]
      required_signatures           = rules.value["required_signatures"]
      update                        = rules.value["update"]
      update_allows_fetch_and_merge = rules.value["update_allows_fetch_and_merge"]

      dynamic "pull_request" {
        for_each = lookup(rules.value, "pull_request", null)[*]
        content {
          allowed_merge_methods             = lookup(pull_request.value, "allowed_merge_methods", null)
          dismiss_stale_reviews_on_push     = lookup(pull_request.value, "dismiss_stale_reviews_on_push", null)
          require_code_owner_review         = lookup(pull_request.value, "require_code_owner_review", null)
          require_last_push_approval        = lookup(pull_request.value, "require_last_push_approval", null)
          required_approving_review_count   = lookup(pull_request.value, "required_approving_review_count", null)
          required_review_thread_resolution = lookup(pull_request.value, "required_review_thread_resolution", null)
        }
      }

      dynamic "required_status_checks" {
        for_each = lookup(rules.value, "required_status_checks", null)[*]
        content {
          do_not_enforce_on_create             = lookup(required_status_checks.value, "do_not_enforce_on_create", null)
          strict_required_status_checks_policy = lookup(required_status_checks.value, "strict_required_status_checks_policy", null)

          dynamic "required_check" {
            for_each = required_status_checks.value["required_check"]
            content {
              context        = required_check.value["context"]
              integration_id = lookup(required_check.value, "integration_id", null)
            }
          }
        }
      }
    }
  }
}
