# jactionlint rollout across locally-cloned repositories

Move every in-scope repository from actionlint (`rhysd` or the `kjanat` fork) to
[`jdx/jactionlint`](https://github.com/jdx/jactionlint), and add jactionlint to the ones that run
workflows with no linter. kuard is done (#60 and the follow-up); this plan reuses its playbook.

## Scope

**In scope** means every repository cloned under `~/code/github.com` (as of 2026-10-15) that has
`.github/workflows`, except forks kept only to track upstream. A local clone stands in for
"recently active". Forks fall into two kinds:

- **Owned forks**: diverged, with workflows of their own. kuard (done) and
  `yo61/commitlint-github-action`, which publishes its own ghcr image. In scope.
- **Tracking forks**: kept to sync with upstream and send PRs back. Out of scope, because a
  workflow change conflicts with every upstream sync and leaks into upstream PRs:
  yo61/{brew, civicrm-core, lastlight, tns-csi} and robinbowes/PrincetonReverbUpdate.

30 repositories in scope, plus kuard (done):

| Group | Today | Repos | Count |
|---|---|---|---|
| A | `kjanat/actionlint` remote pre-commit hook | horopter-dev/{dot-github, horopter-docs, record-action, website}; yo61/{agent-team-topologies, infrastructure, python-template} | 7 |
| B | `rhysd/actionlint` remote pre-commit hook | ycst-org-uk/{board-docs, website-testing}; yo61/{claude-plugin-contributory-factors, claude-plugin-guardrails, claude-plugin-lastlight-pr-gate, claude-plugin-reportlab-pdf, claude-skills, gh-release-stats, go-udap, homelab-docs, jobhound, udapcfg-rs, unifi-mcp, unifictl} | 14 |
| C | `go install` step in CI | horopter-dev/horopter (kjanat, CI only); yo61/claude-plugin-dependency-updates (rhysd 1.7.12 in CI *and* hook) | 2 |
| D | workflows, no actionlint | horopter-dev/{helm-charts, horopter-internal, infrastructure}; yo61/{civi-mcp, flux-homelab, github-repos} | 6 |
| E | workflows, no actionlint, **no pre-commit or mise** (Dependabot only) | yo61/commitlint-github-action | 1 |
| — | `brew style` runs actionlint itself | yo61/homebrew-tap | 1 (out) |

Also out of scope: every repository without `.github/workflows`. No in-scope repo
has a `.github/actionlint.yaml`, so the "config without `profile` selects `default`" trap
doesn't apply. Check again anyway (step 2.2).

Before starting a repository, `git pull` its clone. These were behind `origin` on 2026-10-15:
website-testing, civi-mcp, claude-plugin-dependency-updates, claude-plugin-reportlab-pdf,
flux-homelab, gh-release-stats and unifictl. These are checked out on feature branches, so use a
worktree: horopter-dev/website, ycst-org-uk/board-docs and yo61/claude-skills.

## Decisions (settled 2026-10-15)

Recorded in `decisions/2026-10-15-jactionlint-org-wide.md`.

1. Shared docs live here in `yo61/github-repos`; kuard links to them.
2. v2.2.0, with Phase 1 starting now, as an exception to `minimumReleaseAge`.
3. homebrew-tap stays out: `brew style` brings its own actionlint.
4. zizmor stays alongside jactionlint; whether one replaces the other is decided after Phase 2.
5. Forks that track upstream stay out.
6. commitlint-github-action gets a `.pre-commit-config.yaml` with the jactionlint hook, a
   Dependabot `pre-commit` ecosystem, and a `lint` job running `j178/prek-action`, as
   python-template's `ci.yaml` does.

## Tracking

Linear project [jactionlint rollout](https://linear.app/yo61/project/jactionlint-rollout-82c71a37daf7)
in the Yo61 workspace, Global team: GLB-1 (Phase 0), GLB-3 and GLB-4 (pilots), GLB-5 to GLB-32
(one per repository, both phases as a checklist), GLB-2 (Phase 3). Every repository issue is
blocked by both pilots and blocks GLB-2.

## Phase 0: shared docs and decision (now)

1. Add `docs/jactionlint-migration.md` here: kuard's playbook, generalised, with recipes for a
   remote pre-commit hook, mise, and `go install` in CI.
2. Add `decisions/2026-10-15-jactionlint-org-wide.md`, which supersedes item 3 of
   `2026-10-09-yo61-dependency-update-remediation.md` and covers horopter-dev and ycst-org-uk.
   horopter-dev records its decisions in `horopter-internal/decisions/`, so link to it from
   there.
3. Move the hypotheses to `knowledge/dependency-updates/hypotheses.md`, with
   `knowledge/INDEX.md`. In kuard, replace its playbook and hypotheses with links here.

## Phase 1: swap (or add) on `profile: correctness`

**Pilot first**: `yo61/python-template` (new repos inherit from it) and
`yo61/gh-release-stats` (Group B). kuard proved the mise recipe. The remote-hook recipe hasn't
run anywhere yet.

Per repository, in one branch and one PR:

1. Check the default profile first: `jactionlint --profile default` (with mise:
   `mise x github:jdx/jactionlint@2.2.0 -- jactionlint --profile default`).
   - **No findings:** set `profile: default` in step 3 and skip Phase 2 for this repo. That is
     the case the hypothesis says splitting would only add overhead.
   - **Findings:** use `profile: correctness` and record the count for Phase 2.
2. Run `fd -H 'actionlint' .github`. Any `actionlint.yaml` must go (see the playbook).
3. Add `.github/jactionlint.yaml`:

   ```yaml
   # yaml-language-server: $schema=https://raw.githubusercontent.com/jdx/jactionlint/main/schema/jactionlint-config.json
   profile: correctness
   ```

4. Swap the linter, depending on the group:
   - **A/B**: replace the actionlint `repo:` block with the recipe above. Delete the
     "maintained fork" comment above it.
   - **C, horopter**: in `ci.yaml`, set the Renovate comment to
     `datasource=go depName=github.com/jdx/jactionlint/v2`, the version to `v2.2.0`, and
     install with `go install "github.com/jdx/jactionlint/v2/cmd/jactionlint@${JACTIONLINT_VERSION}"`.
     Rename the env var and update `CONTRIBUTING.md`.
   - **C, dependency-updates**: swap the hook as for B. The CI step lints
     `skills/*/templates/renovate-runner.yaml` by explicit path, so change it the same way as
     horopter's and keep the path argument. Update README line 35 and any skill text that
     prescribes actionlint or kjanat.
   - **D**: add the recipe next to the other hooks.
   - **E**: per decision 6, set up the hook config, the Dependabot ecosystem and the prek `lint`
     job in this one PR. Its workflows still use `runs-on: ubuntu-latest`. Leave that alone
     here; it's a separate change.
5. Verify before pushing, and aim for one push per PR. Wherever Last Light reviews are still on,
   each head SHA is a paid review. This repo's CLAUDE.md says Last Light was switched off for
   cost, so check before assuming either way.
   - `prek run jactionlint --all-files` exits 0.
   - Break one workflow on purpose (e.g. `runs-on: ${{ matrix.nope }}`) and confirm the hook
     fails, then revert.
   - `prek run --all-files` is clean. This is the same command CI's `lint` check runs, so A,
     B and D need no CI change.
6. PR title: `ci: replace actionlint with jactionlint` (Group D: `ci: lint workflows with
   jactionlint`).

After the pilot merges, do the other groups in this order: A (5 left), B (13 left), D, E, C. Group
C is last because it needs hand edits.

## Phase 2: tighten to `profile: default`

Only for repos that had findings in step 1.1. One PR per repo, following "Phase 2" and
"Findings in kuard" in the playbook:

- `missing-timeout`: set it from observed durations (`gh run view <id> --json jobs`) at about
  3-5×.
- `excessive-permissions`: `permissions: {}` at workflow level, list per job. Job-level
  permissions replace workflow-level ones, so include `contents: read`.
- `concurrency-limits` on publishing workflows: `cancel-in-progress: false`.
- `cache-poisoning` in publishing jobs: drop the restore, keep the save if another job reads it.

Publishing repos (releases, images, Pages: go-udap, unifictl, jobhound, homelab-docs,
horopter-docs, horopter-dev/website, helm-charts) get a closer review here, because these fixes
change how they publish.

## Phase 3: global cleanup

- `~/.claude/CLAUDE.md` line 286: change the `actionlint` row to `jactionlint`
  (`jactionlint` with no arguments checks the workflows, composite actions and
  `dependabot.yaml`). This is your file, so it's your edit to approve.
- Vim ALE (`robinbowes/dotfiles`): ALE's `yaml/actionlint` linter calls `actionlint`. Whether
  jactionlint's output fits ALE's handler is **untested**. Try
  `let g:ale_yaml_actionlint_executable = 'jactionlint'` on a broken workflow before relying on
  it.
- Update the hypothesis with each repo that followed the two-PR path or was clean on day one.
  The pilot plus Group A should give the three confirmations needed to promote it to
  `rules.md`. Clean-on-day-one repos are partial evidence against it.

## Done when

- `rg -n --hidden 'rhysd/actionlint|kjanat/actionlint|actionlint\.kjanat'` finds nothing in the
  30 repos' operational files: `.pre-commit-config.yaml`, `.github/`, `mise.toml`, `Taskfile*`,
  `CONTRIBUTING.md`, `README.md`.
- Every one of the 30 has `.github/jactionlint.yaml` with `profile: default`.
- `python-template` is on jactionlint, so new repos start that way.
