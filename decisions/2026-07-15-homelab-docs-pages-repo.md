## Decision: Host homelab documentation in a new public repo `yo61/homelab-docs` with GitHub Pages (GitHub Actions source), instead of enabling Pages on the private `flux-homelab`.

## Context: Asked to enable GitHub Pages on `flux-homelab` with the source set to GitHub Actions. `flux-homelab` is `visibility: private` and `yo61` is a GitHub Organization on the `free` plan. GitHub Pages on private repos requires Team/Enterprise, so enabling it there would 4xx on apply (and a failed apply wedges the Stategraph transaction in `committing`).

## Alternatives considered:
- Make `flux-homelab` public — rejected: it holds Flux/k8s cluster config, not documentation; mixing docs into it is the wrong home.
- Write the `pages` block anyway and accept the apply failure until the org is upgraded — rejected: risks a wedged transaction for no immediate benefit.
- Upgrade the `yo61` org to Team/Enterprise to keep docs private — rejected: cost/overhead not warranted for public-facing homelab docs.

## Reasoning: A dedicated public `homelab-docs` repo makes Pages free, keeps documentation separated from cluster config, and needs no plan change. `build_type: workflow` (GitHub Actions source) requires no `source` branch, so it applies cleanly on an empty repo.

## Trade-offs accepted: Documentation lives in a second repo that must be kept in sync with the homelab; the site is public. Pages won't deploy until content + a Pages deploy workflow are pushed.

## Supersedes: none.
