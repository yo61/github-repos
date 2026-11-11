## Decision: Reach the state only through the Stategraph CLI: `task plan` is `stategraph tf plan --skip-costs --out tfplan.json`, `task apply` is `stategraph tf apply tfplan.json`, and `task state:list`/`state:show` query `stategraph sql`. Delete `backend.tf` and `task init`. Drop `task plan ORG=<org>`. State surgery goes through the plan: `stategraph refactor` or `moved` blocks for moves, `removed` blocks for forgetting.

*Revised the same day (PR after #164):* the first version kept `backend.tf` and the native state tasks. Robin decided to delete it once it was shown the CLI needs neither it nor `terraform init`; the two alternatives below marked *Adopted in revision* were rejected in the first version.

## Context: The goal is state locking. `decisions/2026-08-04-native-terraform-http-backend.md` moved plan/apply onto native terraform because the Stategraph CLI's write path was failing, and accepted an unlocked backend as the cost. That cost was re-examined on 2026-11-11 and checked against the live service rather than our own docs: `GET https://app.stategraph.cloud/api/v1/openapi` lists only `get,post` on `/api/v1/states/backend/{group_id}` and `/{group_id}/{workspace}`. There is no route for terraform's `LOCK`/`UNLOCK`, so locking cannot be switched on by setting `lock_address`; Stategraph's docs state that "Stategraph transactions, not backend locks, control concurrency".

The reason for leaving the CLI was re-tested the same day on CLI 3.2.28, against `yo61/homelab-infrastructure/unifi`:

- **stategraph/releases#3** (an empty plan errors with `NO_STATES`) does not reproduce: the plan reported `No changes detected.` and its transaction aborted cleanly. The issue is still open upstream.
- The first plan failed earlier, with `state schema out of date` (stored configuration at schema 13, server at 19). The cause is the native path itself: `terraform apply` writes state through the HTTP backend but never uploads HCL, so Stategraph's copy of the configuration goes stale. `stategraph import tf --hcl --overwrite -y` refreshed it without touching resources.
- The two transactions left open by the August failures (`06747cad`, `eeccaa31`) were aborted; none remain open.

The August `/logs/append` 404 fired only on plans with real changes, so an empty plan does not prove it fixed. After the switch, a no-op `task plan` + `task apply` on `github-repos` committed cleanly (`Apply complete! Resources: 0 added, 0 changed, 0 destroyed.`, transaction `03495457`). Robin chose to commit to the switch rather than wait for a real change to prove it first.

## Alternatives considered:
- **Wait for a real change to prove the write path, then switch.** Recommended, and declined in favour of moving now. The first real `task plan` on each state is that proof; if it fails, this decision is reversed rather than worked around.
- **Stay on native terraform and ask Stategraph to add `LOCK`/`UNLOCK` to the HTTP backend.** Leaves every state unlocked for an unknown time, and contradicts the vendor's stated concurrency model.
- **Move state to a backend with native locking** (S3 with `use_lockfile`). Leaves Stategraph entirely; disproportionate to the problem.
- **Stay unlocked.** Defensible for a single operator with no CI applies, which is the current position, but it is the gap being closed.
- **Delete `backend.tf`, as the Stategraph docs suggest.** *Adopted in revision.* First rejected because a stray `terraform init` then configures a local backend and plans to recreate every repo, the failure 2026-08-04 made structurally impossible. Adopted because a fresh worktree with no `.terraform/` and no `backend.tf` planned `No changes`, so nothing in the supported path needs it, and keeping it left a second, unlocked route to the state open.
- **Move `state:list`/`state:show` to `stategraph sql`.** *Adopted in revision*, as the consequence of deleting `backend.tf`. `stategraph sql query --format simple --paginate` returns all 280 instances; without `--paginate` it stops at 20 and says so only on stderr. `stategraph states instances query` failed with `UNKNOWN_TAG`.

## Reasoning: Stategraph's transactions are the only concurrency control available on this store, and they only apply when the write goes through its CLI. Making the CLI the only supported route closes the gap without moving state or changing any resource, and removing the backend block means an unlocked write takes deliberate setup rather than one `terraform apply`.

## Trade-offs accepted:
- **The CLI's write path has failed before.** stategraph/releases#3 is open, and the `/logs/append` 404 was never filed. A failed plan can leave a transaction open; clean up with `stategraph tx abort --tx <id>`.
- **`check` results show on apply, not plan.** Verified on this state the same day: `task plan` reported `No changes` with no warnings, while a read-only native `terraform plan` and the subsequent `task apply` both reported `check "unmanaged_repos"` failing for `ycst-org-uk/ycst-wp-dev`. Robin chose to accept this and report it upstream rather than add a native plan alongside; filed as stategraph/releases#5.
- **The plan's cost preview reads like a destroy.** On a no-change plan it lists every resource with `-` and `Resources: 277 → 0 (-277)`. Filed as stategraph/releases#6; `task plan` passes `--skip-costs`, which removes the block. These GitHub resources have no price, so nothing is lost.
- **A plan with `--out` leaves its transaction `previewed` until applied.** An unapplied `task plan` must be aborted (`stategraph tx abort --tx <id>`, the id is in `tfplan.json`); this is where August's pile of previewed transactions came from.
- **No `ORG=` scoping.** `stategraph tf plan` has no `-target`, only `--force`.
- **A stray `terraform init`/`plan` falls back to a local state** and plans to create all 280 instances. Nothing outside the Taskfile can guard against it; CLAUDE.md says never to run terraform here. A clone that predates this change still caches the `http` backend in `.terraform/terraform.tfstate`, where `terraform init` offers to migrate state to a local file; that file must be deleted.
- **Renames rely on an instance-keyed `removed` block.** A repo rename needs a forget plus an `import`, since `moved` cannot change a name-keyed ID. Native terraform rejected `removed` on `module.org_yo61.module.repo["x"]` (2026-07-30); Stategraph's handling of one is unverified.
- **`moved` under the 3.x CLI is unexercised here.** The 2.x CLI ignored it; 3.x generates `moved` blocks in `stategraph refactor`, which suggests it honours them, but the first plan with one needs reading closely.
- **Three environment variables** (`STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, `STATEGRAPH_TENANT_ID`) and a present `stategraph.json` are required, replacing `TF_HTTP_ADDRESS`/`TF_HTTP_PASSWORD`. `stategraph.json` stays gitignored, for the public-repo reason the backend address used to be partial.
- **The same switch is owed in four other roots** that share the unlocked arrangement: `yo61/infrastructure`, `horopter-dev/infrastructure`, `yo61/homelab-infrastructure` and its `unifi/` root. Each is its own repo and gets its own change.

## Supersedes: `decisions/2026-08-04-native-terraform-http-backend.md` in full. Its partial `backend.tf`, `TF_HTTP_*` binding and HTTP preflight guards are removed.
