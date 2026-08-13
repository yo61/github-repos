module "org_yo61" {
  source = "./modules/org"

  org = "yo61"

  default_branch_ruleset_bypass_actors = [
    {
      actor_id    = 3654569
      actor_type  = "Integration"
      bypass_mode = "always"
    },
  ]

  default_branch_ruleset_non_fork_bypass_actors = [
    {
      actor_id    = 5
      actor_type  = "RepositoryRole"
      bypass_mode = "always"
    },
  ]

  providers = {
    github = github.yo61
  }
}

module "org_ycst_org_uk" {
  source = "./modules/org"

  org = "ycst-org-uk"

  providers = {
    github = github.ycst_org_uk
  }
}
