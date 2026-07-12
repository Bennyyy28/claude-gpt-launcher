#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_PROCESS="ClaudeGPTLauncher"
APP_NAME="Claude GPT"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_PROCESS"
APP_RESOURCES="$APP_CONTENTS/Resources"
MCP_DIR="$APP_RESOURCES/mcp-bin"
MCP_BINARY="$MCP_DIR/claude-gpt-mcp"
INSTALL_BUNDLE="$HOME/Applications/$APP_NAME.app"

pkill -x "$APP_PROCESS" >/dev/null 2>&1 || true

cd "$ROOT_DIR"
swift build
swift test
BUILD_BINARY="$(swift build --show-bin-path)/$APP_PROCESS"
BUILD_MCP_BINARY="$(swift build --show-bin-path)/ClaudeGPTMCP"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$MCP_DIR"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$BUILD_MCP_BINARY" "$MCP_BINARY"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
chmod 755 "$APP_BINARY" "$MCP_BINARY"
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == '$APP_PROCESS'"
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == 'app.claudegpt.launcher'"
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_PROCESS" >/dev/null
    ;;
  --install|install)
    mkdir -p "$HOME/Applications"
    rm -rf "$INSTALL_BUNDLE"
    ditto "$APP_BUNDLE" "$INSTALL_BUNDLE"
    /usr/bin/open -n "$INSTALL_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--install]" >&2
    exit 2
    ;;
esac
