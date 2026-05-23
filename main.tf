module "org_yo61" {
  source = "./modules/org"

  org = "yo61"

  providers = {
    github = github.yo61
  }
}
