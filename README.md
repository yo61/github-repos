# Managing GitHub Repositories

Terraform code to manage GitHub repository settings across multiple
organisations. State is held in [Stategraph](https://stategraph.com/). Plan,
apply and state inspection all run through the `stategraph` CLI, whose
transactions guard against concurrent changes. There is no backend block, so
don't run `terraform plan`/`apply` directly: it would use a local state.

## Repository configuration

Each repo is defined by a YAML file at `data/<ORG>/<REPO>.yaml`. The filename
stem must match the `name:` field. A minimal example:

```yaml
auto_init: true
collaborators:
  users:
    - permission: admin
      username: <github-username>
delete_branch_on_merge: true
name: <repo-name>
```

A full list of configuration parameters lives in
[`modules/github-repo/README.md`](modules/github-repo/README.md).

## Setup

Copy `stategraph.json.example` to `stategraph.json` and fill in the state's
`group_id` (`stategraph states list` shows it). Then export, e.g. from a
direnv `.envrc`:

```bash
export STATEGRAPH_API_BASE="https://app.stategraph.cloud"
export STATEGRAPH_API_KEY="<api-key>"
export STATEGRAPH_TENANT_ID="<tenant-id>"   # stategraph user tenants list
```

`task` fails with a usable message if any variable or `stategraph.json` is
missing. No `terraform init` is needed.

## Usage

Drive everything through the [Task](https://taskfile.dev/) wrappers;
`task --list` shows them all.

```bash
task plan    # stategraph tf plan --skip-costs --out tfplan.json   (opens a transaction)
task apply   # stategraph tf apply tfplan.json                     (only after reviewing the plan)
```

`plan` and `apply` are separate steps: `plan` writes `tfplan.json`, which
`apply` then commits, so what gets applied is what you reviewed.

Also available: `task state:list`, `task state:show REPO=<name>` and
`task lockfile:sync`.

## Unmanaged repositories

GitHub repos without a local YAML config are tolerated. A `check` block in
[`modules/org/data.tf`](modules/org/data.tf) surfaces them as warnings. They
appear in `task apply`'s output, not `task plan`'s, and do not block apply. To bring one under management, add a
`data/<ORG>/<repo>.yaml` and import it (see `imports.tf.template`).
