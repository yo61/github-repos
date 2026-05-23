# Managing GitHub Repositories

Terraform code to manage GitHub repository settings across multiple
organisations. State is held in [stategraph](https://stategraph.dev/) —
operations run as `stategraph tf <subcommand>`.

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

## Usage

Stategraph runs `plan` and `apply` as separate steps: `plan` writes a JSON
plan file that `apply` then consumes.

```bash
stategraph tf plan --out tfplan.json
stategraph tf apply tfplan.json
```

Or via [Task](https://taskfile.dev/):

```bash
task plan       # writes tfplan.json
task apply      # consumes tfplan.json
```

State setup (one-time): copy `stategraph.json.example` to `stategraph.json`
and fill in your `group_id`, then consult the
[Stategraph docs](https://stategraph.com/docs) for the exact
`stategraph states create` / `stategraph import tf` invocation that matches
your tenant.

## Unmanaged repositories

GitHub repos without a local YAML config are tolerated — `stategraph tf plan`
emits a warning listing them but does not block apply. To bring one under
management, add a `data/<ORG>/<repo>.yaml` and import it (see
`imports.tf.template`).
