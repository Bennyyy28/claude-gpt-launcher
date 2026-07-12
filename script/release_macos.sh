#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Claude GPT"
APP_PROCESS="ClaudeGPTLauncher"
MCP_PROCESS="ClaudeGPTMCP"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$ROOT_DIR/Resources/Info.plist")"
RELEASE_DIR="$ROOT_DIR/dist/release"
STAGE_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/claude-gpt-release.XXXXXX")"
trap '/bin/rm -rf "$STAGE_DIR"' EXIT
APP_BUNDLE="$STAGE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_PROCESS"
MCP_BINARY="$APP_CONTENTS/Resources/mcp-bin/claude-gpt-mcp"
BACKEND_BINARY="$APP_CONTENTS/Resources/backend/claude-gpt"
ARCHIVE="$RELEASE_DIR/Claude-GPT-Launcher-$VERSION-macOS-arm64.zip"
CHECKSUM="$ARCHIVE.sha256"
SUBMISSION_ARCHIVE="$STAGE_DIR/$(basename "$ARCHIVE")"

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to a Developer ID Application identity.}"
: "${NOTARYTOOL_PROFILE:?Set NOTARYTOOL_PROFILE to a Keychain profile created by notarytool store-credentials.}"

cd "$ROOT_DIR"
/usr/bin/swift test
/usr/bin/swift build -c release
BIN_DIR="$(/usr/bin/swift build -c release --show-bin-path)"

/bin/rm -rf "$RELEASE_DIR"
/bin/mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources/mcp-bin" "$APP_CONTENTS/Resources/backend"
/bin/cp "$BIN_DIR/$APP_PROCESS" "$APP_BINARY"
/bin/cp "$BIN_DIR/$MCP_PROCESS" "$MCP_BINARY"
/bin/cp Resources/Info.plist "$APP_CONTENTS/Info.plist"
/bin/cp Resources/AppIcon.icns "$APP_CONTENTS/Resources/AppIcon.icns"
/bin/cp script/claude-gpt "$BACKEND_BINARY"
/bin/chmod 755 "$APP_BINARY" "$MCP_BINARY" "$BACKEND_BINARY"
/usr/bin/xattr -cr "$APP_BUNDLE"

# Sign inside-out. Hardened runtime and a secure timestamp are required for notarization.
/usr/bin/codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$MCP_BINARY"
/usr/bin/xattr -cr "$APP_BUNDLE"
/usr/bin/codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$SUBMISSION_ARCHIVE"
/usr/bin/xcrun notarytool submit "$SUBMISSION_ARCHIVE" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
/usr/bin/xcrun stapler staple "$APP_BUNDLE"
/usr/bin/xcrun stapler validate "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/usr/sbin/spctl --assess --type execute --verbose=4 "$APP_BUNDLE"

# Rebuild the archive so the distributed copy contains the stapled ticket.
/bin/rm -f "$ARCHIVE" "$CHECKSUM"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ARCHIVE"
(
  cd "$RELEASE_DIR"
  /usr/bin/shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"
)

echo "Notarized release: $ARCHIVE"
echo "Checksum: $CHECKSUM"
