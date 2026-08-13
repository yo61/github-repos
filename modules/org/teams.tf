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
# a member added through the GitHub UI is removed on the next apply. Role is
# left at the provider default (`member`); org owners already administer their
# own teams.
resource "github_team_members" "this" {
  for_each = local.teams

  team_id = github_team.this[each.key].id

  dynamic "members" {
    for_each = toset(lookup(each.value, "members", []))
    content {
      username = members.value
    }
  }
}
