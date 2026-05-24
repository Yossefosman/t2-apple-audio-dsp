# Maintainer: lemmyg <lemmygl@protonmail.com>
# Contributor: T2 Linux Kernel Team
#
# Build from local checkout:
#   cd t2-apple-audio-dsp
#   makepkg -p arch/PKGBUILD -i
#
# Or adapt for AUR by pointing source at a release tarball.

pkgname=t2-apple-audio-dsp
pkgver=1.0.1
pkgrel=1
pkgdesc="Pipewire/Wireplumber userspace audio DSP configuration for Apple T2 Macs"
arch=('any')
url="https://github.com/lemmyg/t2-apple-audio-dsp"
license=('MIT')
depends=(
  'pipewire'
  'wireplumber'
  'lsp-plugins-lv2'
  'swh-lv2'
  'bankstown-lv2'
  'triforce-lv2'
)
makedepends=()
install="${pkgname}.install"
source=()
sha256sums=()

package() {
  # Install FIRs, DSP graphs, and Lua scripts for all models
  for model in 16_1 16_4 9_1; do
    install -dm755 "${pkgdir}/usr/share/t2-linux-audio/${model}"
    cp -r "${startdir}/firs/${model}"/* "${pkgdir}/usr/share/t2-linux-audio/${model}/"
  done

  # Install Wireplumber config files for all models
  for model in 16_1 16_4 9_1; do
    install -dm755 "${pkgdir}/usr/share/t2-apple-audio-dsp/config/${model}"
    cp -r "${startdir}/config/${model}"/* "${pkgdir}/usr/share/t2-apple-audio-dsp/config/${model}/"
  done
}
