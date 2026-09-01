#!/usr/bin/env bash
# Install jarvis: the CLI symlink, the mascot plugin (copied, with the
# generated sprite sheets, since the shell scans real directories), and the
# user units that keep the inbox and the pulse alive. Idempotent: running it
# again on an installed machine is the supported way to update.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user" "$HOME/.config/omarchy/plugins"
ln -sf "$PWD/bin/jarvis" "$HOME/.local/bin/omarchy-jarvis"
python3 sprites/generate.py

# The shell hot-reloads on ANY change under its plugin directories, and it
# has a use-after-free when that happens file by file (upstream #956). So
# the plugin is built whole in a staging directory — hidden, because the
# scan skips dotted names — and swapped in with two renames instead of
# three file copies.
dest="$HOME/.config/omarchy/plugins/macarchy.jarvis"
staging=$(mktemp -d "$HOME/.config/omarchy/plugins/.macarchy.jarvis.XXXXXX")
cp -r plugin/manifest.json plugin/Service.qml plugin/components "$staging/"
rm -rf "$dest.previous"
if [[ -e $dest ]]; then
	mv "$dest" "$dest.previous"
fi
mv "$staging" "$dest"
rm -rf "$dest.previous"

# The units ship with the repository path baked in; install them against the
# symlink instead, so a moved checkout only needs this script re-run. Only
# the triggers (a path watch, a timer) are enabled — the services they pull
# are oneshots, and enabling those would run them here and now.
for unit in systemd/*; do
	sed "s|^ExecStart=.*/bin/jarvis |ExecStart=$HOME/.local/bin/omarchy-jarvis |" \
		"$unit" >"$HOME/.config/systemd/user/$(basename "$unit")"
done
systemctl --user daemon-reload
for unit in systemd/*.path systemd/*.timer; do
	[[ -e $unit ]] || continue
	systemctl --user enable --now "$(basename "$unit")"
done

# The fish is generated from the soul's look settings, outside the plugin
# folder (the shell hot-reloads on changes in there).
"$PWD/bin/jarvis" look
omarchy-shell -q shell rescanPlugins

# The last word goes to the self-check: it names whatever is still missing
# (a voice model, the wake daemon, a mic) without failing the install.
echo
"$PWD/bin/jarvis" doctor || true
echo "installed; enable with: omarchy plugin enable macarchy.jarvis"
