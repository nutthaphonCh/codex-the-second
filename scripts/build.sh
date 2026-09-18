#!/usr/bin/env bash
# Builds a profile launcher .app bundle from a profile configuration.
#
#   ./scripts/build.sh                      -> dist/Codex the 2nd.app
#   ./scripts/build.sh --profile work       -> dist/Codex Work.app
#
# Options:
#   --profile <slug>    Profile in profiles/<slug>.json. Default: personal.
#   --output <dir>      Output directory. Default: dist.
#   --arch <value>      universal (default), arm64 or x86_64.
#   --version <x.y.z>   Version string. Default: contents of VERSION.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO_ROOT="$PWD"

PROFILE_SLUG="2nd"
OUTPUT_DIR="dist"
ARCH="universal"
VERSION="$(tr -d '[:space:]' < VERSION)"
# Deployment target; must match Package.swift's platforms declaration.
MACOS_MIN="12.0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE_SLUG="$2"; shift 2 ;;
    --output)  OUTPUT_DIR="$2";   shift 2 ;;
    --arch)    ARCH="$2";         shift 2 ;;
    --version) VERSION="$2";      shift 2 ;;
    -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

PROFILE_FILE="profiles/${PROFILE_SLUG}.json"
if [[ ! -f "${PROFILE_FILE}" ]]; then
  echo "No such profile: ${PROFILE_FILE}" >&2
  echo "Available:" >&2
  ls profiles/*.json 2>/dev/null >&2 || true
  exit 1
fi

# Profile values are read with plutil, which parses JSON natively, so the build
# needs nothing beyond the Apple toolchain.
read_profile() { plutil -extract "$1" raw -o - "${PROFILE_FILE}" 2>/dev/null || echo "$2"; }

APP_NAME="$(read_profile appName "")"
BUNDLE_ID="$(read_profile bundleIdentifier "")"
ICON_LABEL="$(read_profile icon.label "CP")"
ICON_TOP="$(read_profile icon.tintTop "#7C5CFF")"
ICON_BOTTOM="$(read_profile icon.tintBottom "#2A1B6B")"

if [[ -z "${APP_NAME}" || -z "${BUNDLE_ID}" ]]; then
  echo "Profile ${PROFILE_FILE} is missing appName or bundleIdentifier" >&2
  exit 1
fi

echo "==> Building ${APP_NAME} ${VERSION} (${ARCH}) from ${PROFILE_FILE}"

# ---------------------------------------------------------------------------
# Compile
# ---------------------------------------------------------------------------

# Builds one architecture into its own scratch directory. The resulting binary
# is always at <scratch>/release/CodexTheSecond.
build_slice() {
  local arch="$1" scratch="$2"
  echo "==> Compiling ${arch}"
  swift build -c release --scratch-path "${scratch}" \
    -Xswiftc -target -Xswiftc "${arch}-apple-macosx${MACOS_MIN}" \
    -Xlinker -platform_version -Xlinker macos -Xlinker "${MACOS_MIN}" -Xlinker "${MACOS_MIN}"
}

BUILD_DIR="${REPO_ROOT}/.build"
case "${ARCH}" in
  universal)
    build_slice arm64  "${BUILD_DIR}/arm64"
    build_slice x86_64 "${BUILD_DIR}/x86_64"
    mkdir -p "${BUILD_DIR}/universal"
    # `swift build --arch a --arch b` needs a full Xcode installation; lipo
    # over two single-arch builds works with Command Line Tools alone.
    for product in CodexTheSecond c2nd; do
      lipo -create \
        "${BUILD_DIR}/arm64/release/${product}" \
        "${BUILD_DIR}/x86_64/release/${product}" \
        -output "${BUILD_DIR}/universal/${product}"
    done
    BINARY="${BUILD_DIR}/universal/CodexTheSecond"
    CLI_BINARY="${BUILD_DIR}/universal/c2nd"
    ;;
  arm64|x86_64)
    build_slice "${ARCH}" "${BUILD_DIR}/${ARCH}"
    BINARY="${BUILD_DIR}/${ARCH}/release/CodexTheSecond"
    CLI_BINARY="${BUILD_DIR}/${ARCH}/release/c2nd"
    ;;
  *)
    echo "Unsupported --arch: ${ARCH} (expected universal, arm64 or x86_64)" >&2
    exit 2
    ;;
esac

# ---------------------------------------------------------------------------
# Assemble the bundle
# ---------------------------------------------------------------------------

APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/CodexTheSecond"
chmod +x "${APP_BUNDLE}/Contents/MacOS/CodexTheSecond"

# The c2nd command ships inside the bundle rather than as a loose file in the
# DMG, so drag-to-Applications stays the only install step. It reads the version
# from this same Info.plist, and drives every installed profile, not just this
# one. README documents the one-line symlink that puts it on PATH.
cp "${CLI_BINARY}" "${APP_BUNDLE}/Contents/MacOS/c2nd"
chmod +x "${APP_BUNDLE}/Contents/MacOS/c2nd"

# The profile is the launcher's only configuration: it is read back at runtime
# from Contents/Resources/profile.json.
cp "${PROFILE_FILE}" "${APP_BUNDLE}/Contents/Resources/profile.json"

echo "==> Generating icon"
swift scripts/make-icon.swift \
  --label "${ICON_LABEL}" \
  --top "${ICON_TOP}" \
  --bottom "${ICON_BOTTOM}" \
  --output "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" > /dev/null

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>${APP_NAME}</string>
	<key>CFBundleExecutable</key>
	<string>CodexTheSecond</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>${BUNDLE_ID}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>${APP_NAME}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${VERSION}</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.developer-tools</string>
	<key>LSMinimumSystemVersion</key>
	<string>${MACOS_MIN}</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Independent utility. Not affiliated with or endorsed by OpenAI.</string>
</dict>
</plist>
PLIST

plutil -lint "${APP_BUNDLE}/Contents/Info.plist" > /dev/null

"${REPO_ROOT}/scripts/sign.sh" "${APP_BUNDLE}"

echo "==> Built ${APP_BUNDLE}"
lipo -info "${APP_BUNDLE}/Contents/MacOS/CodexTheSecond" 2>/dev/null || true
