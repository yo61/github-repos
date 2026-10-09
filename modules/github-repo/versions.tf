terraform {
  # A constraint, not a pin: the root module pins the version.
  required_version = ">= 1.12.1"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
