#!/bin/bash
# ============================================================
# GameChanger Installer - Hybrid Battery & Hardware Hub
# ============================================================

set -e

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${RED}     🎮${YELLOW}  G A M E C H A N G E R  ${GREEN}I N S T A L L E R  ${BLUE}   🎮${BLUE}     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# 1. Prüfe Python
# ============================================================
echo -e "${YELLOW}📋 Schritt 1: Prüfe Python...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 nicht gefunden!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python3 gefunden: $(python3 --version)${NC}"

# ============================================================
# 2. Prüfe und installiere Pakete
# ============================================================
echo -e "${YELLOW}📦 Schritt 2: Prüfe benötigte Pakete...${NC}"

# python-dbus
if ! python3 -c "import dbus" 2>/dev/null; then
    if command -v pacman &> /dev/null; then
        sudo pacman -S python-dbus --noconfirm
    elif command -v apt &> /dev/null; then
        sudo apt install python3-dbus -y
    fi
fi

# python-gobject
if ! python3 -c "from gi.repository import GLib" 2>/dev/null; then
    if command -v pacman &> /dev/null; then
        sudo pacman -S python-gobject --noconfirm
    elif command -v apt &> /dev/null; then
        sudo apt install python3-gi -y
    fi
fi
echo -e "${GREEN}✅ Pakete OK${NC}"

# ============================================================
# 3. Erstelle Verzeichnisse
# ============================================================
echo -e "${YELLOW}📁 Schritt 3: Erstelle Verzeichnisse...${NC}"
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/dbus-1/services
mkdir -p ~/.config/autostart
mkdir -p ~/.local/share/gamechanger
echo -e "${GREEN}✅ Verzeichnisse erstellt${NC}"

# ============================================================
# 4. Kopiere Hauptprogramm
# ============================================================
echo -e "${YELLOW}📄 Schritt 4: Kopiere Hauptprogramm...${NC}"

if [ -f "./gamechanger.py" ]; then
    cp ./gamechanger.py ~/.local/share/gamechanger/gamechanger.py
else
    echo -e "${RED}❌ gamechanger.py nicht gefunden!${NC}"
    exit 1
fi
chmod +x ~/.local/share/gamechanger/gamechanger.py
echo -e "${GREEN}✅ Hauptprogramm installiert${NC}"

# ============================================================
# 5. Erstelle DBus Service
# ============================================================
echo -e "${YELLOW}🔌 Schritt 5: Erstelle DBus Service...${NC}"

cat > ~/.local/bin/gamechanger_dbus.py << 'EOFDBUS'
#!/usr/bin/env python3
import os
import subprocess
import json
import time
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

SYS_PATH = "/sys/class/power_supply/"
CHECK_INTERVAL = 30
GAMECHANGER_PATH = os.path.expanduser("~/.local/share/gamechanger/gamechanger.py")

def get_battery_data():
    result = subprocess.run(["python3", GAMECHANGER_PATH, "--once"], capture_output=True, text=True)
    return {"devices": result.stdout.strip().split("\n"), "timestamp": time.time()}

class GameChangerDBus(dbus.service.Object):
    def __init__(self):
        bus_name = dbus.service.BusName("org.gamechanger", bus=dbus.SessionBus())
        dbus.service.Object.__init__(self, bus_name, "/org/gamechanger")
        self.start_timer()
    
    def start_timer(self):
        def update():
            self.update_data()
            return True
        GLib.timeout_add_seconds(CHECK_INTERVAL, update)
    
    def update_data(self):
        data = get_battery_data()
        self.DataUpdated(json.dumps(data))
        return True
    
    @dbus.service.method("org.gamechanger", in_signature='', out_signature='s')
    def GetData(self):
        return json.dumps(get_battery_data())
    
    @dbus.service.signal("org.gamechanger", signature='s')
    def DataUpdated(self, data):
        pass

def main():
    DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()
    service = GameChangerDBus()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
EOFDBUS

chmod +x ~/.local/bin/gamechanger_dbus.py
echo -e "${GREEN}✅ DBus Service erstellt${NC}"

# ============================================================
# 6. DBus Service Datei
# ============================================================
cat > ~/.local/share/dbus-1/services/org.gamechanger.service << 'EOFSERVICE'
[D-BUS Service]
Name=org.gamechanger
Exec=/usr/bin/python3 $HOME/.local/bin/gamechanger_dbus.py
EOFSERVICE
echo -e "${GREEN}✅ DBus registriert${NC}"

# ============================================================
# 7. Autostart
# ============================================================
cat > ~/.config/autostart/gamechanger-dbus.desktop << 'EOFAUTO'
[Desktop Entry]
Type=Application
Name=GameChanger DBus Service
Exec=/usr/bin/python3 $HOME/.local/bin/gamechanger_dbus.py
Icon=battery-full
X-GNOME-Autostart-enabled=true
EOFAUTO
echo -e "${GREEN}✅ Autostart eingerichtet${NC}"

# ============================================================
# 8. Alias für Fish/Bash
# ============================================================
if [ -d ~/.config/fish ]; then
    if ! grep -q "alias gc" ~/.config/fish/config.fish 2>/dev/null; then
        echo 'alias gc="python3 ~/.local/share/gamechanger/gamechanger.py"' >> ~/.config/fish/config.fish
        echo 'alias gamechanger="python3 ~/.local/share/gamechanger/gamechanger.py"' >> ~/.config/fish/config.fish
    fi
fi

if [ -f ~/.bashrc ]; then
    if ! grep -q "alias gc" ~/.bashrc 2>/dev/null; then
        echo 'alias gc="python3 ~/.local/share/gamechanger/gamechanger.py"' >> ~/.bashrc
        echo 'alias gamechanger="python3 ~/.local/share/gamechanger/gamechanger.py"' >> ~/.bashrc
    fi
fi

# ============================================================
# 9. Starte Service
# ============================================================
pkill -f "gamechanger_dbus.py" 2>/dev/null || true
python3 ~/.local/bin/gamechanger_dbus.py &
echo -e "${GREEN}✅ Service gestartet${NC}"

# ============================================================
# 10. udev-Regel für LEDs
# ============================================================
echo -e "${YELLOW}💡 Schritt 10: Richte LED-Zugriff ein...${NC}"

sudo tee /etc/udev/rules.d/98-leds.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*capslock*", RUN+="/bin/chmod 666 /sys/class/leds/%k/brightness"
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*numlock*", RUN+="/bin/chmod 666 /sys/class/leds/%k/brightness"
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*scrolllock*", RUN+="/bin/chmod 666 /sys/class/leds/%k/brightness"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

echo -e "${GREEN}✅ LED-Zugriff eingerichtet${NC}"

# ============================================================
# 11. udev-Regel für NUBWO Headset
# ============================================================
echo -e "${YELLOW}🎧 Schritt 11: Richte NUBWO Headset ein...${NC}"

sudo tee /etc/udev/rules.d/99-nubwo.rules << 'EOF'
KERNEL=="hidraw*", ATTRS{idVendor}=="10d6", ATTRS{idProduct}=="4801", MODE="0666"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

echo -e "${GREEN}✅ NUBWO Headset eingerichtet${NC}"

# ============================================================
# 12. Fertig!
# ============================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${RED}     🎮${YELLOW}  G A M E C H A N G E R  ${GREEN}I N S T A L L I E R T  ${RED}  🎮${GREEN}     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}✨ Was jetzt?${NC}"
echo -e "  ${GREEN}▶${NC} Terminal: ${YELLOW}gc${NC} oder ${YELLOW}gamechanger${NC}"
echo -e "  ${GREEN}▶${NC} Autostart: Läuft im Hintergrund"
echo -e "  ${GREEN}▶${NC} LEDs: Blinken bei Alarm!"
echo ""
echo -e "${YELLOW}💡 Tipp:${NC} Logge dich einmal aus und wieder ein!"
echo ""
