# Migrating a repository from actionlint to jactionlint

The playbook for moving a yo61, horopter-dev or ycst-org-uk repository from `rhysd/actionlint`
or `kjanat/actionlint` to [`jdx/jactionlint`](https://github.com/jdx/jactionlint), or for
adding jactionlint to a repository that has none. The org-wide choice is recorded in
[`decisions/2026-10-15-jactionlint-org-wide.md`](../decisions/2026-10-15-jactionlint-org-wide.md),
and the rollout itself in
[`docs/superpowers/plans/2026-10-15-jactionlint-rollout.md`](superpowers/plans/2026-10-15-jactionlint-rollout.md).

yo61/kuard went first, in two pull requests: #60 swapped the linter, and the follow-up turned on
the `default` profile and fixed what it found. Its findings are the worked example below.

## Why two phases

jactionlint's `correctness` profile runs the checks actionlint runs. Its `default` profile adds
security and policy rules that fail the build. Swapping the tool and turning those rules on in
one change mixes a tooling change with workflow changes, and the workflow changes can alter how
a repository builds or publishes. Keep them apart:

1. **Swap**: replace actionlint with jactionlint on `profile: correctness`. No workflow changes.
2. **Tighten**: set `profile: default` and fix every finding, in its own pull request.

Before choosing, run `jactionlint --profile default`. If it reports nothing, set
`profile: default` in the swap and skip phase 2.

## Before you start

- **An existing `actionlint.yaml` changes behaviour.** jactionlint reads `.github/actionlint.yaml`
  as its own config. If that file sets no `profile`, the `default` profile runs and jactionlint
  prints a `note:` saying so. Phase 1 then fails on findings it was meant to postpone. Replace
  the file with `.github/jactionlint.yaml`.
- **Release age.** Repositories follow a 7-day `minimumReleaseAge`, and jactionlint releases
  often. Take a release old enough to clear it. kuard took 2.2.0 at one day old by explicit
  exception, because no v2 release was old enough at the time.
- **Keep the pin's owner.** Every pin needs exactly one updater. Whatever updates the actionlint
  pin today updates the jactionlint pin, so the migration doesn't move ownership between bots.
  Pick the recipe that matches.

## Recipe: remote pre-commit hook

For repositories whose actionlint is a `repo:` entry in `.pre-commit-config.yaml`. That is most
of them, and CI's `lint` check (`prek run --all-files`) then needs no change.

```yaml
- repo: https://github.com/jdx/jactionlint
  rev: 1027f0a131ab98bc7e191d995bfa15dbed5bbf8f  # frozen: v2.2.0
  hooks:
    - id: jactionlint
```

- The hook id is `jactionlint`, not `actionlint`.
- The hook passes filenames, matching workflows, `action.y*ml` anywhere and `dependabot.y*ml`.
  kjanat's hook ran `actionlint pre-commit` with `pass_filenames: false` and saw only workflows,
  so composite actions may report findings for the first time.
- It is `language: golang`, like both actionlint hooks, so prek builds it.
- The `rev` belongs to Dependabot's `pre-commit` ecosystem, or to Renovate's `pre-commit`
  manager where that is enabled. A repository with neither gets a `pre-commit` entry in
  `.github/dependabot.y*ml`.
- A repository with no hook framework at all gets a `.pre-commit-config.yaml` holding this hook,
  the Dependabot entry, and a `lint` job running `j178/prek-action`, as `python-template`'s
  `ci.yaml` does.

## Recipe: mise and a local hook

For repositories that install tools from `mise.toml` with `jdx/mise-action`, as kuard does.

- `mise.toml`: `"github:jdx/jactionlint" = "<version>"`. Renovate's mise manager reads the
  `github:` backend from GitHub releases. Don't rely on the registry short name `jactionlint`;
  the explicit backend is what Renovate is known to resolve.
- `.pre-commit-config.yaml`: a `local` hook with `entry: jactionlint`, `language: system` and
  `files: ^\.github/(workflows/.*|dependabot)\.ya?ml$`.
- mise warns that `actionlint` is deprecated in favour of `jactionlint`. That points at
  `jdx/jactionlint`, not `kjanat/actionlint`. The warning goes away once `mise.toml` no longer
  names `actionlint`.

## Recipe: `go install` in CI

For a CI step that builds actionlint from source with a Renovate `datasource=go` comment:

```yaml
# renovate: datasource=go depName=github.com/jdx/jactionlint/v2
JACTIONLINT_VERSION: v2.2.0
```

```bash
go install "github.com/jdx/jactionlint/v2/cmd/jactionlint@${JACTIONLINT_VERSION}"
```

The module path carries `/v2`. Keep any explicit file arguments the old step passed.

## Phase 1: swap the linter

1. Create `.github/jactionlint.yaml`:

   ```yaml
   # yaml-language-server: $schema=https://raw.githubusercontent.com/jdx/jactionlint/main/schema/jactionlint-config.json
   profile: correctness
   ```

   Don't use `jactionlint --init-config` in a repository you're editing: it writes
   `.github/jactionlint.yaml` even when `-c` names another file, and the file it writes is
   mostly comments.
2. Delete `.github/actionlint.yaml` once nothing in it is still needed. jactionlint knows the
   `ubuntu-26.04` runner label, so that entry is never needed.
3. Apply the recipe that matches the repository, and point every other caller at the new
   binary: Taskfile or Makefile targets, `CONTRIBUTING.md`, `README.md`. Delete comments that
   explain the kjanat fork.
4. Check that `prek run jactionlint --all-files` (or `jactionlint`) exits 0. Then break a
   workflow on purpose, for example `runs-on: ${{ matrix.nope }}`, confirm the hook fails, and
   revert. A hook with a wrong `files:` pattern passes while checking nothing.

## Phase 2: turn on the default profile

1. See what you're facing without changing the config: `jactionlint --profile default`.
2. Fix each finding (see below), then set `profile: default`.
3. Optionally run `jactionlint --profile pedantic` to see the next level. kuard took one
   pedantic finding and left the style rules (`require-shell`, `anonymous-definition`).

For scripts, `--format json` gives each finding's rule in `id`. The `kind` field can differ: the
timeout rule has `kind: timeout-check` but `id: missing-timeout`, and the config and
`--explain` accept only `missing-timeout`.

## Findings in kuard and their fixes

| Rule | Where | Fix |
|---|---|---|
| `missing-timeout` | all 5 jobs | `timeout-minutes` per job |
| `concurrency-limits` | build-kuard | `concurrency:`, `cancel-in-progress: false` |
| `excessive-permissions` | build-kuard | `permissions: {}`; job gets its own |
| `cache-poisoning` | `build-push-action` | drop `cache-from`, keep `cache-to` |
| `cache-poisoning` (pedantic) | `setup-buildx-action` | `cache-binary: false` |

### Timeouts

A job without `timeout-minutes` can run for GitHub's six-hour limit, and a matrix multiplies
it. A stalled job has used up a whole organisation's free minutes before. Set each timeout from
the job's observed run time, about 3-5×, not a round comfortable number: the timeout is the
most a hung job can cost. Get durations with
`gh run view <run-id> --json jobs -q '.jobs[] | "\(.name) \(.startedAt) \(.completedAt)"'`.
kuard's jobs take 15 s to 3 min, so they got 5, 10 and 15 minutes.

### Concurrency on a publishing workflow

Use `cancel-in-progress: false` on a workflow that publishes, so a newer run waits instead of
cancelling a push halfway. A waiting run is replaced by a newer waiting run. That's fine when
each publish overwrites the same tags, as kuard's do. Add `queue: max` where every publish must
happen.

### Permissions

Job-level `permissions:` replace the workflow's rather than adding to them, so the job lists
everything it needs, including `contents: read` for checkout.

### Caches in a publishing job

A publishing job shouldn't restore a cache that another run wrote. kuard's `build-push-action`
keeps `cache-to`, because `ci.yaml`'s PR image build reads that cache, and drops `cache-from`.
Check the cost first: kuard's first-ever build, with no cache, took about as long as its cached
builds (about 2-3 min per matrix job), so dropping the restore cost nothing noticeable.

## Overlap with zizmor

jactionlint's security rules follow zizmor's audits, and at its default settings it reported
things zizmor did not (`cache-poisoning`, `excessive-permissions`). Repositories keep both for
now. If jactionlint later replaces zizmor, `jactionlint --migrate-ignores` turns
`# zizmor: ignore[...]` comments into jactionlint's own.
