#!/usr/bin/env bash
# Ground truth for check_ruleset_paywall_comment.sh: fixtures with known verdicts.
#
# Written after a review found the key-detection regex silently no-opping on a
# trailing inline comment — a guard that skips a file reports success, so only a
# case whose expected verdict is known independently can catch it.
#
# Fixtures are generated into a temp directory rather than committed: under
# data/<org>/<repo>.yaml they would be linted as real repo config.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
subject="$script_dir/check_ruleset_paywall_comment.sh"

RECORD="decisions/2026-08-10-private-repos-manual-review-gate.md"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# name<TAB>expected exit<TAB>content
fixture() {
  printf '%s' "$3" > "$tmp/$1.yaml"
  cases+=("$1:$2")
}

cases=()

fixture block-cites-record 0 "---
# Paywalled on a private repo in a free-plan org. See $RECORD.
builtin_ruleset_names: []
name: block-cites-record
"
fixture no-comment 1 "---
builtin_ruleset_names: []
name: no-comment
"
fixture comment-without-record 1 "---
# Empty because rulesets are paywalled here.
builtin_ruleset_names: []
name: comment-without-record
"
fixture blank-line-detaches-comment 1 "---
# See $RECORD.

builtin_ruleset_names: []
name: blank-line-detaches-comment
"
fixture inline-cites-record 0 "---
builtin_ruleset_names: []  # paywalled; see $RECORD
name: inline-cites-record
"
fixture inline-without-record 1 "---
builtin_ruleset_names: []  # explain later
name: inline-without-record
"
fixture block-cites-inline-does-not 0 "---
# See $RECORD.
builtin_ruleset_names: []  # unrelated note
name: block-cites-inline-does-not
"
fixture non-empty-list-ignored 0 "---
builtin_ruleset_names:
  - default_branch
name: non-empty-list-ignored
"
fixture key-absent-ignored 0 "---
name: key-absent-ignored
visibility: public
"

failures=0
for case in "${cases[@]}"; do
  name="${case%:*}"
  want="${case#*:}"
  if "$subject" "$tmp/$name.yaml" > /dev/null 2>&1; then got=0; else got=1; fi
  if [[ "$got" == "$want" ]]; then
    printf 'ok    %-30s exit=%s\n' "$name" "$got"
  else
    printf 'FAIL  %-30s want=%s got=%s\n' "$name" "$want" "$got"
    failures=$((failures + 1))
  fi
done

# A batch of mixed fixtures must fail, or a single bad file in a commit passes.
if "$subject" "$tmp"/*.yaml > /dev/null 2>&1; then
  printf 'FAIL  %-30s batch of mixed fixtures exited 0\n' "batch-nonzero"
  failures=$((failures + 1))
else
  printf 'ok    %-30s batch exits nonzero\n' "batch-nonzero"
fi

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "all ${#cases[@]} fixtures + batch check passed"
