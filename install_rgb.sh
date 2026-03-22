#!/bin/bash
# GameChanger - Logitech RGB Installer v3.2.1

set -e

echo "🎮 GameChanger - Logitech RGB Controller v3.2.1"
echo "==============================================="
echo ""

# 1. Compiler prüfen
if ! command -v g++ &> /dev/null; then
    echo "📦 Installiere Compiler..."
    sudo pacman -S gcc --noconfirm
fi

# 2. libusb installieren
echo "📦 Prüfe libusb..."
if ! pacman -Qs libusb > /dev/null; then
    sudo pacman -S libusb --noconfirm
fi

# 3. Kompilieren
echo "🔨 Kompiliere RGB Controller..."
if [ -f "logitech_rgb.cpp" ]; then
    g++ -std=c++17 -O3 -pthread logitech_rgb.cpp -o logitech_rgb -lusb-1.0
    sudo mv logitech_rgb /usr/local/bin/logitech_rgb
    sudo chmod +x /usr/local/bin/logitech_rgb
else
    echo "❌ Fehler: logitech_rgb.cpp nicht gefunden!"
    exit 1
fi

# 4. Udev-Regel
echo "🔧 Richte USB-Zugriff ein..."
sudo tee /etc/udev/rules.d/99-logitech.rules << 'EOF'
# Logitech Gaming Geräte
SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", MODE="0666", GROUP="plugdev"
KERNEL=="hidraw*", ATTRS{idVendor}=="046d", MODE="0666", GROUP="plugdev"
EOF

sudo groupadd plugdev 2>/dev/null || true
sudo usermod -aG plugdev $USER
sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "=========================================="
echo "✅ GameChanger RGB Core installiert!"
echo "=========================================="
echo ""
echo "🚀 Befehle:"
echo "    logitech_rgb scan          # Geräte suchen"
echo "    logitech_rgb 255 0 0       # Rot"
echo "    logitech_rgb test          # Test-Muster"
echo "    logitech_rgb fade          # Fading-Demo"
echo "    logitech_rgb status        # Status"
echo ""
echo "💡 Tipp: Nach dem ersten Start einmal aus- und einloggen."
