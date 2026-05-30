variable "additional_rulesets" {
  description = "User-supplied rulesets"
  type        = any
  default     = {}
  nullable    = false
}

variable "allow_auto_merge" {
  description = "Set to true to allow auto-merging pull requests on the repository."
  type        = bool
  default     = false
  nullable    = false
}

variable "allow_merge_commit" {
  description = "Set to false to disable merge commits on the repository."
  type        = bool
  default     = true
  nullable    = false
}

variable "allow_rebase_merge" {
  description = "Set to false to disable rebase merges on the repository."
  type        = bool
  default     = true
  nullable    = false
}

variable "allow_squash_merge" {
  description = "Set to false to disable squash merges on the repository."
  type        = bool
  default     = true
  nullable    = false
}

variable "allow_update_branch" {
  description = "Set to true to always suggest updating pull request branches."
  type        = bool
  default     = true
  nullable    = false
}

variable "apply_default_branch_protection" {
  description = "Set to true to apply legacy branch protection to the default branch. Defaults to false; rulesets are the preferred mechanism."
  type        = bool
  default     = false
  nullable    = false
}

variable "archived" {
  description = "Specifies if the repository should be archived. Defaults to false. NOTE Currently, the API does not support unarchiving."
  type        = bool
  default     = false
  nullable    = false
}

variable "auto_init" {
  description = "Set to true to produce an initial commit in the repository."
  type        = bool
  default     = false
  nullable    = false
}

variable "branch_protection_rules_override" {
  description = <<EOT
Override the default Branch protection configuration. Any configuration supplied here is merged on top of the default rules, defined in the module.

  object(
    {
      allows_deletions                = optional(bool, false)
      allows_force_pushes             = optional(bool, false)
      enforce_admins                  = optional(bool, true)
      force_push_bypassers            = optional(list(string), [])
      require_conversation_resolution = optional(bool, false)
      required_linear_history         = optional(bool, false)
      require_signed_commits          = optional(bool, true)
      required_pull_request_reviews = optional(
        object(
          {
            dismiss_stale_reviews           = optional(bool, true)
            dismissal_restrictions          = optional(list(string), [])
            pull_request_bypassers          = optional(list(string), [])
            require_code_owner_reviews      = optional(bool, false)
            require_last_push_approval      = optional(bool, false)
            required_approving_review_count = optional(number, 1)
            restrict_dismissals             = optional(bool, false)
          }
        ),
        null
      )
      required_status_checks = optional(
        object(
          {
            contexts = optional(list(string), [])
            strict   = optional(bool, false)
          }
        ),
        null
      )
      restrict_pushes = optional(
        object(
          {
            blocks_creations = optional(bool)
            push_allowances  = optional(list(string))
          }
        )
    )
  }
EOT
  type        = any
  default     = null
}

variable "builtin_ruleset_names" {
  description = "List of built-in ruleset names to be applied"
  type        = list(string)
  default     = ["default_branch"]
  nullable    = false
}

variable "collaborators" {
  description = "Define team and user permissions for the repository"
  type = object({
    teams = optional(list(
      object({
        permission = string
        slug       = string
      })
    ))
    users = optional(list(
      object({
        permission = string
        username   = string
      })
    ))
  })
}

variable "create_default_branch" {
  description = "Have terraform create the default branch resource. Defaults to false; the default branch on existing repos is left unmanaged unless explicitly opted in."
  type        = bool
  default     = false
  nullable    = false
}

variable "default_branch" {
  description = "The name of the default branch of the repository"
  nullable    = false
  type        = string
  default     = "main"
}

variable "default_branch_ruleset_bypass_actors" {
  description = "Actors permitted to bypass the default_branch built-in ruleset. Empty means no bypass."
  type = list(object({
    actor_id    = number
    actor_type  = string
    bypass_mode = string
  }))
  default  = []
  nullable = false
}

variable "default_branch_ruleset_require_last_push_approval" {
  description = "Whether the most recent reviewable push must be approved by someone other than the pusher. With required_approving_review_count = 0 and this = true, solo authors are still blocked. Defaults to false."
  type        = bool
  default     = false
  nullable    = false
}

variable "default_branch_ruleset_required_approving_review_count" {
  description = "Number of approving reviews required on PRs targeting the default branch when the default_branch built-in ruleset is enabled."
  type        = number
  default     = 0
  nullable    = false
}

variable "delete_branch_on_merge" {
  description = "Automatically delete head branch after a pull request is merged."
  type        = bool
  default     = true
  nullable    = false
}

variable "dependabot_security_updates" {
  description = <<-EOT
    Whether Dependabot opens PRs that fix vulnerable dependencies automatically.
    Set true/false to manage explicitly; leave null (the default) to leave the
    attribute unmanaged so existing repos see no drift. Enabling requires
    vulnerability_alerts to be enabled — the GitHub API rejects this otherwise,
    and the module sets a depends_on to enforce ordering on apply.
  EOT
  type        = bool
  default     = null
  nullable    = true
}

variable "description" {
  description = "A description of the repository."
  type        = string
  default     = null
}

variable "has_discussions" {
  description = "Set to true to enable GitHub Discussions on the repository. Defaults to false."
  type        = bool
  default     = false
  nullable    = false
}

variable "has_issues" {
  description = "Set to true to enable the GitHub Issues features on the repository."
  type        = bool
  default     = false
  nullable    = false
}

variable "has_projects" {
  description = "Set to true to enable the GitHub Projects features on the repository. Per the GitHub documentation when in an organization that has disabled repository projects it will default to false and will otherwise default to true. If you specify true when it has been disabled it will return an error."
  type        = bool
  default     = false
  nullable    = false
}

variable "has_wiki" {
  description = "Set to true to enable the GitHub Wiki features on the repository."
  type        = bool
  default     = false
  nullable    = false
}

variable "homepage_url" {
  description = "URL of a page describing the project."
  type        = string
  default     = null
}

variable "is_template" {
  description = "Set to true to tell GitHub that this is a template repository."
  type        = bool
  default     = false
  nullable    = false
}

variable "merge_commit_message" {
  description = "Can be PR_BODY, PR_TITLE, or BLANK for a default merge commit message. Applicable only if allow_merge_commit is true."
  type        = string
  default     = "PR_TITLE"
  validation {
    condition     = var.merge_commit_message == null ? true : contains(["PR_BODY", "PR_TITLE", "BLANK"], var.merge_commit_message)
    error_message = "merge_commit_message must be one of PR_BODY, PR_TITLE or BLANK."
  }

}

variable "merge_commit_title" {
  description = "Can be PR_TITLE or MERGE_MESSAGE for a default merge commit title. Applicable only if allow_merge_commit is true."
  type        = string
  default     = "MERGE_MESSAGE"
  validation {
    condition     = var.merge_commit_title == null ? true : contains(["PR_TITLE", "MERGE_MESSAGE"], var.merge_commit_title)
    error_message = "merge_commit_title must be one of PR_TITLE or MERGE_MESSAGE."
  }
}

variable "name" {
  description = "The name of the repository."
  type        = string
}

variable "pages" {
  description = "The repository's GitHub Pages configuration."
  type = object({
    build_type = string
    cname      = optional(string)
    source = optional(object({
      branch = string
      path   = string
    }))
  })
  default = null

  validation {
    condition = (
      var.pages == null ? true : contains(["legacy", "workflow"], var.pages.build_type)
    )

    error_message = "The build_type must be either 'legacy' or 'workflow'."
  }

  validation {
    condition = (
      var.pages == null ? true : (
        var.pages.build_type == "legacy" ? var.pages.source != null : true
      )
    )
    error_message = "source must be supplied for build_type 'legacy'"
  }
}

variable "security_and_analysis" {
  description = <<-EOT
    GitHub security_and_analysis configuration. Defaults to null which leaves
    the attribute unmanaged so existing repos see no drift. Set any sub-field
    to opt in. advanced_security applies to private/internal repos in
    enterprise orgs; the GitHub API rejects it on public repos.
  EOT
  type = object({
    advanced_security               = optional(bool)
    secret_scanning                 = optional(bool)
    secret_scanning_push_protection = optional(bool)
  })
  default  = null
  nullable = true

  validation {
    condition = (
      var.security_and_analysis == null ? true : !(
        coalesce(var.security_and_analysis.secret_scanning_push_protection, false)
        && !coalesce(var.security_and_analysis.secret_scanning, false)
      )
    )
    error_message = "secret_scanning_push_protection requires secret_scanning to be enabled."
  }
}

variable "squash_merge_commit_message" {
  description = "Can be PR_BODY, COMMIT_MESSAGES, or BLANK for a default squash merge commit message. Applicable only if allow_squash_merge is true."
  type        = string
  default     = "COMMIT_MESSAGES"
  validation {
    condition     = var.squash_merge_commit_message == null ? true : contains(["PR_BODY", "COMMIT_MESSAGES", "BLANK"], var.squash_merge_commit_message)
    error_message = "squash_merge_commit_message must be one of PR_BODY, COMMIT_MESSAGES or BLANK."
  }
}

variable "squash_merge_commit_title" {
  description = "Can be PR_TITLE or COMMIT_OR_PR_TITLE for a default squash merge commit title. Applicable only if allow_squash_merge is true."
  type        = string
  default     = "COMMIT_OR_PR_TITLE"
  validation {
    condition     = var.squash_merge_commit_title == null ? true : contains(["PR_TITLE", "COMMIT_OR_PR_TITLE"], var.squash_merge_commit_title)
    error_message = "squash_merge_commit_title must be one of PR_TITLE or COMMIT_OR_PR_TITLE."
  }
}

variable "team_ids" {
  description = "A map of github team ids, indexed on team slug"
  type        = map(string)
  default     = {}
}

variable "template" {
  description = "Use a template repository to create this resource."
  type = object({
    include_all_branches = optional(bool, false)
    owner                = string
    repository           = string
  })
  default = null
}

variable "visibility" {
  description = "Can be public or private. If your organization is associated with an enterprise account using GitHub Enterprise Cloud or GitHub Enterprise Server 2.20+, visibility can also be internal. The visibility parameter overrides the private parameter."
  type        = string
  default     = "private"
  nullable    = false
  validation {
    condition     = contains(["public", "private", "internal"], var.visibility)
    error_message = "visibility must be one of public, private, internal"
  }
}

variable "vulnerability_alerts" {
  description = <<-EOT
    Whether GitHub security alerts for vulnerable dependencies are enabled.
    Set true/false to manage explicitly; leave null (the default) to leave the
    attribute unmanaged so existing repos see no drift. Enabling requires
    alerts to be enabled at the owner level. Wired to the standalone
    github_repository_vulnerability_alerts resource.
  EOT
  type        = bool
  default     = null
  nullable    = true
}
