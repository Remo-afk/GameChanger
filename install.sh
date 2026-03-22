#!/bin/bash
# GameChanger Ultimate Installer v2.2
# Mit gefiltertem Alias für saubere Terminal-Ausgabe

set -e

echo "🎮 GameChanger Ultimate Installer v2.2"
echo "======================================"
echo ""

# ========== 1. SYSTEM-CHECKS ==========
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 nicht gefunden!"
    exit 1
fi
echo "✅ Python3 gefunden: $(python3 --version)"

# ========== 2. ABHÄNGIGKEITEN ==========
echo ""
echo "📦 Installiere Abhängigkeiten..."
if command -v pacman &> /dev/null; then
    sudo pacman -S python-gobject gtk3 libappindicator-gtk3 python-psutil python-dbus --noconfirm 2>/dev/null || true
fi

# ========== 3. VERZEICHNISSE ==========
echo ""
echo "📁 Erstelle Verzeichnisse..."
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/gamechanger
mkdir -p ~/.config/autostart
mkdir -p ~/.config/gamechanger/profiles
mkdir -p ~/.local/share/plasma/plasmoids

# ========== 4. HAUPTPROGRAMM ==========
echo ""
echo "🐍 Installiere GameChanger..."

# Kopiere gamechanger.py (muss im aktuellen Ordner sein)
if [ -f "./gamechanger.py" ]; then
    cp ./gamechanger.py ~/.local/share/gamechanger/gamechanger.py
else
    echo "❌ gamechanger.py nicht gefunden!"
    exit 1
fi
chmod +x ~/.local/share/gamechanger/gamechanger.py

# ========== 5. STARTER (mit gefiltertem Alias) ==========
cat > ~/.local/bin/gamechanger << 'EOF'
#!/bin/bash
if pgrep -f "gamechanger.py" > /dev/null; then
    echo "🎮 GameChanger läuft bereits!"
    exit 0
fi
nohup python3 ~/.local/share/gamechanger/gamechanger.py > /dev/null 2>&1 &
EOF
chmod +x ~/.local/bin/gamechanger

# ========== 6. ALIAS MIT FILTER (für Terminal) ==========
echo ""
echo "⚡ Richte gefilterten Alias ein..."

# Für Fish Shell
if [ -d ~/.config/fish ]; then
    # Lösche alte Aliase
    sed -i '/alias gamechanger/d' ~/.config/fish/config.fish
    sed -i '/alias gc/d' ~/.config/fish/config.fish
    # Füge neue gefilterte Aliase hinzu
    echo 'alias gamechanger="gamechanger 2>&1 | grep -v \"No sample format supported\""' >> ~/.config/fish/config.fish
    echo 'alias gc="gamechanger 2>&1 | grep -v \"No sample format supported\""' >> ~/.config/fish/config.fish
fi

# Für Bash
if [ -f ~/.bashrc ]; then
    sed -i '/alias gamechanger/d' ~/.bashrc
    sed -i '/alias gc/d' ~/.bashrc
    echo 'alias gamechanger="gamechanger 2>&1 | grep -v \"No sample format supported\""' >> ~/.bashrc
    echo 'alias gc="gamechanger 2>&1 | grep -v \"No sample format supported\""' >> ~/.bashrc
fi

# ========== 7. GAME PROFILER JSON ==========
cat > ~/.config/gamechanger/profiles/profiles.json << 'EOF'
{
  "Final Fantasy XIV": {
    "rgb": [255, 0, 0],
    "process": "ffxiv"
  },
  "Cyberpunk 2077": {
    "rgb": [255, 0, 255],
    "process": "Cyberpunk2077"
  },
  "Desktop": {
    "rgb": [0, 255, 0],
    "process": ""
  }
}
EOF

# ========== 8. KDE-PLASMOID ==========
echo ""
echo "🎨 Installiere KDE-Plasmoid..."

if [ -d "./gamechanger@plasma" ]; then
    rm -rf ~/.local/share/plasma/plasmoids/gamechanger@plasma
    cp -r ./gamechanger@plasma ~/.local/share/plasma/plasmoids/
    echo "✅ Plasmoid kopiert"
else
    echo "⚠️ gamechanger@plasma Ordner nicht gefunden – überspringe Plasmoid"
fi

# ========== 9. AUTOSTART ==========
cat > ~/.config/autostart/gamechanger.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=GameChanger
Exec=$HOME/.local/bin/gamechanger
Icon=battery-full
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

cat > ~/.local/share/applications/gamechanger.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=GameChanger
Comment=Ultimate Gaming Control Center
Exec=$HOME/.local/bin/gamechanger
Icon=battery-full
Categories=System;Utility;
Terminal=false
StartupNotify=false
EOF

# ========== 10. UDEV REGEL ==========
echo ""
echo "💡 Richte LED-Zugriff ein..."
sudo tee /etc/udev/rules.d/99-leds.rules << 'EOF'
SUBSYSTEM=="leds", ACTION=="add", RUN+="/bin/chgrp video /sys%p/brightness", RUN+="/bin/chmod g+w /sys%p/brightness"
EOF
sudo udevadm control --reload-rules
sudo groupadd video 2>/dev/null || true
sudo usermod -aG video $USER

# ========== 11. KDE NEUSTART ==========
echo ""
echo "🔄 Aktualisiere KDE..."
plasmashell --replace &

# ========== 12. FERTIG! ==========
echo ""
echo "=========================================="
echo "✅ GameChanger v2.2 installiert!"
echo "=========================================="
echo ""
echo "🚀 Starte mit: gamechanger oder gc"
echo "🔄 Tray-Icon erscheint in der Taskleiste"
echo "🎨 KDE-Plasmoid: Rechtsklick auf Taskleiste → Widgets hinzufügen → GameChanger"
echo "🎮 Game Profiler: FFXIV → Rot, Desktop → Grün"
echo "🖱 Dashboard: Mit Maus verschiebbar!"
echo "🔇 Audio-Fehler werden automatisch ausgeblendet"
echo ""
echo "💡 Nach dem Neustart startet GameChanger automatisch!"
