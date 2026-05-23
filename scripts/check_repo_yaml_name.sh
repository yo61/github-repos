#!/usr/bin/env bash
# Verify every data/<org>/<repo>.yaml file's `name:` field equals its filename stem.
# Files whose basename starts with `_` are reserved metadata files and are skipped.

set -euo pipefail

status=0
for file in "$@"; do
  base="$(basename "$file" .yaml)"
  case "$base" in
  _*) continue ;;
  *) ;;
  esac
  name="$(awk -F': *' '/^name:/ { print $2; exit }' "$file" || true)"
  name="${name%\"}"
  name="${name#\"}"
  name="${name%\'}"
  name="${name#\'}"
  if [[ -z "$name" ]]; then
    echo "ERROR: $file is missing a top-level \`name:\` field" >&2
    status=1
  elif [[ "$name" != "$base" ]]; then
    echo "ERROR: $file has name=\"$name\" but filename stem is \"$base\"" >&2
    status=1
  fi
done
exit "$status"
