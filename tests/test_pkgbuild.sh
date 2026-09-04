#!/bin/bash
# tests/test_pkgbuild.sh — the package is the program, not the voices.
#
# jarvis needs Piper voices, wake models and a python venv that install.sh
# fetches. Shipping them makes a fat package that still needs the network for
# the rest, so they stay out and the scriptlet names the setup step.
# macarchy-install#17.
set -uo pipefail
cd "$(dirname "$0")/.."

fails=0
check() { local name=$1; shift; if "$@"; then echo "ok   $name"; else echo "FAIL $name"; fails=$((fails+1)); fi; }
# Comments name every artefact, so a whole-file grep passes even when the line is
# gone. Read the code.
code() { grep -v '^[[:space:]]*#' PKGBUILD; }

check "the tree ships where bin/jarvis looks" grep -q 'usr/share/\$pkgname' <(code)
check "one entry point on PATH"               grep -q 'ln -sf "/usr/share/\$pkgname/bin/jarvis"' <(code)
check "the venv is never shipped"             grep -q 'rm -rf "\$pkgdir/usr/share/\$pkgname/wake/venv"' <(code)
check "no voices in the package"              bash -c '! grep -qE "piper/|\.onnx" <(grep -v "^[[:space:]]*#" PKGBUILD)'
check "the units are repointed off %h"        grep -q "sed 's|\^ExecStart=.\*/bin/jarvis " <(code)
check "and the rewrite is checked"            grep -q "grep -q '\^ExecStart=/usr/bin/jarvis '" <(code)
check "the shipped unit really bakes a path"  grep -q '%h/Work/jarvis' systemd/jarvis-tick.service

# bin/jarvis must be able to find its tree from /usr/bin, where "one level up"
# is /usr and holds nothing of ours.
check "the launcher searches for its tree"    grep -q '/usr/share/jarvis' bin/jarvis
check "and JARVIS_DIR overrides"              grep -q 'JARVIS_DIR:-' bin/jarvis
check "and it fails loudly, not with 41 empty paths" \
  grep -q 'cannot find the jarvis tree' bin/jarvis

check "the scriptlet names the setup step"    grep -q 'jarvis setup' jarvis.install
check "and where the plugin goes"             grep -q 'omarchy/plugins' jarvis.install

# The workflow lessons from macarchy-install#16, each a real failure there.
WF=.github/workflows/release-please.yml
check "no standalone package workflow"    [ ! -e .github/workflows/package.yml ]
check "the job hangs off release_created" grep -q 'release_created' "$WF"
check "not a release: published trigger"  bash -c '! grep -q "types: \[published\]" '"$WF"
check "pkgver is rewritten from the tag"  grep -q 'pkgver=\${TAG#v}' "$WF"
check "extra-files is not used"           bash -c '! grep -q "extra-files" release-please-config.json'
check "the upload globs"                  grep -q '\*.pkg.tar.\*' "$WF"
check "gh is installed in the container"  grep -q 'github-cli' "$WF"

(( fails == 0 )) && echo "all ok" || echo "$fails failed"
exit $(( fails > 0 ))
