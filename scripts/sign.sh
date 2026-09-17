#!/usr/bin/env bash
# Code-signs a built .app bundle.
#
# Signing configuration is kept out of the normal build so that compilation
# never depends on certificates being present.
#
#   CODESIGN_IDENTITY   Signing identity. Defaults to "-" (ad-hoc).
#                       Set to a "Developer ID Application: ..." identity to
#                       produce a distributable, notarizable build.
#   CODESIGN_KEYCHAIN   Optional keychain to search for the identity.
#
# Ad-hoc signatures are enough for the app to run locally, but they are not
# trusted by Gatekeeper on another machine. See README.md, "Gatekeeper".
set -euo pipefail

APP_PATH="${1:?usage: sign.sh <path-to-.app>}"
IDENTITY="${CODESIGN_IDENTITY:--}"

codesign_args=(--force --sign "${IDENTITY}")

if [[ -n "${CODESIGN_KEYCHAIN:-}" ]]; then
  codesign_args+=(--keychain "${CODESIGN_KEYCHAIN}")
fi

if [[ "${IDENTITY}" != "-" ]]; then
  # Required for notarization; meaningless (and slow) for ad-hoc signatures.
  codesign_args+=(--options runtime --timestamp)
  echo "==> Signing with identity: ${IDENTITY}"
else
  echo "==> Signing ad-hoc (no Developer ID identity configured)"
fi

# Sign inside out: a second executable in Contents/MacOS - the c2nd command -
# must carry its own signature before the bundle is sealed, or verification
# reports it as "not signed at all".
MAIN_EXECUTABLE="$(plutil -extract CFBundleExecutable raw -o - "${APP_PATH}/Contents/Info.plist")"
while IFS= read -r nested; do
  [[ "$(basename "${nested}")" == "${MAIN_EXECUTABLE}" ]] && continue
  file "${nested}" | grep -q "Mach-O" || continue
  echo "==> Signing nested executable: $(basename "${nested}")"
  codesign "${codesign_args[@]}" "${nested}"
done < <(find "${APP_PATH}/Contents/MacOS" -type f -perm -u+x)

codesign "${codesign_args[@]}" "${APP_PATH}"
codesign --verify --strict --verbose=2 "${APP_PATH}"
