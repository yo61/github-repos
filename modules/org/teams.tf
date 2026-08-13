# Org teams from data/<org>/_teams.yaml, keyed by slug. The map key is the team
# name; GitHub derives the slug from it, so keys must be lowercase and
# hyphenated for the two to agree. Repo YAML references teams by that slug.
resource "github_team" "this" {
  for_each = local.teams

  name        = each.key
  description = lookup(each.value, "description", null)

  # Closed teams are visible to org members, which suits a team whose purpose
  # is granting access. The provider default is `secret`.
  privacy = lookup(each.value, "privacy", "closed")
}

# Authoritative, matching this repo's "the YAML is the source of truth" posture:
# a member added through the GitHub UI is removed on the next apply.
#
# `maintainers` and `members` are separate lists rather than one list carrying a
# role, so the common case stays a plain list of usernames. Both are needed:
# GitHub makes whoever creates a team its maintainer, so a team whose YAML lists
# only `members` shows a standing diff demoting its creator. Observed on
# ycst-org-uk/admins, 2026-08-13.
#
# team_slug rather than team_id: the provider deprecated team_id and will make
# it computed-only. Referencing github_team.this keeps the dependency edge that
# orders team creation before any repo grant either way.
resource "github_team_members" "this" {
  for_each = local.teams

  team_slug = github_team.this[each.key].slug

  dynamic "members" {
    for_each = toset(coalesce(lookup(each.value, "maintainers", []), []))
    content {
      username = members.value
      role     = "maintainer"
    }
  }

  dynamic "members" {
    for_each = toset(coalesce(lookup(each.value, "members", []), []))
    content {
      username = members.value
      role     = "member"
    }
  }
}
