cd /mnt/Vault/Dev/GameChanger

# Erstelle die neue install.sh
cat > install.sh << 'EOF'
#!/bin/bash
# GameChanger Ultimate Installer - 100% Unabhängig!

set -e

echo "🎮 GameChanger Ultimate Installer"
echo "================================"
echo ""

# Prüfe Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 nicht gefunden!"
    exit 1
fi
echo "✅ Python3 gefunden: $(python3 --version)"

# Installiere Abhängigkeiten
echo ""
echo "📦 Installiere Abhängigkeiten..."
if command -v pacman &> /dev/null; then
    sudo pacman -S python-gobject gtk3 libappindicator-gtk3 --noconfirm 2>/dev/null || true
fi

# Erstelle Verzeichnisse
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/gamechanger
mkdir -p ~/.config/autostart

# Hauptprogramm
cat > ~/.local/share/gamechanger/gamechanger.py << 'PYEOF'
#!/usr/bin/env python3
"""
GameChanger - 100% UNABHÄNGIG! Nutzt NATIVE LEDs!
"""

import os
import time
import subprocess
import threading
import gi
import glob

gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, GLib, AppIndicator3

SYS_PATH = "/sys/class/power_supply/"

class RGB_LED:
    def __init__(self):
        self.leds = self.find_leds()
        self.running = False
        
    def find_leds(self):
        leds = []
        for pattern in ["/sys/class/leds/*capslock*/brightness", "/sys/class/leds/*numlock*/brightness"]:
            for path in glob.glob(pattern):
                if os.path.exists(path):
                    leds.append(path)
        return leds
    
    def set_leds(self, state):
        for led in self.leds:
            try:
                with open(led, 'w') as f:
                    f.write("1" if state else "0")
            except:
                pass
    
    def blink_pattern(self, pattern, duration=3):
        if not self.leds:
            return
        self.running = True
        if pattern == "rot":
            for _ in range(duration * 5):
                if not self.running: break
                self.set_leds(True); time.sleep(0.1)
                self.set_leds(False); time.sleep(0.1)
        elif pattern == "gruen":
            for _ in range(duration):
                if not self.running: break
                self.set_leds(True); time.sleep(0.5)
                self.set_leds(False); time.sleep(0.5)
        elif pattern == "blau":
            for _ in range(duration):
                if not self.running: break
                self.set_leds(True); time.sleep(0.2)
                self.set_leds(False); time.sleep(0.1)
                self.set_leds(True); time.sleep(0.2)
                self.set_leds(False); time.sleep(0.3)
        elif pattern == "gelb":
            self.set_leds(True); time.sleep(duration)
            self.set_leds(False)
        elif pattern == "alarm":
            for _ in range(duration * 10):
                if not self.running: break
                self.set_leds(True); time.sleep(0.05)
                self.set_leds(False); time.sleep(0.05)
        self.set_leds(False)
        self.running = False
    
    def stop(self):
        self.running = False
        self.set_leds(False)

def get_devices():
    devices = []
    if not os.path.exists(SYS_PATH):
        return devices
    for entry in os.listdir(SYS_PATH):
        if entry.startswith(("AC", "ADP", "ACAD")):
            continue
        cap = os.path.join(SYS_PATH, entry, "capacity")
        if not os.path.exists(cap):
            continue
        try:
            with open(cap) as f:
                level = int(f.read().strip())
            status = os.path.join(SYS_PATH, entry, "status")
            charging = False
            if os.path.exists(status):
                with open(status) as f:
                    charging = "charging" in f.read().strip().lower()
            icon, name = "🔋", entry
            if "hidpp_battery_0" in entry:
                icon, name = "🖱️", "Logitech G502 X"
            elif "hidpp_battery_1" in entry:
                icon, name = "⌨️", "Logitech G515"
            elif "ps" in entry.lower():
                icon, name = "🎮", "PS5 DualSense"
            devices.append((icon, name, level, charging))
        except:
            pass
    try:
        usb = subprocess.run(["lsusb", "-d", "10d6:4801"], capture_output=True, timeout=2)
        if usb.stdout.strip():
            devices.append(("🎧", "NUBWO G06", "??", False))
    except:
        pass
    return devices

class GameChanger:
    def __init__(self):
        self.indicator = AppIndicator3.Indicator.new("gamechanger", "input-gaming", AppIndicator3.IndicatorCategory.SYSTEM_SERVICES)
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.rgb = RGB_LED()
        self.last_alarm = {}
        self.build_menu()
        self.indicator.set_menu(self.menu)
        GLib.timeout_add_seconds(30, self.update)
        self.update()
        print("🎮 GameChanger läuft (OHNE OpenRGB!)")

    def build_menu(self):
        self.menu = Gtk.Menu()
        self.device_info = Gtk.MenuItem(label="🔍 Scanne...")
        self.device_info.set_sensitive(False)
        self.menu.append(self.device_info)
        self.menu.append(Gtk.SeparatorMenuItem())
        
        rgb_menu = Gtk.MenuItem(label="🌈 RGB Farben")
        rgb_sub = Gtk.Menu()
        for name, pattern in [("🔴 Rot", "rot"), ("🟢 Grün", "gruen"), ("🔵 Blau", "blau"), ("🟡 Gelb", "gelb"), ("⚪ Aus", "aus")]:
            item = Gtk.MenuItem(label=name)
            item.connect("activate", self.set_led, pattern)
            rgb_sub.append(item)
        rgb_menu.set_submenu(rgb_sub)
        self.menu.append(rgb_menu)
        
        dash = Gtk.MenuItem(label="📊 Dashboard")
        dash.connect("activate", self.open_dashboard)
        self.menu.append(dash)
        
        self.menu.append(Gtk.SeparatorMenuItem())
        quit_item = Gtk.MenuItem(label="❌ Beenden")
        quit_item.connect("activate", Gtk.main_quit)
        self.menu.append(quit_item)
        self.menu.show_all()
    
    def set_led(self, w, pattern):
        if pattern == "aus":
            self.rgb.stop()
        else:
            threading.Thread(target=self.rgb.blink_pattern, args=(pattern, 2), daemon=True).start()
    
    def update(self):
        devices = get_devices()
        count = len(devices)
        lowest = min([l for _, _, l, _ in devices if l != "??"], default=100)
        
        if count == 0:
            self.indicator.set_icon("battery-missing")
            self.device_info.set_label("🔍 Keine Geräte")
        elif lowest <= 10:
            self.indicator.set_icon("battery-caution")
            self.device_info.set_label(f"🚨 {count} Geräte - KRITISCH!")
            threading.Thread(target=self.rgb.blink_pattern, args=("alarm", 2), daemon=True).start()
        elif lowest <= 20:
            self.indicator.set_icon("battery-low")
            self.device_info.set_label(f"⚠️ {count} Geräte - niedrig")
        else:
            self.indicator.set_icon("input-gaming")
            self.device_info.set_label(f"🎮 {count} Geräte")
        
        for _, name, level, _ in devices:
            if level != "??" and level <= 15 and level != self.last_alarm.get(name, 100):
                subprocess.run(["notify-send", "-u", "critical", f"⚠️ {name}", f"{level}%!"])
                threading.Thread(target=self.rgb.blink_pattern, args=("alarm", 3), daemon=True).start()
                self.last_alarm[name] = level
        return True
    
    def open_dashboard(self, w):
        win = Gtk.Window(title="🎮 GameChanger")
        win.set_default_size(400, 350)
        win.set_position(Gtk.WindowPosition.CENTER)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        win.add(box)
        for icon, name, level, charging in get_devices():
            lbl = Gtk.Label()
            if level == "??":
                lbl.set_markup(f"{icon} {name}: 🔍 Scanne...")
            else:
                lbl.set_markup(f"{icon} {name}: {level}%")
            box.pack_start(lbl, False, False, 0)
        btn = Gtk.Button(label="❌ Schließen")
        btn.connect("clicked", lambda x: win.destroy())
        box.pack_start(btn, False, False, 0)
        win.show_all()

if __name__ == "__main__":
    hub = GameChanger()
    Gtk.main()
PYEOF

chmod +x ~/.local/share/gamechanger/gamechanger.py

# Starter
cat > ~/.local/bin/gamechanger << 'EOF'
#!/bin/bash
nohup python3 ~/.local/share/gamechanger/gamechanger.py > /dev/null 2>&1 &
EOF
chmod +x ~/.local/bin/gamechanger

# Autostart
cat > ~/.config/autostart/gamechanger.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=GameChanger
Exec=$HOME/.local/bin/gamechanger
Icon=battery-full
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# Udev für LEDs
sudo tee /etc/udev/rules.d/99-leds.rules << 'EOF'
SUBSYSTEM=="leds", ACTION=="add", RUN+="/bin/chgrp video /sys%p/brightness", RUN+="/bin/chmod g+w /sys%p/brightness"
EOF
sudo udevadm control --reload-rules
sudo groupadd video 2>/dev/null || true
sudo usermod -aG video $USER

echo ""
echo "✅ GameChanger installiert!"
echo "🚀 Starte mit: gamechanger"
EOF

# Mach ausführbar
chmod +x install.sh

# Commit und Push
git add install.sh
git commit -m "Update: 100% independent version - no OpenRGB needed!"
git push
