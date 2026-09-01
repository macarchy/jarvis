#!/usr/bin/env bash
# Install jarvis: the CLI symlink, and the mascot plugin (copied, with the
# generated sprite sheets, since the shell scans real directories).
set -euo pipefail
cd "$(dirname "$0")"
ln -sf "$PWD/bin/jarvis" "$HOME/.local/bin/omarchy-jarvis"
python3 sprites/generate.py
dest="$HOME/.config/omarchy/plugins/macarchy.jarvis"
mkdir -p "$dest/assets"
cp -r plugin/manifest.json plugin/Service.qml plugin/components "$dest/"
# The fish is generated from the soul's look settings (default look here).
python3 sprites/generate.py --out "$dest/assets"
omarchy-shell -q shell rescanPlugins
echo "installed; enable with: omarchy plugin enable macarchy.jarvis"
