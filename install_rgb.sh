#!/bin/bash
# GameChanger - Logitech RGB Installer v3.2
# Optimiert für CachyOS / Arch Linux

set -e

echo "🎮 GameChanger - Logitech RGB Controller v3.2"
echo "==============================================="
echo ""

# 1. System-Checks
if ! command -v g++ &> /dev/null; then
    echo "📦 Installiere Compiler..."
    sudo pacman -S gcc --noconfirm
fi

# 2. libusb Check & Installation
echo "📦 Prüfe libusb..."
if ! pacman -Qs libusb > /dev/null; then
    sudo pacman -S libusb --noconfirm
fi

# 3. Kompilieren (mit C++17 und Filesystem)
echo "🔨 Kompiliere RGB Controller..."
if [ -f "logitech_rgb.cpp" ]; then
    g++ -std=c++17 -O3 -pthread logitech_rgb.cpp -o logitech_rgb -lusb-1.0
    sudo mv logitech_rgb /usr/local/bin/logitech_rgb
    sudo chmod +x /usr/local/bin/logitech_rgb
else
    echo "❌ Fehler: logitech_rgb.cpp nicht im aktuellen Verzeichnis gefunden!"
    exit 1
fi

# 4. Udev-Regel (Erlaubt Zugriff auf USB ohne sudo)
echo "🔧 Richte USB-Zugriff ein (Udev-Regeln)..."
sudo tee /etc/udev/rules.d/99-logitech.rules << 'EOF'
# Logitech Gaming Geräte (HID & USB)
SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", MODE="0666", GROUP="plugdev"
KERNEL=="hidraw*", ATTRS{idVendor}=="046d", MODE="0666", GROUP="plugdev"
EOF

# 5. Gruppe erstellen
sudo groupadd plugdev 2>/dev/null || true
sudo usermod -aG plugdev $USER

# 6. udev neu laden & Hardware triggern
echo "🔄 Lade USB-Subsystem neu..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "=========================================="
echo "✅ GameChanger RGB Core installiert!"
echo "=========================================="
echo ""
echo "🚀 Befehle:"
echo "    logitech_rgb scan          # Sucht deine Geräte"
echo "    logitech_rgb 255 0 0       # Setzt statisch Rot"
echo "    logitech_rgb test          # Farb-Demo"
echo "    logitech_rgb fade          # Fading-Demo"
echo "    logitech_rgb status        # Zeigt Status"
echo ""
echo "💡 Tipp: Nach dem ersten Start einmal aus- und einloggen für USB-Rechte."
echo "💡 Tipp: Falls libusb nicht funktioniert, wechselt das Programm automatisch zu HIDRAW."
