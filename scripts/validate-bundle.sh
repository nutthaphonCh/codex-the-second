#!/usr/bin/env bash
# Checks that a generated .app bundle is well formed.
#
#   ./scripts/validate-bundle.sh "dist/Codex Personal.app"
#
# Run by CI so a broken bundle fails the build rather than reaching a release.
set -euo pipefail

APP_BUNDLE="${1:?usage: validate-bundle.sh <path-to-.app>}"
failures=0

check() {
  local description="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "  ok    ${description}"
  else
    echo "  FAIL  ${description}"
    failures=$((failures + 1))
  fi
}

echo "==> Validating ${APP_BUNDLE}"

EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/CodexTheSecond"
INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"

check "bundle exists"                test -d "${APP_BUNDLE}"
check "executable exists"            test -x "${EXECUTABLE}"
check "Info.plist is valid"          plutil -lint "${INFO_PLIST}"
check "profile.json is present"      test -f "${APP_BUNDLE}/Contents/Resources/profile.json"
# plutil -lint only accepts property lists; -convert validates JSON.
check "profile.json is valid JSON"   plutil -convert json -o /dev/null "${APP_BUNDLE}/Contents/Resources/profile.json"
check "icon is present"              test -f "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
check "code signature is valid"      codesign --verify --strict "${APP_BUNDLE}"

for key in CFBundleIdentifier CFBundleName CFBundleExecutable CFBundleShortVersionString CFBundleIconFile; do
  check "Info.plist has ${key}"      plutil -extract "${key}" raw -o - "${INFO_PLIST}"
done

# The launcher must never claim to be Codex itself.
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "${INFO_PLIST}")"
if [[ "${BUNDLE_ID}" == com.openai.* ]]; then
  echo "  FAIL  bundle identifier must not impersonate Codex (${BUNDLE_ID})"
  failures=$((failures + 1))
else
  echo "  ok    bundle identifier is our own (${BUNDLE_ID})"
fi

# Codex itself must never be redistributed inside the launcher.
SIZE_KB="$(du -sk "${APP_BUNDLE}" | cut -f1)"
if (( SIZE_KB > 20480 )); then
  echo "  FAIL  bundle is ${SIZE_KB}KB; it should contain only the launcher"
  failures=$((failures + 1))
else
  echo "  ok    bundle is ${SIZE_KB}KB (launcher only, Codex not bundled)"
fi

# Alerts are suppressed so a failure path cannot block on a modal dialog here.
export CODEX_THE_SECOND_NO_ALERTS=1

echo "  ..    --version reports: $("${EXECUTABLE}" --version)"

# With Codex pinned to a path that does not exist, the launcher must fail
# cleanly and explain itself rather than hanging or exiting silently.
set +e
output="$(CODEX_THE_SECOND_CODEX_APP=/nonexistent/Codex.app "${EXECUTABLE}" --print-plan 2>&1)"
status=$?
set -e
if [[ ${status} -ne 0 && "${output}" == *"Codex could not be found"* ]]; then
  echo "  ok    missing Codex is reported, not ignored"
else
  echo "  FAIL  missing Codex should exit non-zero with an explanation (exit ${status})"
  echo "${output}" | sed 's/^/        /'
  failures=$((failures + 1))
fi

if (( failures > 0 )); then
  echo "==> ${failures} check(s) failed"
  exit 1
fi
echo "==> All checks passed"
