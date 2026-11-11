## Decision: Route `task plan` and `task apply` through the Stategraph CLI (`stategraph tf plan --out tfplan.json` / `stategraph tf apply tfplan.json`) instead of native `terraform` over the HTTP backend. Keep `backend.tf` and the native-terraform tasks (`init`, `state:list`, `state:show`) for read-only inspection and state surgery. Drop `task plan ORG=<org>`.

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
- **Delete `backend.tf`, as the Stategraph docs suggest.** Rejected: without it a stray `terraform init` configures a local backend and plans to recreate every repo, the failure that 2026-08-04 made structurally impossible. Keeping it costs nothing for the CLI, which ran against `unifi` with its `backend.tf` in place.
- **Move `state:list`/`state:show` to `stategraph sql`/`states instances`.** Rejected for now: they are reads, the lock question does not arise, and `terraform state list` already works.

## Reasoning: Stategraph's transactions are the only concurrency control available on this store, and they only apply when the write goes through its CLI. Routing the two writing tasks through it closes the gap with the smallest change: state does not move, no resource changes, and the native path stays available for the operations the CLI is weakest at.

## Trade-offs accepted:
- **The CLI's write path has failed before.** stategraph/releases#3 is open, and the `/logs/append` 404 was never filed. A failed plan can leave a transaction open; clean up with `stategraph tx abort --tx <id>`.
- **`check` results show on apply, not plan.** Verified on this state the same day: `task plan` reported `No changes` with no warnings, while a read-only native `terraform plan` and the subsequent `task apply` both reported `check "unmanaged_repos"` failing for `ycst-org-uk/ycst-wp-dev`. Robin chose to accept this and report it upstream rather than add a native plan alongside; filed as stategraph/releases#5.
- **The plan's cost preview reads like a destroy.** On a no-change plan it lists every resource with `-` and `Resources: 277 → 0 (-277)`; the plan line above it is the one to read. Filed as stategraph/releases#6.
- **A plan with `--out` leaves its transaction `previewed` until applied.** An unapplied `task plan` must be aborted (`stategraph tx abort --tx <id>`, the id is in `tfplan.json`); this is where August's pile of previewed transactions came from.
- **No `ORG=` scoping.** `stategraph tf plan` has no `-target`, only `--force`.
- **Two ways to reach the state remain.** Native `terraform plan`/`apply` still works over `backend.tf`; it is undocumented as a route for changes, and CLAUDE.md says not to use it. Any write through it takes no lock and leaves the stored configuration stale until the next `import tf --hcl --overwrite`.
- **Three more environment variables** (`STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, `STATEGRAPH_TENANT_ID`) and a present `stategraph.json` are now required. `stategraph.json` stays gitignored, for the same public-repo reason the backend address is partial.
- **The same switch is owed in four other roots** that share the unlocked arrangement: `yo61/infrastructure`, `horopter-dev/infrastructure`, `yo61/homelab-infrastructure` and its `unifi/` root. Each is its own repo and gets its own change.

## Supersedes: `decisions/2026-08-04-native-terraform-http-backend.md`, for the plan/apply client only. Its partial `backend.tf`, environment-variable binding and preflight guards stand.
