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

# horopter and horopter-internal were transferred from yo61 to horopter-dev on
# GitHub out of band; github_repository takes its owner from the provider, so
# terraform cannot do the move itself. One block per repo carries all four of
# that repo's instances across the provider alias.
#
# `moved` is usable here precisely because the names did not change. It failed
# for the ycst migration because those repos were renamed as well as
# transferred, and moved cannot rewrite a resource ID — for github_repository
# the ID *is* the repo name, so refresh asked for the old name under the new
# owner and got 404. See decisions/2026-08-13-ycst-org-uk-migration.md.
#
# Delete these once applied — a spent moved block is a no-op.
moved {
  from = module.org_yo61.module.repo["horopter"]
  to   = module.org_horopter_dev.module.repo["horopter"]
}

moved {
  from = module.org_yo61.module.repo["horopter-internal"]
  to   = module.org_horopter_dev.module.repo["horopter-internal"]
}
