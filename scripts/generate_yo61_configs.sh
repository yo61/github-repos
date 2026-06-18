#!/usr/bin/env bash
# Generate imports-<ORG>.tf: Terraform `import` blocks that adopt every managed
# repo and its module-instantiated resources into Stategraph state.
#
# Driven by the committed data/<ORG>/<repo>.yaml configs — the source of truth
# for what modules/github-repo will instantiate — NOT by live GitHub settings.
# The only thing fetched from GitHub is resource IDs that the config cannot know
# (ruleset IDs), via `gh api`.
#
# Resources imported per repo (gated to match modules/github-repo/main.tf):
#   always:                               github_repository                              id <repo>
#                                         github_repository_collaborators                id <repo>
#   builtin_ruleset_names (def [default_branch]):
#                                         github_repository_ruleset.this["<key>"]        id <repo>:<ruleset_id>
#   vulnerability_alerts set:             github_repository_vulnerability_alerts.this["this"]        id <repo>
#   dependabot_security_updates set:      github_repository_dependabot_security_updates.this["this"] id <repo>
#   pages set:                            github_repository_pages.this["pages"]          id <repo>
#   create_default_branch = true:         github_branch.this["default"]                  id <repo>:<branch>
#                                         github_branch_default.this["default"]          id <repo>
#   apply_default_branch_protection=true: github_branch_protection.this["<branch>"]      id <repo>:<branch>
#
# Remove imports-<ORG>.tf after `stategraph tf apply` (the blocks are one-shot).
#
# Usage:
#   scripts/generate_yo61_configs.sh             # every managed repo
#   scripts/generate_yo61_configs.sh repo1 repo2 # subset (each must have YAML)
#
# Requires: gh (authenticated), yq v4, jq, bash 4+.

set -euo pipefail

ORG=yo61
DATA_DIR="data/${ORG}"
IMPORTS_FILE="imports-${ORG}.tf"

# Map a module builtin-ruleset key to the GitHub ruleset `name` it creates.
# Mirrors modules/github-repo/data/rulesets.yaml; extend when builtins are added.
declare -A RULESET_NAME=([default_branch]="Default Branch")

if [[ ! -d "${DATA_DIR}" ]]; then
  echo "error: ${DATA_DIR} not found (run from the repo root)" >&2
  exit 1
fi

# Repo list: CLI args, or every committed YAML stem excluding _-prefixed names.
if (($# > 0)); then
  repos=("$@")
else
  mapfile -t repos < <(
    find "${DATA_DIR}" -maxdepth 1 -type f -name '*.yaml' ! -name '_*' \
      -exec basename {} .yaml \; | sort
  )
fi

# Accumulate import blocks in a buffer so a mid-run failure leaves no partial file.
buffer=""
emit() {
  # $1 = resource address suffix under module.repo["<repo>"]; $2 = import id.
  buffer+=$(printf 'import {\n  to = module.org_%s.module.repo["%s"].%s\n  id = "%s"\n}\n' \
    "${ORG}" "${repo}" "$1" "$2")
  buffer+=$'\n'
}

# Read a scalar field; prints the value, or nothing if the key is absent/null.
field() { yq -r "(.${1} // \"\") | tostring" "${yaml}"; }
# True when a key is present and not null (matches the module's `!= null` gate).
has_value() { [[ "$(yq -r "has(\"${1}\") and .${1} != null" "${yaml}")" == "true" ]]; }

total=${#repos[@]}
count=0
for repo in "${repos[@]}"; do
  count=$((count + 1))
  yaml="${DATA_DIR}/${repo}.yaml"
  printf '[%d/%d] %s\n' "${count}" "${total}" "${repo}" >&2

  if [[ ! -f "${yaml}" ]]; then
    echo "error: ${yaml} not found" >&2
    exit 1
  fi

  buffer+=$(printf '# %s\n' "${repo}")
  buffer+=$'\n'

  emit "github_repository.this" "${repo}"
  emit "github_repository_collaborators.this" "${repo}"

  # Rulesets: builtin_ruleset_names defaults to [default_branch] when absent.
  if [[ "$(yq -r 'has("builtin_ruleset_names")' "${yaml}")" == "true" ]]; then
    mapfile -t ruleset_keys < <(yq -r '.builtin_ruleset_names[]' "${yaml}")
  else
    ruleset_keys=(default_branch)
  fi
  if ((${#ruleset_keys[@]} > 0)); then
    rulesets_json=$(gh api "repos/${ORG}/${repo}/rulesets" 2>/dev/null || echo '[]')
    for key in "${ruleset_keys[@]}"; do
      gh_name=${RULESET_NAME[${key}]:-}
      if [[ -z "${gh_name}" ]]; then
        echo "warn: ${repo}: no GitHub name mapped for ruleset key '${key}'; skipping" >&2
        continue
      fi
      ruleset_id=$(jq -r --arg n "${gh_name}" 'map(select(.name == $n)) | .[0].id // empty' <<<"${rulesets_json}")
      if [[ -z "${ruleset_id}" ]]; then
        echo "warn: ${repo}: ruleset '${gh_name}' not found on GitHub; will be created, not imported" >&2
        continue
      fi
      emit "github_repository_ruleset.this[\"${key}\"]" "${repo}:${ruleset_id}"
    done
  fi

  has_value vulnerability_alerts &&
    emit 'github_repository_vulnerability_alerts.this["this"]' "${repo}"
  has_value dependabot_security_updates &&
    emit 'github_repository_dependabot_security_updates.this["this"]' "${repo}"
  has_value pages &&
    emit 'github_repository_pages.this["pages"]' "${repo}"

  if [[ "$(field create_default_branch)" == "true" ]]; then
    branch=$(field default_branch)
    branch=${branch:-main}
    emit 'github_branch.this["default"]' "${repo}:${branch}"
    emit 'github_branch_default.this["default"]' "${repo}"
  fi

  if [[ "$(field apply_default_branch_protection)" == "true" ]]; then
    branch=$(field default_branch)
    branch=${branch:-main}
    emit "github_branch_protection.this[\"${branch}\"]" "${repo}:${branch}"
  fi
done

{
  printf '# Generated by scripts/generate_yo61_configs.sh\n'
  printf '# Imports every managed %s repo and its terraform resources into state.\n' "${ORG}"
  printf '# Remove this file after running stategraph tf apply tfplan.json.\n\n'
  printf '%s' "${buffer}"
} >"${IMPORTS_FILE}"

echo "Done. ${total} repos. Imports written to ${IMPORTS_FILE}." >&2
