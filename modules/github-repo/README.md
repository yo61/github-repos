# Github Repository Module

This module allows you to create a github repository with opinionated settings.
It creates a default branch, and configures collaborators (teams/users).

The aim is to create a Github repository with the minimum of user
configuration.

## Usage

Create a private repository named "my-repo" and give push access to the
"engineers" team:

```hcl
module "my_repo" {
  source  = "./repo"
  version = "~> 1.0"

  name = "my-repo"

  collaborators = {
    teams = [
      {
        permission = "push"
        slug       = "engineers"
      }
    ]
  }
}
```

Create a public repository named "example02", with discussions, issues, and a
wiki, plus delete head branch when a PR is merged and always suggest updating
pull request branches:

```hcl
module "my_repo" {
  source  = "./repo"
  version = "~> 1.0"

  name = "example02"
  description = "Further example repository"
  visibility  = "public"

  allow_update_branch    = true
  delete_branch_on_merge = true

  has_discussions = true
  has_issues      = true
  has_wiki        = true

  collaborators = {
    teams = [
      {
        permission = "push"
        slug       = "engineers"
      }
    ]
  }
}
```

### Branch Protection / Rulesets

This module offers two ways to implement default branch protection.

1. "Classic" branch protection rule
1. Rulesets

#### Classic branch protection rule

With no additional configuration, the module will create a "classic" branch
protection rule on the default branch, usually `main`.

This can be disabled by passing `apply_default_branch_protection = false` to the
module.

#### Rulesets

Rulesets can be applied in two ways:

1. Specifying a list of built-in ruleset IDs in the `builtin_ruleset_names`
   parameter.
   The built-in rulesets are defined in `data/rulesets.yaml` The ruleset ID is
   the top-level key.
   Currently, the following rulesets are available:

   - `default_branch`: Applies branch protection rules to the default branch

1. Pass in custom rulesets in the `additional_rulesets` parameter.
   Create the rulesets by defining them in a YAML file, using the same format as
   the built-in rulesets, and loading to a local var with `yamldecode`

   ```hcl
   rulesets_file    = join("/", [path.module, "data/new_rulesets.yaml"])
   additional_rulesets = yamldecode(file(local.rulesets_file))
   ```

#### Required Status Checks

Rulesets support `required_status_checks` to enforce that specific CI checks
must pass before merging. Add a `required_status_checks` block inside `rules`
with one or more `required_check` entries.

Example YAML ruleset with required status checks:

```yaml
ci_checks:
  enforcement: active
  name: CI Checks
  target: branch
  conditions:
  - ref_name:
      exclude: []
      include:
      - ~DEFAULT_BRANCH
  rules:
  - creation: false
    deletion: false
    non_fast_forward: true
    required_signatures: false
    update: false
    update_allows_fetch_and_merge: false
    required_status_checks:
      strict_required_status_checks_policy: true
      do_not_enforce_on_create: false
      required_check:
      - context: "ci/build"
      - context: "ci/test"
      - context: "ci/lint"
        integration_id: 12345
```

- **`required_check`** (required): List of status check contexts that must pass.
  Each entry requires a `context` (string) and accepts an optional
  `integration_id` (number) to pin the check to a specific app.
- **`strict_required_status_checks_policy`** (optional, default `false`): When
  `true`, pull requests must be tested with the latest base branch code.
- **`do_not_enforce_on_create`** (optional, default `false`): When `true`,
  newly created branches are exempt from this rule.

### Linear Autolinking

GitHub makes issue auto-linking available only at the repository level, not
the organization level.  We probably want the exact same set of team
identifiers autolinked across any participating repo.

So the model we expect is "if the identifier is present, we control it, and
can add/delete as needed; if not present, we don't touch it".  Thus in the
`github-manage` repo, we expect that setting `linear_autolink_enable` to false
for a repo will remove the autolinks, but removing that item entirely will not
touch the autolinks at all, dropping from state.

In _this_ repo, we just accept the set of autolinks to enable, thus the manage
repo can support multiple ticket systems and we don't need to care.

It's possible that leaving the autolinks behind will require a `terraform
state rm` because we can't truly abandon state.


## Known Issues

There is a bug in the github provider, introduced in v6.4.0 by
[this change](https://github.com/integrations/terraform-provider-github/pull/2420)
that makes the teams permissions flap if they are set using team slug rather
than team id.

One workaround is to convert all team slugs to team ids either using a
github_team data source, or directly from the github_team resource if managing
the teams in the same module. This has the added benefit of speeding things up
as terraform can avoid performing an additional Github API call to get the team
id for each repo.

Something like this will do the trick:

```hcl
locals {
  # load the team data from the local config file
  team_file = join("/", [path.module, "data/teams.yaml"])
  team_data = yamldecode(file(local.team_file))
}

locals {
  # load the repo data from the local config files
  repo_files    = fileset(path.module, "data/repositories/*.yaml")
  raw_repo_data = [for f in local.repo_files : yamldecode(file(f))]

  # Process the repo data, converting github team slugs into team ids
  repo_data = [
    for repo in local.raw_repo_data : {
      for k, v in repo : k =>
      k == "collaborators" ?
      {
        for k2, v2 in v : k2 =>
        k2 == "teams" ? [
          for block in v2 : {
            for k3, v3 in block : k3 =>
            k3 == "slug" ? github_team.this[v3].id : v3
          }
        ]
        : v2
      }
      : v
    }
  ]
}

# create all github teams defined in the local config file
resource "github_team" "this" {
  for_each = { for team in local.team_data : team.slug => team }

  name           = each.value.name
  description    = can(each.value.description) ? each.value.description : null
  privacy        = can(each.value.privacy) ? each.value.privacy : null
  parent_team_id = can(each.value.parent_team_id) ? each.value.parent_team_id : null
}
```

Pass the repo data to the module like this:

```hcl
module "repo" {
  source = "./modules/github-repo"

  for_each = { for repo in local.repo_data : repo.name => repo }

  allow_auto_merge                 = can(each.value.allow_auto_merge) ? each.value.allow_auto_merge : null
  allow_merge_commit               = can(each.value.allow_merge_commit) ? each.value.allow_merge_commit : null
  allow_rebase_merge               = can(each.value.allow_rebase_merge) ? each.value.allow_rebase_merge : null
  allow_squash_merge               = can(each.value.allow_squash_merge) ? each.value.allow_squash_merge : null
  allow_update_branch              = can(each.value.allow_update_branch) ? each.value.allow_update_branch : null
  apply_default_branch_protection  = can(each.value.apply_default_branch_protection) ? each.value.apply_default_branch_protection : null
  archived                         = can(each.value.archived) ? each.value.archived : null
  auto_init                        = can(each.value.auto_init) ? each.value.auto_init : null
  autolinks                        = can(each.value.linear_autolink_enable) ? (each.value.linear_autolink_enable ? local.linear_autolinks : []) : null
  branch_protection_rules_override = can(each.value.branch_protection_rules_override) ? each.value.branch_protection_rules_override : null
  collaborators                    = can(each.value.collaborators) ? each.value.collaborators : null
  create_default_branch            = can(each.value.create_default_branch) ? each.value.create_default_branch : true
  default_branch                   = can(each.value.default_branch) ? each.value.default_branch : null
  delete_branch_on_merge           = can(each.value.delete_branch_on_merge) ? each.value.delete_branch_on_merge : null
  description                      = can(each.value.description) ? each.value.description : null
  has_discussions                  = can(each.value.has_discussions) ? each.value.has_discussions : null
  has_issues                       = can(each.value.has_issues) ? each.value.has_issues : null
  has_projects                     = can(each.value.has_projects) ? each.value.has_projects : null
  has_wiki                         = can(each.value.has_wiki) ? each.value.has_wiki : null
  homepage_url                     = can(each.value.homepage_url) ? each.value.homepage_url : null
  is_template                      = can(each.value.is_template) ? each.value.is_template : null
  merge_commit_message             = can(each.value.merge_commit_message) ? each.value.merge_commit_message : null
  merge_commit_title               = can(each.value.merge_commit_title) ? each.value.merge_commit_title : null
  name                             = can(each.value.name) ? each.value.name : null
  pages                            = can(each.value.pages) ? each.value.pages : null
  squash_merge_commit_message      = can(each.value.squash_merge_commit_message) ? each.value.squash_merge_commit_message : null
  squash_merge_commit_title        = can(each.value.squash_merge_commit_title) ? each.value.squash_merge_commit_title : null
  template                         = can(each.value.template) ? each.value.template : null
  visibility                       = can(each.value.visibility) ? each.value.visibility : null
  vulnerability_alerts             = can(each.value.vulnerability_alerts) ? each.value.vulnerability_alerts : null
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.1 |
| <a name="requirement_github"></a> [github](#requirement\_github) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_github"></a> [github](#provider\_github) | 6.12.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [github_branch.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch) | resource |
| [github_branch_default.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_default) | resource |
| [github_branch_protection.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_protection) | resource |
| [github_repository.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) | resource |
| [github_repository_collaborators.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_collaborators) | resource |
| [github_repository_dependabot_security_updates.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_dependabot_security_updates) | resource |
| [github_repository_pages.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_pages) | resource |
| [github_repository_ruleset.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset) | resource |
| [github_repository_vulnerability_alerts.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_vulnerability_alerts) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_rulesets"></a> [additional\_rulesets](#input\_additional\_rulesets) | User-supplied rulesets | `any` | `{}` | no |
| <a name="input_allow_auto_merge"></a> [allow\_auto\_merge](#input\_allow\_auto\_merge) | Set to true to allow auto-merging pull requests on the repository. | `bool` | `false` | no |
| <a name="input_allow_merge_commit"></a> [allow\_merge\_commit](#input\_allow\_merge\_commit) | Set to false to disable merge commits on the repository. | `bool` | `true` | no |
| <a name="input_allow_rebase_merge"></a> [allow\_rebase\_merge](#input\_allow\_rebase\_merge) | Set to false to disable rebase merges on the repository. | `bool` | `true` | no |
| <a name="input_allow_squash_merge"></a> [allow\_squash\_merge](#input\_allow\_squash\_merge) | Set to false to disable squash merges on the repository. | `bool` | `true` | no |
| <a name="input_allow_update_branch"></a> [allow\_update\_branch](#input\_allow\_update\_branch) | Set to true to always suggest updating pull request branches. | `bool` | `true` | no |
| <a name="input_apply_default_branch_protection"></a> [apply\_default\_branch\_protection](#input\_apply\_default\_branch\_protection) | Set to true to apply legacy branch protection to the default branch. Defaults to false; rulesets are the preferred mechanism. | `bool` | `false` | no |
| <a name="input_archived"></a> [archived](#input\_archived) | Specifies if the repository should be archived. Defaults to false. NOTE Currently, the API does not support unarchiving. | `bool` | `false` | no |
| <a name="input_auto_init"></a> [auto\_init](#input\_auto\_init) | Set to true to produce an initial commit in the repository. | `bool` | `false` | no |
| <a name="input_branch_protection_rules_override"></a> [branch\_protection\_rules\_override](#input\_branch\_protection\_rules\_override) | Override the default Branch protection configuration. Any configuration supplied here is merged on top of the default rules, defined in the module.<br/><br/>  object(<br/>    {<br/>      allows\_deletions                = optional(bool, false)<br/>      allows\_force\_pushes             = optional(bool, false)<br/>      enforce\_admins                  = optional(bool, true)<br/>      force\_push\_bypassers            = optional(list(string), [])<br/>      require\_conversation\_resolution = optional(bool, false)<br/>      required\_linear\_history         = optional(bool, false)<br/>      require\_signed\_commits          = optional(bool, true)<br/>      required\_pull\_request\_reviews = optional(<br/>        object(<br/>          {<br/>            dismiss\_stale\_reviews           = optional(bool, true)<br/>            dismissal\_restrictions          = optional(list(string), [])<br/>            pull\_request\_bypassers          = optional(list(string), [])<br/>            require\_code\_owner\_reviews      = optional(bool, false)<br/>            require\_last\_push\_approval      = optional(bool, false)<br/>            required\_approving\_review\_count = optional(number, 1)<br/>            restrict\_dismissals             = optional(bool, false)<br/>          }<br/>        ),<br/>        null<br/>      )<br/>      required\_status\_checks = optional(<br/>        object(<br/>          {<br/>            contexts = optional(list(string), [])<br/>            strict   = optional(bool, false)<br/>          }<br/>        ),<br/>        null<br/>      )<br/>      restrict\_pushes = optional(<br/>        object(<br/>          {<br/>            blocks\_creations = optional(bool)<br/>            push\_allowances  = optional(list(string))<br/>          }<br/>        )<br/>    )<br/>  } | `any` | `null` | no |
| <a name="input_builtin_ruleset_names"></a> [builtin\_ruleset\_names](#input\_builtin\_ruleset\_names) | Built-in ruleset names to apply. Repository rulesets are free on public<br/>repos but require GitHub Pro / Team / Enterprise on private repos<br/>(the GitHub API returns 403 otherwise). Set to [] on free-tier private<br/>repos to skip ruleset creation. | `list(string)` | <pre>[<br/>  "default_branch"<br/>]</pre> | no |
| <a name="input_collaborators"></a> [collaborators](#input\_collaborators) | Define team and user permissions for the repository | <pre>object({<br/>    teams = optional(list(<br/>      object({<br/>        permission = string<br/>        slug       = string<br/>      })<br/>    ))<br/>    users = optional(list(<br/>      object({<br/>        permission = string<br/>        username   = string<br/>      })<br/>    ))<br/>  })</pre> | n/a | yes |
| <a name="input_create_default_branch"></a> [create\_default\_branch](#input\_create\_default\_branch) | Have terraform create the default branch resource. Defaults to false; the default branch on existing repos is left unmanaged unless explicitly opted in. | `bool` | `false` | no |
| <a name="input_default_branch"></a> [default\_branch](#input\_default\_branch) | The name of the default branch of the repository | `string` | `"main"` | no |
| <a name="input_default_branch_ruleset_bypass_actors"></a> [default\_branch\_ruleset\_bypass\_actors](#input\_default\_branch\_ruleset\_bypass\_actors) | Actors permitted to bypass the default\_branch built-in ruleset. Empty means no bypass. | <pre>list(object({<br/>    actor_id    = number<br/>    actor_type  = string<br/>    bypass_mode = string<br/>  }))</pre> | `[]` | no |
| <a name="input_default_branch_ruleset_require_last_push_approval"></a> [default\_branch\_ruleset\_require\_last\_push\_approval](#input\_default\_branch\_ruleset\_require\_last\_push\_approval) | Whether the most recent reviewable push must be approved by someone other than the pusher. With required\_approving\_review\_count = 0 and this = true, solo authors are still blocked. Defaults to false. | `bool` | `false` | no |
| <a name="input_default_branch_ruleset_required_approving_review_count"></a> [default\_branch\_ruleset\_required\_approving\_review\_count](#input\_default\_branch\_ruleset\_required\_approving\_review\_count) | Number of approving reviews required on PRs targeting the default branch when the default\_branch built-in ruleset is enabled. | `number` | `0` | no |
| <a name="input_delete_branch_on_merge"></a> [delete\_branch\_on\_merge](#input\_delete\_branch\_on\_merge) | Automatically delete head branch after a pull request is merged. | `bool` | `true` | no |
| <a name="input_dependabot_security_updates"></a> [dependabot\_security\_updates](#input\_dependabot\_security\_updates) | Whether Dependabot opens PRs that fix vulnerable dependencies automatically.<br/>Set true/false to manage explicitly; leave null (the default) to leave the<br/>attribute unmanaged so existing repos see no drift. Enabling requires<br/>vulnerability\_alerts to be enabled — the GitHub API rejects this otherwise,<br/>and the module sets a depends\_on to enforce ordering on apply. | `bool` | `null` | no |
| <a name="input_description"></a> [description](#input\_description) | A description of the repository. | `string` | `null` | no |
| <a name="input_has_discussions"></a> [has\_discussions](#input\_has\_discussions) | Set to true to enable GitHub Discussions on the repository. Defaults to false. | `bool` | `false` | no |
| <a name="input_has_issues"></a> [has\_issues](#input\_has\_issues) | Set to true to enable the GitHub Issues features on the repository. | `bool` | `false` | no |
| <a name="input_has_projects"></a> [has\_projects](#input\_has\_projects) | Set to true to enable the GitHub Projects features on the repository. Per the GitHub documentation when in an organization that has disabled repository projects it will default to false and will otherwise default to true. If you specify true when it has been disabled it will return an error. | `bool` | `false` | no |
| <a name="input_has_wiki"></a> [has\_wiki](#input\_has\_wiki) | Set to true to enable the GitHub Wiki features on the repository. | `bool` | `false` | no |
| <a name="input_homepage_url"></a> [homepage\_url](#input\_homepage\_url) | URL of a page describing the project. | `string` | `null` | no |
| <a name="input_is_template"></a> [is\_template](#input\_is\_template) | Set to true to tell GitHub that this is a template repository. | `bool` | `false` | no |
| <a name="input_merge_commit_message"></a> [merge\_commit\_message](#input\_merge\_commit\_message) | Can be PR\_BODY, PR\_TITLE, or BLANK for a default merge commit message. Applicable only if allow\_merge\_commit is true. | `string` | `"PR_TITLE"` | no |
| <a name="input_merge_commit_title"></a> [merge\_commit\_title](#input\_merge\_commit\_title) | Can be PR\_TITLE or MERGE\_MESSAGE for a default merge commit title. Applicable only if allow\_merge\_commit is true. | `string` | `"MERGE_MESSAGE"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the repository. | `string` | n/a | yes |
| <a name="input_pages"></a> [pages](#input\_pages) | The repository's GitHub Pages configuration. | <pre>object({<br/>    build_type = string<br/>    cname      = optional(string)<br/>    source = optional(object({<br/>      branch = string<br/>      path   = string<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_security_and_analysis"></a> [security\_and\_analysis](#input\_security\_and\_analysis) | GitHub security\_and\_analysis configuration. Defaults to null which leaves<br/>the attribute unmanaged so existing repos see no drift. Set any sub-field<br/>to opt in.<br/><br/>GitHub API licensing gates (enforced at apply time):<br/>- secret\_scanning / secret\_scanning\_push\_protection: free on public<br/>  repos; require GHAS on private repos (the API returns 422 otherwise).<br/>- advanced\_security: requires GHAS regardless of visibility; the API<br/>  also rejects it on public repos. | <pre>object({<br/>    advanced_security               = optional(bool)<br/>    secret_scanning                 = optional(bool)<br/>    secret_scanning_push_protection = optional(bool)<br/>  })</pre> | `null` | no |
| <a name="input_squash_merge_commit_message"></a> [squash\_merge\_commit\_message](#input\_squash\_merge\_commit\_message) | Can be PR\_BODY, COMMIT\_MESSAGES, or BLANK for a default squash merge commit message. Applicable only if allow\_squash\_merge is true. | `string` | `"COMMIT_MESSAGES"` | no |
| <a name="input_squash_merge_commit_title"></a> [squash\_merge\_commit\_title](#input\_squash\_merge\_commit\_title) | Can be PR\_TITLE or COMMIT\_OR\_PR\_TITLE for a default squash merge commit title. Applicable only if allow\_squash\_merge is true. | `string` | `"COMMIT_OR_PR_TITLE"` | no |
| <a name="input_team_ids"></a> [team\_ids](#input\_team\_ids) | A map of github team ids, indexed on team slug | `map(string)` | `{}` | no |
| <a name="input_template"></a> [template](#input\_template) | Use a template repository to create this resource. | <pre>object({<br/>    include_all_branches = optional(bool, false)<br/>    owner                = string<br/>    repository           = string<br/>  })</pre> | `null` | no |
| <a name="input_visibility"></a> [visibility](#input\_visibility) | Can be public or private. If your organization is associated with an enterprise account using GitHub Enterprise Cloud or GitHub Enterprise Server 2.20+, visibility can also be internal. The visibility parameter overrides the private parameter. | `string` | `"private"` | no |
| <a name="input_vulnerability_alerts"></a> [vulnerability\_alerts](#input\_vulnerability\_alerts) | Whether GitHub security alerts for vulnerable dependencies are enabled.<br/>Set true/false to manage explicitly; leave null (the default) to leave the<br/>attribute unmanaged so existing repos see no drift. Enabling requires<br/>alerts to be enabled at the owner level. Wired to the standalone<br/>github\_repository\_vulnerability\_alerts resource. | `bool` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_default_branch"></a> [default\_branch](#output\_default\_branch) | Default branch name |
| <a name="output_node_id"></a> [node\_id](#output\_node\_id) | GraphQL global node id for use with v4 API |
<!-- END_TF_DOCS -->
