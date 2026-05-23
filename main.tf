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

  providers = {
    github = github.yo61
  }
}
