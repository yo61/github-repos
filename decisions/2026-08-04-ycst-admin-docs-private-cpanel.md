## Decision: Manage `yo61/ycst-admin-docs` as a **private** repo with no rulesets, no Pages, and no auto-merge, deploying to Krystal cPanel over rsync rather than to GitHub Pages.

## Context: York City Supporters Trust Board documentation needs a home. The
site already exists locally as a Fumadocs (Next.js) static export with a PHP
gatekeeper (`deploy/gate/index.php`) that authenticates against the WordPress
install on `www.ycst.org.uk` and streams files from a directory outside the web
root. Access control therefore lives on the cPanel host, not in GitHub. The
brief was "similar to `homelab-docs`", but `homelab-docs` is public, publishes
via GitHub Pages, and carries the full Tier-1 + Tier-2 gate from
`decisions/2026-08-03-ci-baseline-two-tier-policy.md`. `yo61` is an org on the
free plan, where repository rulesets (403), secret scanning (422), and Pages
are all paywalled on private repos.

## Alternatives considered:
- **Public repo with the full `homelab-docs` gate, secrets kept out of the tree.**
  Rejected: the content is Board-internal. The PHP gate protects the *deployed*
  site, not the source; a public repo would expose the documentation itself.
- **Private repo that declares the rulesets anyway, accepting apply failures
  until the org is upgraded.** Rejected for the same reason as
  `decisions/2026-07-15-homelab-docs-pages-repo.md`: the GitHub API enforces
  licensing at apply time, so it plans clean and then 4xx's, risking a wedged
  transaction for no benefit.
- **Upgrade `yo61` to Team to keep both privacy and the gate.** Rejected: the
  cost is not warranted for one Board docs site with a small maintainer set.
  (Amended 2026-08-04: `PlanetSeth` added as a second admin. The rejection
  stands — a free org takes unlimited collaborators on private repos, whereas
  Team bills per seat, so a second maintainer raises the upgrade cost.)
- **Deploy to GitHub Pages and gate at the edge.** Rejected: Pages on a private
  repo is paywalled, and the existing WordPress role check (`view_admin_docs`
  on the Trust Board role) already provides the authorisation model. Moving it
  to GitHub would mean maintaining a second identity system.

## Reasoning: Deployment already terminates on the same cPanel account that
hosts WordPress, which is what makes the gatekeeper simple — so the hosting
choice drives the repo shape rather than the reverse. Given private visibility
on a free-tier org, `builtin_ruleset_names: []` is not a preference but the
only configuration that applies cleanly. With no ruleset to gate on,
`allow_auto_merge` would have nothing to wait for, so it stays at its default
of `false`. The repo keeps the two protections that *are* free on private
repos: `vulnerability_alerts` and `dependabot_security_updates`.

## Trade-offs accepted:
- **No enforced CI gate.** The `build`/`types:check` workflow runs on PRs but
  cannot be made a required check, so a red build does not mechanically block a
  merge. This is a discipline gate, not a technical one, until the org is
  upgraded.
- **No secret scanning** on a repo whose deploy path uses SSH credentials. The
  repo's own `gitleaks` and `detect-private-key` prek hooks are the
  compensating control, running pre-commit rather than post-push.
- **Deploy secrets are configured out-of-band** (`SSH_PRIVATE_KEY`,
  `SSH_KNOWN_HOSTS`, `SSH_HOST`, `SSH_USER`, `SSH_PORT`, `DEPLOY_PATH`) and are
  not managed by Terraform, so they are invisible to this repo's state.
- **`visibility: private` restates the module default**, which
  `quality/criteria.md` marks as blocking. Kept deliberately: it is the fact the
  entire access-control design rests on, and both sibling private files
  (`flux-homelab`, `ycst-website-testing`) state it too.
- **One-time push to `main`** to establish the default branch on the empty repo,
  explicitly authorised, since there is no branch to open a PR against until a
  first commit exists.

## Supersedes: none. Sits alongside
`decisions/2026-07-15-homelab-docs-pages-repo.md`, which reached the opposite
conclusion (public + Pages) from the same free-tier constraint, because that
content was public-facing and this content is not.

## Update 2026-08-13

The repo moved to `ycst-org-uk/board-docs`; admin is now granted through the
`admins` team rather than a named collaborator. The site it documents was
renamed too, from `admin.ycst.org.uk` to `board.ycst.org.uk` — the old host has
no DNS record, so `homepage_url` was corrected to match. The private-visibility reasoning
here is unchanged. See `decisions/2026-08-13-ycst-org-uk-migration.md`.
