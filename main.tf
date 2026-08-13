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

# The repos were transferred and renamed on GitHub out of band; github_repository
# takes its owner from the provider, so terraform cannot do the move itself.
# One block per repo carries all four of that repo's instances across both the
# provider alias and the renamed for_each key, preserving the resource ID.
# Delete these once applied — a spent moved block is a no-op.
moved {
  from = module.org_yo61.module.repo["ycst-admin-docs"]
  to   = module.org_ycst_org_uk.module.repo["board-docs"]
}

moved {
  from = module.org_yo61.module.repo["ycst-website-testing"]
  to   = module.org_ycst_org_uk.module.repo["website-testing"]
}
