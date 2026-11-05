## Decision: Manage the DNS for every yo61 domain, along with the Cloudflare config that depends on it, as Terraform in the existing private `yo61/infrastructure` repo. The `yo61/dns` repo created earlier the same day is deleted.

## Context: `yo61/www-yo61-com` will serve www.yo61.com from Cloudflare Pages, which needs more than DNS records: a Pages project, a custom-domain binding, and probably email routing. `decisions/2026-11-05-yo61-dns-repo.md` created `yo61/dns` for the DNS alone. It never considered `yo61/infrastructure`, which already existed, and it misread its own precedent: `horopter-dev/infrastructure` is not a DNS repo but a Cloudflare Terraform root (`website.tf`, `email.tf`, `pages-verification.tf`, `docs.tf`, `workers/`). There, DNS sits beside the resources that depend on it.

## Alternatives considered:
- Keep `yo61/dns`. Rejected: the Pages project and email routing have no natural home in a repo named for DNS, so it would either grow past its name or need a second Cloudflare repo duplicating the provider, credentials and state setup.
- Add it to `yo61/homelab-infrastructure`. Rejected for the same reason as before: that repo is scoped to the homelab.

## Reasoning: One `infrastructure` repo per org matches `horopter-dev`, and `decisions/2026-10-09-yo61-dependency-update-remediation.md` already named `yo61/infrastructure` to match it. Its description began "starting with the Renovate workflow", so it was meant to grow. `yo61/dns` had no commits, so deleting it lost nothing.

## Trade-offs accepted: `yo61/infrastructure` now holds two unrelated kinds of content, a fleet-wide Renovate workflow and a Terraform root, as `horopter-dev/infrastructure` does. As a private repo on the free-plan org it has no rulesets or secret scanning (`decisions/2026-08-10-private-repos-manual-review-gate.md`). Every yo61 zone shares one Cloudflare credential and one state, so a bad apply can affect all of them.

## Supersedes: `decisions/2026-11-05-yo61-dns-repo.md`.
