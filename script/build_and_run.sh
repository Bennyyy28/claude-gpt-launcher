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
BACKEND_DIR="$APP_RESOURCES/backend"
BACKEND_BINARY="$BACKEND_DIR/claude-gpt"
INSTALL_BUNDLE="$HOME/Applications/$APP_NAME.app"

cd "$ROOT_DIR"
/usr/bin/swift build
/usr/bin/swift test
BUILD_BINARY="$(/usr/bin/swift build --show-bin-path)/$APP_PROCESS"
BUILD_MCP_BINARY="$(/usr/bin/swift build --show-bin-path)/ClaudeGPTMCP"

/bin/rm -rf "$APP_BUNDLE"
/bin/mkdir -p "$APP_MACOS" "$MCP_DIR" "$BACKEND_DIR"
/bin/cp "$BUILD_BINARY" "$APP_BINARY"
/bin/cp "$BUILD_MCP_BINARY" "$MCP_BINARY"
/bin/cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
/bin/cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
/bin/cp "$ROOT_DIR/script/claude-gpt" "$BACKEND_BINARY"
/bin/chmod 755 "$APP_BINARY" "$MCP_BINARY" "$BACKEND_BINARY"
/usr/bin/xattr -cr "$APP_BUNDLE"
/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"

open_app() {
  /usr/bin/open "$APP_BUNDLE"
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
    /bin/mkdir -p "$HOME/Applications"
    if [[ -e "$INSTALL_BUNDLE" ]]; then
      EXISTING_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INSTALL_BUNDLE/Contents/Info.plist" 2>/dev/null || true)"
      if [[ "$EXISTING_IDENTIFIER" != "app.claudegpt.launcher" ]]; then
        echo "refusing to replace unrelated application: $INSTALL_BUNDLE" >&2
        exit 1
      fi
      if /usr/bin/pgrep -x "$APP_PROCESS" >/dev/null; then
        echo "refusing to replace a running $APP_NAME app; quit it and retry" >&2
        exit 1
      fi
    fi
    /bin/rm -rf "$INSTALL_BUNDLE"
    /usr/bin/ditto "$APP_BUNDLE" "$INSTALL_BUNDLE"
    /usr/bin/open "$INSTALL_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--install]" >&2
    exit 2
    ;;
esac
