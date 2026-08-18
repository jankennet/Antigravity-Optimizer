#!/usr/bin/env bash
# One-liner installer — see README.md for the raw curl command.
set -e
DEST="${1:-$HOME/.local/bin/antigravity-lowend}"
mkdir -p "$(dirname "$DEST")"
curl -fsSL https://raw.githubusercontent.com/jankennet/Antigravity-Optimizer/main/antigravity-lowend.sh -o "$DEST"
chmod +x "$DEST"
echo "Installed to $DEST"
echo "Make sure $(dirname "$DEST") is in your PATH, then run: antigravity-lowend"