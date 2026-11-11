# Managing GitHub Repositories

Terraform code to manage GitHub repository settings across multiple
organisations. State is held in [Stategraph](https://stategraph.com/). `plan`
and `apply` run through the `stategraph` CLI, whose transactions guard against
concurrent changes; read-only state inspection uses the native `terraform` CLI
over Stategraph's HTTP backend.

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
# Native terraform, for task init and task state:*
export TF_HTTP_ADDRESS="https://app.stategraph.cloud/api/v1/states/backend/<group-id>"
export TF_HTTP_PASSWORD="$STATEGRAPH_API_KEY"
```

`backend.tf` is a partial HTTP backend configuration that takes its address
from the environment. It exists so that a plain `terraform` command reaches
the real state instead of initialising a local one. `task` fails with a usable
message if any variable is missing.

## Usage

Drive everything through the [Task](https://taskfile.dev/) wrappers;
`task --list` shows them all.

```bash
task plan    # stategraph tf plan --out tfplan.json   (opens a transaction)
task apply   # stategraph tf apply tfplan.json        (only after reviewing the plan)
```

`plan` and `apply` are separate steps: `plan` writes `tfplan.json`, which
`apply` then commits, so what gets applied is what you reviewed.

Also available: `task init` (terraform, for the state tasks),
`task state:list`, `task state:show REPO=<name>` and `task lockfile:sync`.

## Unmanaged repositories

GitHub repos without a local YAML config are tolerated. A `check` block in
[`modules/org/data.tf`](modules/org/data.tf) surfaces them as warnings during
`task plan` but does not block apply. To bring one under management, add a
`data/<ORG>/<repo>.yaml` and import it (see `imports.tf.template`).
