## Decision: record `unifictl`'s rebase-only merge buttons in Terraform. `allow_merge_commit: false` and `allow_squash_merge: false` in `data/yo61/unifictl.yaml`, superseding the squash-merge choice of `decisions/2026-08-07-blank-merge-commit-message.md` for that repo alone.

## Context: `unifictl` disabled squash and merge-commit on 2026-09-03 under its
own `decisions/2026-09-03-rebase-only-merge-policy.md`, leaving rebase as the
only merge button. This repo never learned about it, so the module defaults
(`allow_merge_commit = true`, `allow_squash_merge = true` at
`modules/github-repo/variables.tf:15-34`) still rendered, and the plan proposed:

```
# module.org_yo61.module.repo["unifictl"].github_repository.this will be updated in-place
~ allow_merge_commit = false -> true
~ allow_squash_merge = false -> true
```

That is Terraform preparing to silently undo a deliberate policy on the next
apply — the failure mode `decisions/2026-08-25-exclude-archived-from-drift-detection.md`
describes for `archived`, in a new attribute.

`unifictl`'s reason for the switch: 0.5.4 shipped the `--wan` flag under **Bug
Fixes** with a patch bump. The branch was deliberately split into `fix(list):`
and `feat(list):` commits to produce both changelog sections, and squash
discarded all but the PR title. `squash_merge_commit_message` was already
`COMMIT_MESSAGES`, so the `feat:` line was present in the squashed commit's
body and ignored anyway — release-please parses only the subject.

## Alternatives considered:

- **Apply the plan as it stands.** Rejected. It re-enables two buttons that
  `unifictl` turned off three weeks after this repo chose squash, and does so
  without anyone deciding to. The plan is not evidence the config is right.
- **Set `allow_merge_commit: false` only, keeping squash.** This is the exact
  escalation `decisions/2026-08-07-blank-merge-commit-message.md` reserved for
  "if squashing is forgotten repeatedly". Rejected: squash is what failed on
  0.5.4, and it failed while being used correctly, not from being forgotten.
  The escalation was written for the wrong failure.
- **Revert `unifictl` to squash and leave this repo unchanged.** Rejected. The
  0.5.4 loss is structural — one PR title cannot express a change that is both
  a fix and a feature — and `unifictl` has since added a `commit-hygiene` CI
  job rejecting `fixup!`/`squash!`/`amend!`/`wip` subjects, which only earns
  its keep under a non-squash strategy.
- **Change the module defaults to rebase-only for every repo.** Rejected as
  out of proportion. The evidence is one repo's changelog; the other two
  release-please repos (`unifi-mcp`, `claude-skills`) have not hit it.
  Revisit if a second repo does.

## Reasoning: the data file records deviations from the module defaults, and
rebase-only is now a deviation. Writing it down is what stops the apply from
reverting it, and it is the only mechanism available — there is no per-repo
opt-out of a `nullable = false` variable short of stating the value.

The 2026-08-07 decision is superseded for `unifictl` only. Its finding stands
everywhere else: no merge-commit title/message combination avoids duplicated
changelog entries, so squash remains the choice for `unifi-mcp` and
`claude-skills` until one of them produces a comparable failure.

## Trade-offs accepted:

- **The org no longer has one merge strategy.** `unifictl` is rebase-only,
  `unifi-mcp` and `claude-skills` are squash-by-practice, everything else is
  module default. Someone reading two data files side by side will not find a
  rule, only two decisions. The decision records are the rule.
- **`unifictl`'s changelog loses its `(#N)` PR references.** GitHub's
  rebase-merge does not rewrite subjects, so the PR link is gone; the commit
  link remains. This is the trade `unifictl` accepted and this change only
  makes it durable.
- **Auto-merge now has exactly one method left.** `allow_auto_merge: true` on
  this repo needs an enabled merge method, and rebase is the last one.
  Disabling `allow_rebase_merge` in future would strand every armed PR — a
  failure that would look like the review-gate stall in `CLAUDE.md` but is not.
- **Two more keys drift out of date if `unifictl` changes its mind.** Nothing
  detects that; the next plan reports it as a diff, the same way this one did.

## Supersedes: `decisions/2026-08-07-blank-merge-commit-message.md`, for
`unifictl` only. That decision's `nullable = false` finding and its squash
choice for the other release-please repos are unaffected.
