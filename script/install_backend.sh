#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/script/claude-gpt"
INSTALL_DIR="$HOME/.local/bin"
DESTINATION="$INSTALL_DIR/claude-gpt"

if [[ -e "$DESTINATION" ]] && ! /usr/bin/grep -q '^# Installed by claude-gpt-launcher$' "$DESTINATION"; then
  echo "Refusing to overwrite unrelated file: $DESTINATION" >&2
  exit 1
fi

/usr/bin/install -d -m 700 "$INSTALL_DIR"
/usr/bin/install -m 700 "$SOURCE" "$DESTINATION"
echo "Installed $DESTINATION"

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) echo "Add $INSTALL_DIR to PATH to run claude-gpt directly." ;;
esac
