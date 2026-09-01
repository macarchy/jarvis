#!/usr/bin/env bash
# bootstrap.sh — fetch everything a clone cannot carry.
#
# The repository tracks 500 KB of source. The things that make it speak are
# 300 MB of binaries and neural weights that belong to other projects, so
# they are downloaded here instead of vendored: the Piper synthesizer, its
# voices, and the Whisper model the transcriber loads. Nothing here needs
# root, everything lands inside the checkout or under ~/.local/share, and
# running it twice is a no-op — it only fetches what is missing.
#
#   ./bootstrap.sh                 the two voices Jarvis actually speaks
#   ./bootstrap.sh --all-voices    plus the two French alternates
#   ./bootstrap.sh --skip-wake     no « Hey Jarvis » (skips a 200 MB venv)
#   ./bootstrap.sh --skip-whisper  you already have a Whisper model
#
# Then run ./install.sh, which wires the pieces into the desktop.
set -euo pipefail
cd "$(dirname "$0")"

PIPER_VERSION="v1.2.0"
WHISPER_MODEL="ggml-small.bin"          # matches `model = "small"` in voxtype.toml
WHISPER_DIR="$HOME/.local/share/voxtype/models"

all_voices=0 skip_wake=0 skip_whisper=0
for arg in "$@"; do
	case "$arg" in
	--all-voices) all_voices=1 ;;
	--skip-wake) skip_wake=1 ;;
	--skip-whisper) skip_whisper=1 ;;
	-h | --help)
		sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "bootstrap: unknown option $arg (try --help)" >&2
		exit 1
		;;
	esac
done

say() { printf '\n\033[1m▸ %s\033[0m\n' "$*"; }
skip() { printf '  · %s\n' "$*"; }

need() {
	command -v "$1" >/dev/null || {
		echo "bootstrap: $1 is required and not installed" >&2
		exit 1
	}
}
need curl
need tar
need python3

# Resumable, fails loudly, and never leaves a half file behind under the real
# name — a truncated .onnx is the one failure mode that looks like a working
# install right up until Jarvis is silent.
fetch() {
	local url="$1" dest="$2"
	mkdir -p "$(dirname "$dest")"
	if ! curl -fL --progress-bar -C - -o "$dest.part" "$url"; then
		rm -f "$dest.part"
		echo "bootstrap: download failed — $url" >&2
		exit 1
	fi
	mv "$dest.part" "$dest"
}

# ------------------------------------------------------------------ piper

say "Piper $PIPER_VERSION — the voice"
if [[ -x piper/piper ]]; then
	skip "piper/piper is already here"
else
	case "$(uname -m)" in
	aarch64 | arm64) asset="piper_arm64.tar.gz" ;;
	x86_64 | amd64) asset="piper_amd64.tar.gz" ;;
	*)
		echo "bootstrap: no Piper build for $(uname -m); build it from" >&2
		echo "           https://github.com/rhasspy/piper and put it in piper/" >&2
		exit 1
		;;
	esac
	fetch "https://github.com/rhasspy/piper/releases/download/$PIPER_VERSION/$asset" "/tmp/$asset"
	# The tarball's top-level directory is already `piper/`.
	tar -xzf "/tmp/$asset" -C .
	rm -f "/tmp/$asset"
	[[ -x piper/piper ]] || { echo "bootstrap: piper/piper missing after extraction" >&2; exit 1; }
fi

# ------------------------------------------------------------------ voices
#
# Two voices are what Jarvis speaks: French for a French reply, English for an
# English one. The other two French voices are alternates you can point
# VOICE_FR at in bin/jarvis; they are not downloaded unless asked for.

say "Voices — rhasspy/piper-voices"
voices=(
	"fr/fr_FR/tom/medium/fr_FR-tom-medium"
	"en/en_GB/alan/medium/en_GB-alan-medium"
)
((all_voices)) && voices+=(
	"fr/fr_FR/siwis/medium/fr_FR-siwis-medium"
	"fr/fr_FR/upmc/medium/fr_FR-upmc-medium"
)
for path in "${voices[@]}"; do
	name=$(basename "$path")
	if [[ -s models/$name.onnx && -s models/$name.onnx.json ]]; then
		skip "$name"
		continue
	fi
	printf '  %s\n' "$name"
	base="https://huggingface.co/rhasspy/piper-voices/resolve/main/$path"
	fetch "$base.onnx" "models/$name.onnx"
	fetch "$base.onnx.json" "models/$name.onnx.json"
done

# ----------------------------------------------------------------- whisper

say "Whisper — the ear"
if ((skip_whisper)); then
	skip "skipped (--skip-whisper)"
elif [[ -s $WHISPER_DIR/$WHISPER_MODEL ]]; then
	skip "$WHISPER_MODEL is already in $WHISPER_DIR"
else
	echo "  $WHISPER_MODEL — 488 MB, this is the long one"
	fetch "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$WHISPER_MODEL" \
		"$WHISPER_DIR/$WHISPER_MODEL"
fi

# -------------------------------------------------------------------- wake
#
# The wake daemon gets its own virtualenv rather than the system Python:
# openWakeWord pins an onnxruntime that has no business being installed
# system-wide, and the whole thing is optional — without it Jarvis still
# answers the key, he just cannot be summoned by name.

say "« Hey Jarvis » — the ears that never close"
if ((skip_wake)); then
	skip "skipped (--skip-wake); the push-to-talk key still works"
elif [[ -x wake/venv/bin/python ]]; then
	skip "wake/venv is already here"
else
	python3 -m venv wake/venv
	wake/venv/bin/pip install --quiet --upgrade pip
	wake/venv/bin/pip install --quiet openwakeword onnxruntime numpy scikit-learn joblib
	# openWakeWord ships its models separately from the wheel.
	wake/venv/bin/python -c "import openwakeword.utils as u; u.download_models()"
fi

# ------------------------------------------------------------------- ready

say "Ready"
cat <<'EOF'
  Next:  ./install.sh          the CLI, the mascot plugin, the user units
         omarchy-jarvis doctor what is still missing, in one screen

  Not fetched, because they are yours to install and configure:
    claude    the brain    — https://claude.com/claude-code  (needs an account)
    voxtype   the ear      — https://voxtype.io
EOF
