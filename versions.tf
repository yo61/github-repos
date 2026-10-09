terraform {
  # A constraint, not a pin: CI's TERRAFORM_VERSION and mise.toml pin the version.
  required_version = "~> 1.15"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}
