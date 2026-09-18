#!/usr/bin/env bash
# Packages a built .app into distributable artifacts.
#
#   ./scripts/package.sh                 -> dist/Codex-the-2nd-v0.2.0.dmg
#                                           dist/Codex-the-2nd-v0.2.0.zip
#                                           dist/SHA256SUMS.txt
#
# The DMG contains the launcher and an Applications symlink, so installing is
# the normal macOS drag-to-Applications flow. Codex itself is never bundled:
# these artifacts contain only this launcher utility.
#
# Options:
#   --profile <slug>   Profile to package. Default: personal.
#   --output <dir>     Directory holding the built .app. Default: dist.
#   --version <x.y.z>  Version string. Default: contents of VERSION.
#   --skip-build       Package an existing .app instead of rebuilding.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PROFILE_SLUG="2nd"
OUTPUT_DIR="dist"
VERSION="$(tr -d '[:space:]' < VERSION)"
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)    PROFILE_SLUG="$2"; shift 2 ;;
    --output)     OUTPUT_DIR="$2";   shift 2 ;;
    --version)    VERSION="$2";      shift 2 ;;
    --skip-build) SKIP_BUILD=1;      shift ;;
    -h|--help)    sed -n '2,16p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  ./scripts/build.sh --profile "${PROFILE_SLUG}" --output "${OUTPUT_DIR}" --version "${VERSION}"
fi

APP_NAME="$(plutil -extract appName raw -o - "profiles/${PROFILE_SLUG}.json")"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

if [[ ! -d "${APP_BUNDLE}" ]]; then
  echo "No built app at ${APP_BUNDLE}. Run scripts/build.sh first." >&2
  exit 1
fi

ARTIFACT_BASE="Codex-the-2nd-v${VERSION}"
DMG_PATH="${OUTPUT_DIR}/${ARTIFACT_BASE}.dmg"
ZIP_PATH="${OUTPUT_DIR}/${ARTIFACT_BASE}.zip"

# ---------------------------------------------------------------------------
# DMG
# ---------------------------------------------------------------------------

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "${STAGING_DIR}"' EXIT

echo "==> Staging disk image contents"
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "==> Creating ${DMG_PATH}"
rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  -quiet \
  "${DMG_PATH}"

# ---------------------------------------------------------------------------
# ZIP (secondary artifact)
# ---------------------------------------------------------------------------

echo "==> Creating ${ZIP_PATH}"
rm -f "${ZIP_PATH}"
# ditto preserves the bundle's symlinks, resource forks and code signature.
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

# ---------------------------------------------------------------------------
# Checksums
# ---------------------------------------------------------------------------

echo "==> Writing checksums"
(
  cd "${OUTPUT_DIR}"
  shasum -a 256 "${ARTIFACT_BASE}.dmg" "${ARTIFACT_BASE}.zip" > SHA256SUMS.txt
)

echo "==> Artifacts"
ls -lh "${DMG_PATH}" "${ZIP_PATH}" "${OUTPUT_DIR}/SHA256SUMS.txt"
cat "${OUTPUT_DIR}/SHA256SUMS.txt"
