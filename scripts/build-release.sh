#!/bin/bash
# Builds a universal (Apple Silicon + Intel) Release of CENTRO and packages it
# as dist/CENTRO-<version>.zip and dist/CENTRO-<version>.dmg, ready to attach
# to a GitHub Release.
#
# Usage: ./scripts/build-release.sh
#
# Without an Apple Developer ID the app is ad-hoc signed: users have to allow
# it once in System Settings > Privacy & Security (see README).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
# Build outside the repo: folders synced by iCloud add extended attributes that break codesign.
BUILD="${TMPDIR:-/tmp}/centro-release-build"
DIST="$ROOT/dist"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

VERSION=$(grep -m1 "MARKETING_VERSION" CENTRO.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);/\1/')
echo "==> Building CENTRO $VERSION"

rm -rf "$BUILD" "$DIST"
mkdir -p "$DIST"

xcodebuild -project CENTRO.xcodeproj -scheme CENTRO -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$BUILD" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
  build | grep -E "error:|warning: |BUILD" || true

APP="$BUILD/Build/Products/Release/CENTRO.app"
[ -d "$APP" ] || { echo "Build failed"; exit 1; }

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
lipo -info "$APP/Contents/MacOS/CENTRO"

echo "==> Packaging"
ditto -c -k --keepParent "$APP" "$DIST/CENTRO-$VERSION.zip"

STAGE="$BUILD/dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE"
ditto "$APP" "$STAGE/CENTRO.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "CENTRO" -srcfolder "$STAGE" -ov -format UDZO "$DIST/CENTRO-$VERSION.dmg" >/dev/null

(cd "$DIST" && shasum -a 256 * > SHA256SUMS.txt)
echo "==> Done"
ls -lh "$DIST"
