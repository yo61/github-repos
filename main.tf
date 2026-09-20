locals {
  # The repository Admin role. Applied to every ruleset in both orgs so a
  # maintainer can merge a pull request that does not meet the ruleset's
  # requirements. See decisions/2026-09-13-admin-override-all-rulesets.md.
  #
  # A bypass lets a maintainer merge by hand; it does not satisfy GitHub's
  # auto-merge, which ignores bypass actors. Keeping bot PRs flowing is the
  # job of the review count being 0, not of this list.
  admin_bypass_actors = [
    {
      actor_id    = 5
      actor_type  = "RepositoryRole"
      bypass_mode = "always"
    },
  ]
}

module "org_yo61" {
  source = "./modules/org"

  org = "yo61"

  additional_ruleset_bypass_actors = local.admin_bypass_actors

  # semantic-release-pusher, plus the admin role.
  default_branch_ruleset_bypass_actors = concat(
    [
      {
        actor_id    = 3654569
        actor_type  = "Integration"
        bypass_mode = "always"
      },
    ],
    local.admin_bypass_actors,
  )

  providers = {
    github = github.yo61
  }
}

module "org_ycst_org_uk" {
  source = "./modules/org"

  org = "ycst-org-uk"

  additional_ruleset_bypass_actors     = local.admin_bypass_actors
  default_branch_ruleset_bypass_actors = local.admin_bypass_actors

  providers = {
    github = github.ycst_org_uk
  }
}

module "org_horopter_dev" {
  source = "./modules/org"

  org = "horopter-dev"

  additional_ruleset_bypass_actors     = local.admin_bypass_actors
  default_branch_ruleset_bypass_actors = local.admin_bypass_actors

  providers = {
    github = github.horopter_dev
  }
}
