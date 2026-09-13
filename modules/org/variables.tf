variable "org" {
  description = "GitHub organisation slug. Must match the data/<org>/ directory name."
  type        = string
  nullable    = false
}

variable "additional_ruleset_bypass_actors" {
  description = "Org-wide default bypass actors for every ruleset a repo declares under `additional_rulesets`, applied to every repo. A ruleset that names its own `bypass_actors` in YAML keeps that list verbatim, so `bypass_actors: []` on one ruleset is the opt-out."
  type = list(object({
    actor_id    = number
    actor_type  = string
    bypass_mode = string
  }))
  default  = []
  nullable = false
}

variable "default_branch_ruleset_bypass_actors" {
  description = "Org-wide default for the default_branch ruleset's bypass actors, applied to every repo (forks included). Per-repo YAML can override."
  type = list(object({
    actor_id    = number
    actor_type  = string
    bypass_mode = string
  }))
  default  = []
  nullable = false
}

variable "default_branch_ruleset_dismiss_stale_reviews_on_push" {
  description = "Org-wide default for whether pushing to a PR branch dismisses existing approvals. Defaults to true. Per-repo YAML can override, for repos whose release automation pushes after review."
  type        = bool
  default     = true
  nullable    = false
}

variable "default_branch_ruleset_require_last_push_approval" {
  description = "Org-wide default for whether the most recent reviewable push must be approved by someone other than the pusher. Defaults to false so solo authors aren't blocked even when the pull_request rule is active. Per-repo YAML can override."
  type        = bool
  default     = false
  nullable    = false
}

variable "default_branch_ruleset_required_approving_review_count" {
  description = "Org-wide default for the number of approving reviews required on PRs targeting the default branch (when the default_branch ruleset is enabled). Per-repo YAML can override."
  type        = number
  default     = 0
  nullable    = false
}
