# Maintainer: Philippe Matray <phmatray@gmail.com>
#
# The program, not the voices. jarvis needs Piper voices, wake models and a
# python venv that install.sh fetches; shipping them would make a fat package
# that still needs the network for the rest, so they stay out and the scriptlet
# names the setup step. A voice assistant that cannot reach the network has
# bigger problems than a missing package. macarchy-install#17.
pkgname=jarvis
# Rewritten from the tag by the packaging job before makepkg runs. This value is
# the fallback for a manual makepkg from a checkout.
pkgver=1.4.0
pkgrel=1
pkgdesc="A bilingual voice assistant for Linux: Whisper transcribes locally, Claude thinks, the shell is its hands"
arch=('any')
url="https://github.com/macarchy/jarvis"
license=('MIT')
install=jarvis.install
depends=('bash' 'python' 'pipewire' 'jq')
optdepends=('piper-tts: speech synthesis'
            'claude-code: the brain'
            'macarchy-touchbar: the mascot on the Touch Bar'
            'omarchy: the Control Center page and the bar')
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
  cd "$srcdir/$pkgname-$pkgver"

  # bin/jarvis resolves its tree relative to itself, so the tree has to exist
  # somewhere it can find: /usr/share/jarvis is the third candidate it tries.
  install -d "$pkgdir/usr/share/$pkgname"
  cp -r bin assets sprites memory plugin wake "$pkgdir/usr/share/$pkgname/"
  install -Dm644 SOUL.md "$pkgdir/usr/share/$pkgname/SOUL.md"
  install -Dm644 voxtype.toml "$pkgdir/usr/share/$pkgname/voxtype.toml"
  # the venv is built by the setup step, never shipped
  rm -rf "$pkgdir/usr/share/$pkgname/wake/venv"

  # One entry point on PATH; everything else is reached through JARVIS_DIR.
  install -d "$pkgdir/usr/bin"
  ln -sf "/usr/share/$pkgname/bin/jarvis" "$pkgdir/usr/bin/jarvis"

  # The units bake %h/Work/jarvis/bin/jarvis -- install.sh rewrites them to the
  # symlink it makes in $HOME. A package writes nothing there, so they point at
  # /usr/bin instead, and the build fails if the rewrite did not land.
  local u
  for u in systemd/*; do
    sed 's|^ExecStart=.*/bin/jarvis |ExecStart=/usr/bin/jarvis |' "$u" \
      > "$srcdir/$(basename "$u").pkg"
    install -Dm644 "$srcdir/$(basename "$u").pkg" \
      "$pkgdir/usr/lib/systemd/user/$(basename "$u")"
  done
  grep -q '^ExecStart=/usr/bin/jarvis ' "$pkgdir/usr/lib/systemd/user/jarvis-tick.service"

  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
}
