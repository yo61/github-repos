# Temporary: re-adopts the two repos transferred from yo61 to ycst-org-uk on
# 2026-08-13. Delete once applied.
#
# `moved` blocks were the intended mechanism and half worked: they rebound each
# resource to the ycst_org_uk provider and the renamed for_each key, exactly as
# the migration design's experiment predicted. What they cannot do is rewrite a
# resource ID, and for github_repository the ID *is* the repo name. State held
# `ycst-admin-docs`, so refresh asked GitHub for ycst-org-uk/ycst-admin-docs and
# got 404 — the rename redirect is keyed on the original owner/name pair
# (yo61/ycst-admin-docs), not on the old name under the new owner. Terraform
# read the 404 as "resource is gone" and planned to create it.
#
# The stale entries were dropped with `terraform state rm` (GitHub untouched);
# these blocks adopt the same objects at their new addresses under their new
# names. `removed` blocks cannot do the dropping — they reject instance keys.

import {
  to = module.org_ycst_org_uk.module.repo["board-docs"].github_repository.this
  id = "board-docs"
}

import {
  to = module.org_ycst_org_uk.module.repo["board-docs"].github_repository_collaborators.this
  id = "board-docs"
}

import {
  to = module.org_ycst_org_uk.module.repo["board-docs"].github_repository_vulnerability_alerts.this["this"]
  id = "board-docs"
}

import {
  to = module.org_ycst_org_uk.module.repo["board-docs"].github_repository_dependabot_security_updates.this["this"]
  id = "board-docs"
}

import {
  to = module.org_ycst_org_uk.module.repo["website-testing"].github_repository.this
  id = "website-testing"
}

import {
  to = module.org_ycst_org_uk.module.repo["website-testing"].github_repository_collaborators.this
  id = "website-testing"
}

import {
  to = module.org_ycst_org_uk.module.repo["website-testing"].github_repository_vulnerability_alerts.this["this"]
  id = "website-testing"
}

import {
  to = module.org_ycst_org_uk.module.repo["website-testing"].github_repository_dependabot_security_updates.this["this"]
  id = "website-testing"
}
