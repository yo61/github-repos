## Decision: leave immutable releases outside Terraform, with no drift detection, until `integrations/github` supports them. `horopter-dev/record-action` keeps the setting it was given out of band on 2026-10-12 (`gh api -X PUT repos/horopter-dev/record-action/immutable-releases`); its data file declares nothing for it.

## Context: issue #125. record-action's release spec needs immutable releases (a GitHub Release exists only for `vX.Y.Z`; `v1` is a plain tag the release workflow moves). `modules/github-repo` has no input for the setting, and the provider offers none to build one on:

- `integrations/github` 6.13.0, both the locked version and the latest release on 2026-10-12, has no immutable-releases attribute on `github_repository` and no resource for it. `terraform providers schema -json` lists only `github_release`.
- GitHub exposes the setting on its own endpoint (`GET/PUT/DELETE /repos/{owner}/{repo}/immutable-releases`), not as a repository field, so upstream wants a separate resource for it.
- Upstream: integrations/terraform-provider-github#2746 (repository level) is open and still in triage. #3447 and #3574, both proposing a `github_repository_immutable_releases` resource, were closed by their authors without merging. The org-level resource (#3228, PR #3227) is also open.

## Alternatives considered:

- **`hashicorp/http` data source + a `check` block**, asserting a new `immutable_releases` input against the endpoint. It would warn on drift during `task plan`, but adds a provider and a token variable (`providers.tf` uses ambient auth, which `data "http"` cannot share), and still only checks, it does not enforce. Too much for one repo's setting.
- **A `scripts/` check run with `gh api`.** It lives outside the plan, so it only catches drift when someone remembers to run it, and running it in CI would need read credentials for all three orgs.
- **Declare `immutable_releases: true` in the data file anyway.** Rejected: nothing reads it, and `modules/org/main.tf` drops unknown keys without error, so the file would claim a setting Terraform neither manages nor checks.

## Reasoning: the setting is on one repo, and that repo was turned on deliberately. The only failure is someone disabling it in the UI, which is unlikely, and it would show up the next time a release tag is overwritten. That doesn't justify a new provider or a credentials path. Waiting costs little: when the provider ships a resource, adopting it is one module input plus an import.

## Trade-offs accepted:

- **No drift detection.** If immutable releases is switched off on record-action, nothing here will notice. Check it by hand with `gh api repos/horopter-dev/record-action/immutable-releases` (`"enabled": true`).
- **The data file is incomplete for this repo.** It carries a comment pointing here, so a reader of the file finds out.
- **Other repos that need the setting are turned on out of band the same way**, and each gets the same comment.

Revisit when #2746 (or a successor) ships in a provider release: add an `immutable_releases` module input (default `false`), declare it in record-action's data file, and import the live state.

## Supersedes: none.
