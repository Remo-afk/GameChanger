cd /mnt/Vault/Dev/GameChanger
cat > PKGBUILD << 'EOF'
# Maintainer: Remo-afk <remo@github.com>
pkgname=gamechanger
pkgver=1.0
pkgrel=4
pkgdesc="Ultimate Gaming Control Center - Battery Monitor + RGB + Game Profiles"
arch=('any')
url="https://github.com/Remo-afk/GameChanger"
license=('MIT')
depends=('python' 'python-gobject' 'gtk3' 'libappindicator-gtk3')
optdepends=('openrgb: for RGB control' 'cachyos-rate-mirrors: for system update')
source=("$pkgname-$pkgver.tar.gz::https://github.com/Remo-afk/GameChanger/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    cd "$srcdir/GameChanger-$pkgver"
    
    # Hauptprogramm
    install -Dm755 gamechanger.py "$pkgdir/usr/share/gamechanger/gamechanger.py"
    
    # Starter – jetzt mit install, nicht cat
    install -Dm755 gamechanger "$pkgdir/usr/bin/gamechanger"
    
    # Desktop Entry
    install -Dm644 gamechanger.desktop "$pkgdir/usr/share/applications/gamechanger.desktop"
    
    # Game Profiler
    install -Dm755 game_profiler.sh "$pkgdir/usr/share/gamechanger/game_profiler.sh"
    
    # Udev-Regel
    install -Dm644 99-leds.rules "$pkgdir/usr/lib/udev/rules.d/99-leds.rules"
}
EOF

# Starter-Datei sicherstellen
cat > gamechanger << 'EOF'
#!/bin/bash
if pgrep -f "gamechanger.py" > /dev/null; then
    echo "🎮 GameChanger läuft bereits!"
    exit 0
fi
nohup python3 /usr/share/gamechanger/gamechanger.py > /dev/null 2>&1 &
EOF
chmod +x gamechanger

# Git pushen
git add PKGBUILD gamechanger
git commit -m "Fix PKGBUILD: use install for starter"
git push
git tag -f v1.0
git push --force --tags
