#!/usr/bin/env bash
# Keeps the tested Codex build consistent across the documents that state it.
#
# tested-with.json is the single source of truth. Every document listed below
# must mention that exact build, and must not mention a different one.
#
# The earlier version of this check looked for the phrase "Codex Desktop X.Y.Z",
# which stopped matching as soon as a document put the version in a table. It
# passed while checking nothing. This matches the build number's own shape
# instead: <major>.<3 digits>.<4+ digits>, which cannot collide with a macOS
# version like 26.5.2 or a launcher version like 0.3.0.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# These must state the tested build: they are where a reader goes to find it.
MUST_STATE=(
  docs/verification.md
  knowledge/reference/upstream-behaviour-watch.md
)
# Everywhere else may stay silent - README points at tested-with.json rather
# than repeating it - but nothing may contradict it.
BUILD_SHAPE='[0-9]+\.[0-9]{3}\.[0-9]{4,}'

expected="$(plutil -extract codexDesktopVersion raw -o - tested-with.json)"
if [[ ! "${expected}" =~ ^${BUILD_SHAPE}$ ]]; then
  echo "  FAIL  tested-with.json: '${expected}' is not a Codex build number"
  exit 1
fi
echo "  ok    tested-with.json says ${expected}"

failures=0
for document in "${MUST_STATE[@]}"; do
  if [[ ! -f "${document}" ]]; then
    echo "  FAIL  ${document}: listed here but missing from the repository"
    failures=$((failures + 1))
    continue
  fi

  # bash 3.2 (what macOS ships) has no mapfile.
  found="$(grep -oE "${BUILD_SHAPE}" "${document}" | sort -u || true)"

  if [[ -z "${found}" ]]; then
    echo "  FAIL  ${document}: states no Codex build; it must name the tested one"
    failures=$((failures + 1))
    continue
  fi

  for version in ${found}; do
    if [[ "${version}" != "${expected}" ]]; then
      echo "  FAIL  ${document}: mentions Codex ${version}, tested-with.json says ${expected}"
      failures=$((failures + 1))
    fi
  done

  [[ ${failures} -eq 0 ]] && echo "  ok    ${document}"
done

# Nothing anywhere may name a different build.
while IFS= read -r document; do
  # git ls-files still lists files deleted in the working tree.
  [[ -f "${document}" ]] || continue
  found="$(grep -oE "${BUILD_SHAPE}" "${document}" | sort -u || true)"
  for version in ${found}; do
    if [[ "${version}" != "${expected}" ]]; then
      echo "  FAIL  ${document}: mentions Codex ${version}, tested-with.json says ${expected}"
      failures=$((failures + 1))
    fi
  done
done < <(git ls-files "*.md" "*.json" "*.yml" "*.swift")

if (( failures > 0 )); then
  exit 1
fi
echo "  ok    no file anywhere contradicts tested-with.json"
