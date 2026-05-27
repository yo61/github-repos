# Secret scanning support in github-repo module — design

Date: 2026-05-27
Status: Draft, pending implementation plan

## Problem

`yo61/go-udap` has gained a security workflow (commit `5889946`: govulncheck +
grype with SARIF uploads to the Security tab) and an expanded Dependabot config
(commit `56e8d4c`: gomod, github-actions, npm). The Terraform configuration in
this repo does not yet reflect any of this: the corresponding repo-level
toggles (Dependabot alerts, secret scanning, secret-scanning push protection)
are all `disabled` on GitHub.

`vulnerability_alerts: true` was already added to `data/yo61/go-udap.yaml`
(prior turn in this session) — that wires the existing
`github_repository_vulnerability_alerts` resource and enables Dependabot
alerts. The remaining gap is secret scanning, which the `github-repo` module
does not currently expose at all. The provider supports it via the
`security_and_analysis` nested block on `github_repository`, but no variable,
no dynamic block, and no `lookup()` is wired through.

## Goals

In scope:

- Add a `security_and_analysis` variable on `modules/github-repo` covering all
  three sub-blocks supported by the `integrations/github` provider:
  `advanced_security`, `secret_scanning`, `secret_scanning_push_protection`.
- Render those settings via a `dynamic` block on the existing
  `github_repository.this` resource.
- Plumb the variable through `modules/org/main.tf` via `lookup()`.
- Opt `data/yo61/go-udap.yaml` into `secret_scanning: true` and
  `secret_scanning_push_protection: true`. Leave `advanced_security` unset —
  the GitHub API rejects it on public repos.
- Zero drift on the ~180 existing repo YAMLs that don't set the new key.

Out of scope:

- Opting any other repo into secret scanning. Bulk opt-in is a follow-up PR
  (likely scoped to all `visibility: public` repos), reviewed and applied
  separately.
- `secret_scanning_validity_checks` and `secret_scanning_non_provider_patterns`.
  These appear in the GitHub REST response but are not exposed by the
  `integrations/github` v6.x provider's `security_and_analysis` block; adding
  them requires waiting for provider support.
- Cross-field validation that depends on `var.visibility` or on enterprise-org
  state (e.g. "advanced_security on public is invalid"). The GitHub API
  surfaces these errors at apply time with clear messages.
- Changes to the existing `github_repository_vulnerability_alerts` wiring; it
  stays as a separate resource as the provider requires.

## Architecture

No new resources, no new modules. The change is contained to:

1. A new variable on the `github-repo` child module.
2. A new `dynamic "security_and_analysis"` block inside the existing
   `github_repository.this` resource in `modules/github-repo/main.tf`.
3. One extra `lookup()` line in `modules/org/main.tf` that passes the variable
   through from per-repo YAML.
4. Two extra lines in `data/yo61/go-udap.yaml`.

Data flow is unchanged from existing fields: `data/<org>/<repo>.yaml` →
`yamldecode()` in `modules/org/data.tf` → `lookup()` in
`modules/org/main.tf` → typed variable on `modules/github-repo` → resource
attribute.

## Component design

### Variable shape (modules/github-repo/variables.tf)

```hcl
variable "security_and_analysis" {
  description = <<-EOT
    GitHub security_and_analysis configuration. Defaults to null which leaves
    the attribute unmanaged so existing repos see no drift. Set any sub-field
    to opt in. advanced_security applies to private/internal repos in
    enterprise orgs; the GitHub API rejects it on public repos.
  EOT
  type = object({
    advanced_security               = optional(bool)
    secret_scanning                 = optional(bool)
    secret_scanning_push_protection = optional(bool)
  })
  default  = null
  nullable = true

  validation {
    condition = (
      var.security_and_analysis == null ? true : !(
        coalesce(var.security_and_analysis.secret_scanning_push_protection, false)
        && !coalesce(var.security_and_analysis.secret_scanning, false)
      )
    )
    error_message = "secret_scanning_push_protection requires secret_scanning to be enabled."
  }
}
```

Key choices:

- **All three sub-fields are `optional(bool)`.** `null` means "don't render
  that inner block; leave whatever GitHub has." `true`/`false` means explicit
  enable/disable. This lets a YAML opt into `secret_scanning` without
  committing to or against `advanced_security`.
- **Bool, not string.** The provider takes `"enabled"`/`"disabled"`; the
  conversion happens in the dynamic block. YAML stays idiomatic and consistent
  with `has_issues`, `vulnerability_alerts`, etc.
- **One local validation.** Push-protection-without-secret-scanning is the
  only constraint checkable without referencing other module variables or
  org-level state. Visibility and enterprise-license constraints are left to
  the GitHub API.

### Dynamic block (modules/github-repo/main.tf)

Added inside the existing `github_repository "this"` resource, between the
`template` dynamic block and the `lifecycle` block:

```hcl
dynamic "security_and_analysis" {
  for_each = var.security_and_analysis[*]
  content {
    dynamic "advanced_security" {
      for_each = var.security_and_analysis.advanced_security == null ? [] : [var.security_and_analysis.advanced_security]
      content {
        status = advanced_security.value ? "enabled" : "disabled"
      }
    }
    dynamic "secret_scanning" {
      for_each = var.security_and_analysis.secret_scanning == null ? [] : [var.security_and_analysis.secret_scanning]
      content {
        status = secret_scanning.value ? "enabled" : "disabled"
      }
    }
    dynamic "secret_scanning_push_protection" {
      for_each = var.security_and_analysis.secret_scanning_push_protection == null ? [] : [var.security_and_analysis.secret_scanning_push_protection]
      content {
        status = secret_scanning_push_protection.value ? "enabled" : "disabled"
      }
    }
  }
}
```

Two-layer null guards:

- **Outer** `for_each = var.security_and_analysis[*]` — splat-on-null returns
  `[]`, so when the variable is null the entire block is omitted from the
  resource. No drift for repos that don't opt in.
- **Inner** `for_each = field == null ? [] : [field]` — same trick per
  sub-field. An unset sub-field means "leave that one alone"; the provider
  treats unspecified sub-blocks as unmanaged.

Edge case (documented behaviour, not enforced): supplying
`security_and_analysis: {}` in YAML (empty object, not null) renders one
outer block with no inner sub-blocks. This sends an empty
`security_and_analysis {}` payload to the provider. Operators should omit the
key entirely or set it to null to leave the attribute unmanaged. Not
defensively guarded because the YAML shape is operator-controlled.

### Plumbing (modules/org/main.tf)

One new line, alphabetically placed between `pages` and
`squash_merge_commit_message`:

```hcl
security_and_analysis = lookup(each.value, "security_and_analysis", null)
```

### YAML opt-in (data/yo61/go-udap.yaml)

```yaml
security_and_analysis:
  secret_scanning: true
  secret_scanning_push_protection: true
```

Inserted alphabetically between `pages:` and `visibility:`. `advanced_security`
is omitted — go-udap is public, where the API rejects `enabled`.

## Plan diff (expected)

For go-udap specifically, after both this change and the prior-turn
`vulnerability_alerts: true` opt-in:

```
~ resource "github_repository" "this" {
    ~ security_and_analysis {
        ~ secret_scanning {
            ~ status = "disabled" -> "enabled"
          }
        ~ secret_scanning_push_protection {
            ~ status = "disabled" -> "enabled"
          }
      }
  }
+ resource "github_repository_vulnerability_alerts" "this"
```

For every other repo: no diff. The new variable defaults to null and the
dynamic block renders nothing when unset.

## Failure modes

- **Operator sets `secret_scanning_push_protection: true` without
  `secret_scanning: true`.** Caught at `terraform validate` / `plan` time by
  the variable's `validation` block with a clear error.
- **Operator sets `advanced_security: true` on a public repo.** GitHub API
  returns an error at apply time. Module does not pre-validate this because
  the constraint depends on `var.visibility` and on enterprise licensing the
  module cannot see.
- **Operator sets `secret_scanning: true` on a private repo in an org without
  advanced_security enabled at the org level.** GitHub API returns an error
  at apply time. Same reasoning.
- **Provider drift on existing repos.** Variable default is null → empty
  dynamic block → no `security_and_analysis` rendered → provider leaves the
  attribute as-is on GitHub. Verified by inspection of the dynamic block
  semantics; should be confirmed in the first plan run after the change
  lands.

## Testing

No automated tests (consistent with existing module — see the parent
`2026-05-22-multi-org-github-repos-design.md`, "Automated integration tests
against real GitHub" is out of scope).

Manual verification, in order:

1. After the variable + dynamic block + lookup land, run `stategraph tf plan`
   with no YAML change. Expected: no diff on any repo.
2. Add the `security_and_analysis` block to `data/yo61/go-udap.yaml`. Run
   plan. Expected: exactly the diff shown above on `github_repository.this`
   for go-udap, no diff elsewhere.
3. Apply. Verify via
   `gh api repos/yo61/go-udap --jq '.security_and_analysis'` that
   `secret_scanning.status` and `secret_scanning_push_protection.status` are
   both `"enabled"`.

## Module README

`modules/github-repo/README.md` contains a `terraform-docs`-generated block
(`<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->` between lines 260 and 337).
The pre-commit config (`.pre-commit-config.yaml`) runs the `terraform_docs`
hook from `antonbabenko/pre-commit-terraform`, so the new variable will be
picked up automatically on the next commit that touches the module.

## Open questions

None. Defaults, scope, and YAML shape were settled in brainstorm before this
spec was written:

- Scope: all three sub-blocks (`advanced_security`, `secret_scanning`,
  `secret_scanning_push_protection`).
- YAML shape: nested object under `security_and_analysis:` key.
- Default behaviour: null → unmanaged → zero drift. Opt in per repo,
  starting with go-udap only.
