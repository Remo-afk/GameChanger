# 1. Gehe in dein lokales GameChanger Verzeichnis
cd /mnt/Vault/Dev/GameChanger

# 2. Stelle sicher, dass die Starter-Datei existiert
cat > gamechanger << 'EOF'
#!/bin/bash
if pgrep -f "gamechanger.py" > /dev/null; then
    echo "🎮 GameChanger läuft bereits!"
    exit 0
fi
nohup python3 /usr/share/gamechanger/gamechanger.py > /dev/null 2>&1 &
EOF
chmod +x gamechanger

# 3. Stelle sicher, dass die udev-Regel existiert
cat > 99-leds.rules << 'EOF'
SUBSYSTEM=="leds", ACTION=="add", RUN+="/bin/chgrp video /sys%p/brightness", RUN+="/bin/chmod g+w /sys%p/brightness"
EOF

# 4. Aktualisiere den PKGBUILD
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
    
    # Starter (wichtig!)
    install -Dm755 gamechanger "$pkgdir/usr/bin/gamechanger"
    
    # Desktop Entry
    install -Dm644 gamechanger.desktop "$pkgdir/usr/share/applications/gamechanger.desktop"
    
    # Game Profiler
    install -Dm755 game_profiler.sh "$pkgdir/usr/share/gamechanger/game_profiler.sh"
    
    # Udev-Regel
    install -Dm644 99-leds.rules "$pkgdir/usr/lib/udev/rules.d/99-leds.rules"
}
EOF

# 5. Alle Dateien hinzufügen
git add gamechanger 99-leds.rules PKGBUILD
git commit -m "Fix PKGBUILD: add missing starter file"
git push
git tag -f v1.0
git push --force --tags
