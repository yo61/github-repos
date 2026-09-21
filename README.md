# Managing GitHub Repositories

Terraform code to manage GitHub repository settings across multiple
organisations. State is held in [stategraph](https://stategraph.dev/), reached
through its **HTTP backend** using the native `terraform` CLI — Stategraph is a
state store here, and its CLI does not run `plan` or `apply`.

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

`backend.tf` is a partial configuration: it declares the backend but omits the
address, so both the address and the API key come from the environment. They
live in `.envrc`, loaded by direnv (`direnv allow` once per clone):

```bash
export TF_HTTP_ADDRESS="https://app.stategraph.cloud/api/v1/states/backend/<state-uuid>"
export TF_HTTP_PASSWORD="$STATEGRAPH_API_KEY"
```

`.envrc` is machine-specific and untracked. Any other way of exporting the two
variables works just as well. `task` fails with a usable message if either is
missing, rather than prompting for an address or returning a bare 401.

State setup (one-time): copy `stategraph.json.example` to `stategraph.json` and
fill in your `group_id`, then consult the
[Stategraph docs](https://stategraph.com/docs) for the `stategraph states create`
/ `stategraph import tf` invocation that matches your tenant. That is the extent
of the Stategraph CLI's role — everything below is `terraform`.

## Usage

Drive everything through the [Task](https://taskfile.dev/) wrappers;
`task --list` shows them all.

```bash
task init    # terraform init                 (once per clone)
task plan    # terraform plan -out tfplan     (read-only)
task apply   # terraform apply tfplan         (only after reviewing the plan)
```

`plan` and `apply` are separate steps: `plan` writes a plan file named `tfplan`
that `apply` then consumes, so what gets applied is what you reviewed.

`plan` takes an optional `ORG` to scope it to one organisation, which must name
a directory under `data/`:

```bash
task plan ORG=yo61
```

Also available: `task state:list`, `task state:show REPO=<name>` and
`task lockfile:sync`.

## Unmanaged repositories

GitHub repos without a local YAML config are tolerated. A `check` block in
[`modules/org/data.tf`](modules/org/data.tf) surfaces them as warnings during
`terraform plan` but does not block apply. To bring one under management, add a
`data/<ORG>/<repo>.yaml` and import it (see `imports.tf.template`).
