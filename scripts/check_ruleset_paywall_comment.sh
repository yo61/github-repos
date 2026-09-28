#!/usr/bin/env bash
# Verify every `builtin_ruleset_names: []` carries a comment naming a decision record.
#
# The empty list is forced by the rulesets API returning 403 on a private repo in a
# free-plan org. Nothing in the YAML says so, which is why the key has repeatedly
# read as an oversight. The citation may sit in a comment block directly above the
# key, with no blank line between, or in a trailing comment on the key line itself.

set -euo pipefail

status=0

for file in "$@"; do
  mapfile -t lines < "$file"

  key=-1
  for i in "${!lines[@]}"; do
    # The trailing-comment branch is required, not cosmetic: without it a key line
    # carrying any inline comment fails to match, and the file is skipped silently.
    if [[ ${lines[i]} =~ ^builtin_ruleset_names:[[:space:]]*\[[[:space:]]*\][[:space:]]*(#.*)?$ ]]; then
      key=$i
      break
    fi
  done

  # No key, or a non-empty list: the paywall is not what put it there.
  [[ $key -ge 0 ]] || continue

  comment="${BASH_REMATCH[1]:-}"
  for ((i = key - 1; i >= 0; i--)); do
    [[ ${lines[i]} =~ ^[[:space:]]*# ]] || break
    comment="${lines[i]}${comment}"
  done

  if [[ -z "$comment" ]]; then
    echo "ERROR: $file sets \`builtin_ruleset_names: []\` with no comment." >&2
    echo "       Say why the list is empty and cite the decisions/ record." >&2
    status=1
  elif [[ ! "$comment" =~ decisions/[^[:space:]]+\.md ]]; then
    echo "ERROR: $file comments \`builtin_ruleset_names: []\` but names no record." >&2
    echo "       Cite the decisions/*.md path that explains the paywall." >&2
    status=1
  fi
done

exit "$status"
