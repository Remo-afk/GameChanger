#!/bin/bash
# GameChanger Ultimate - Das Gaming Kontrollzentrum!
# Mit System-Update Funktion!

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

# ============================================================
# Hauptprogramm mit Update-Button!
# ============================================================
cat > ~/.local/share/gamechanger/gamechanger.py << 'EOF'
#!/usr/bin/env python3
"""
GameChanger Ultimate - Gaming Kontrollzentrum
Mit LED-Farben, Dashboard und System-Update!
"""

import os
import time
import subprocess
import threading
import gi
import glob

gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, GLib, AppIndicator3, GdkPixbuf

SYS_PATH = "/sys/class/power_supply/"

# ========== LED CONTROLLER (Thread-Safe) ==========
class RGB_LED:
    def __init__(self):
        self.leds = self.find_leds()
        self.running = False
        self.lock = threading.Lock()
        
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
        with self.lock:
            if not self.leds:
                return
            self.running = True
            try:
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
            finally:
                self.set_leds(False)
                self.running = False
    
    def stop(self):
        self.running = False
        time.sleep(0.05)
        self.set_leds(False)
    
    def is_running(self):
        return self.running

# ========== AKKU LOGIK ==========

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

def system_update():
    """Führt System-Update durch (in neuem Terminal)"""
    try:
        # Prüfe ob cachyos-rate-mirrors verfügbar
        if os.path.exists("/usr/bin/cachyos-rate-mirrors"):
            cmd = "cachyos-rate-mirrors && sudo pacman -Syu"
        else:
            cmd = "sudo pacman -Syu"
        
        subprocess.Popen([
            "konsole", "-e", "bash", "-c", 
            f"echo '🔄 System-Update wird gestartet...'; {cmd}; echo ''; echo '✅ Fertig! Drücke Enter zum Schließen'; read"
        ])
    except:
        # Fallback: xterm oder gnome-terminal
        subprocess.Popen([
            "xterm", "-e", "bash", "-c",
            f"echo '🔄 System-Update...'; {cmd}; echo ''; echo 'Fertig! Drücke Enter'; read"
        ])

# ========== HAUPTKLASSE ==========

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
        
        # RGB Farben Menü
        rgb_menu = Gtk.MenuItem(label="🌈 RGB Farben")
        rgb_sub = Gtk.Menu()
        for name, pattern in [("🔴 Rot (schnell)", "rot"), ("🟢 Grün (langsam)", "gruen"), 
                               ("🔵 Blau (doppel)", "blau"), ("🟡 Gelb (dauerhaft)", "gelb"), 
                               ("⚪ Aus", "aus")]:
            item = Gtk.MenuItem(label=name)
            item.connect("activate", self.set_led_pattern, pattern)
            rgb_sub.append(item)
        rgb_menu.set_submenu(rgb_sub)
        self.menu.append(rgb_menu)
        
        # Dashboard
        dash = Gtk.MenuItem(label="📊 Dashboard")
        dash.connect("activate", self.open_dashboard)
        self.menu.append(dash)
        
        self.menu.append(Gtk.SeparatorMenuItem())
        
        # SYSTEM UPDATE BUTTON! 🔥
        update_item = Gtk.MenuItem(label="🔄 System Update")
        update_item.connect("activate", self.do_system_update)
        self.menu.append(update_item)
        
        self.menu.append(Gtk.SeparatorMenuItem())
        
        # Beenden
        quit_item = Gtk.MenuItem(label="❌ Beenden")
        quit_item.connect("activate", Gtk.main_quit)
        self.menu.append(quit_item)
        self.menu.show_all()
    
    def set_led_pattern(self, widget, pattern):
        if pattern == "aus":
            self.rgb.stop()
        else:
            if self.rgb.is_running():
                self.rgb.stop()
                time.sleep(0.1)
            threading.Thread(target=self.rgb.blink_pattern, args=(pattern, 2), daemon=True).start()
    
    def do_system_update(self, widget):
        """System Update ausführen"""
        threading.Thread(target=system_update, daemon=True).start()
    
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
            if not self.rgb.is_running():
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
                if not self.rgb.is_running():
                    threading.Thread(target=self.rgb.blink_pattern, args=("alarm", 3), daemon=True).start()
                self.last_alarm[name] = level
            elif level != "??" and level > 20:
                self.last_alarm[name] = 100
        return True
    
    def open_dashboard(self, w):
        win = Gtk.Window(title="🎮 GameChanger Dashboard")
        win.set_default_size(450, 450)
        win.set_position(Gtk.WindowPosition.CENTER)
        win.set_border_width(15)
        
        # CSS
        css = b"""
        window { background-color: #1e1e2e; }
        label { color: #cdd6f4; }
        .title { font-size: 18px; font-weight: bold; color: #a6e3a1; }
        .device { background-color: #313244; border-radius: 8px; padding: 8px; margin: 5px; }
        .update-btn { background-color: #a6e3a1; color: #1e1e2e; font-weight: bold; }
        """
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(css)
        screen = Gtk.Window.get_screen(win)
        Gtk.StyleContext.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        win.add(box)
        
        title = Gtk.Label()
        title.set_markup("<span size='x-large'>🎮 GameChanger Kontrollzentrum</span>")
        title.get_style_context().add_class("title")
        box.pack_start(title, False, False, 0)
        
        # Geräte anzeigen
        devices = get_devices()
        for icon, name, level, charging in devices:
            device_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
            device_box.get_style_context().add_class("device")
            
            header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            name_label = Gtk.Label()
            name_label.set_markup(f"<span size='large'>{icon} {name}</span>")
            name_label.set_halign(Gtk.Align.START)
            header.pack_start(name_label, True, True, 0)
            
            if charging:
                charge = Gtk.Label()
                charge.set_markup("<span color='#a6e3a1'>⚡ LÄDT</span>")
                header.pack_end(charge, False, False, 0)
            
            device_box.pack_start(header, False, False, 0)
            
            if level == "??":
                level_label = Gtk.Label()
                level_label.set_markup("<span color='#f9e2af'>🔍 Scanne...</span>")
            else:
                level_label = Gtk.Label()
                if level <= 10:
                    color = "#f38ba8"
                elif level <= 20:
                    color = "#fab387"
                else:
                    color = "#a6e3a1"
                level_label.set_markup(f"<span color='{color}'><b>{level}%</b></span>")
            
            level_label.set_halign(Gtk.Align.START)
            device_box.pack_start(level_label, False, False, 0)
            box.pack_start(device_box, False, False, 0)
        
        if not devices:
            empty = Gtk.Label()
            empty.set_markup("<span color='#f9e2af'>🔍 Keine Geräte gefunden</span>")
            box.pack_start(empty, False, False, 0)
        
        # UPDATE BUTTON im Dashboard!
        update_btn = Gtk.Button(label="🔄 SYSTEM UPDATE")
        update_btn.get_style_context().add_class("update-btn")
        update_btn.connect("clicked", self.do_system_update)
        box.pack_start(update_btn, False, False, 10)
        
        status = Gtk.Label()
        status.set_markup(f"📅 {time.strftime('%H:%M:%S')}")
        box.pack_start(status, False, False, 5)
        
        btn_box = Gtk.Box(spacing=10)
        refresh_btn = Gtk.Button(label="🔄 Aktualisieren")
        refresh_btn.connect("clicked", lambda x: win.destroy() or self.open_dashboard(None))
        btn_box.pack_start(refresh_btn, True, True, 0)
        
        close_btn = Gtk.Button(label="❌ Schließen")
        close_btn.connect("clicked", lambda x: win.destroy())
        btn_box.pack_start(close_btn, True, True, 0)
        
        box.pack_start(btn_box, False, False, 0)
        win.show_all()

if __name__ == "__main__":
    hub = GameChanger()
    Gtk.main()
EOF

chmod +x ~/.local/share/gamechanger/gamechanger.py

# ============================================================
# Starter mit Single-Instance-Schutz
# ============================================================
cat > ~/.local/bin/gamechanger << 'EOF'
#!/bin/bash
# GameChanger Starter - Single Instance

if pgrep -f "gamechanger.py" > /dev/null; then
    echo "🎮 GameChanger läuft bereits!"
    exit 0
fi

nohup python3 ~/.local/share/gamechanger/gamechanger.py > /dev/null 2>&1 &
echo "🎮 GameChanger gestartet!"
EOF
chmod +x ~/.local/bin/gamechanger

# ============================================================
# Autostart
# ============================================================
cat > ~/.config/autostart/gamechanger.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=GameChanger
Comment=Gaming Kontrollzentrum
Exec=$HOME/.local/bin/gamechanger
Icon=battery-full
Categories=System;Utility;
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# ============================================================
# Udev-Regel für LEDs
# ============================================================
echo ""
echo "💡 Richte LED-Zugriff ein..."
sudo tee /etc/udev/rules.d/99-leds.rules << 'EOF'
SUBSYSTEM=="leds", ACTION=="add", RUN+="/bin/chgrp video /sys%p/brightness", RUN+="/bin/chmod g+w /sys%p/brightness"
EOF
sudo udevadm control --reload-rules
sudo groupadd video 2>/dev/null || true
sudo usermod -aG video $USER

# ============================================================
# Desktop-Eintrag
# ============================================================
cat > ~/.local/share/applications/gamechanger.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=GameChanger
Comment=Gaming Kontrollzentrum
Exec=$HOME/.local/bin/gamechanger
Icon=battery-full
Categories=System;Utility;
Terminal=false
StartupNotify=false
EOF

echo ""
echo "=========================================="
echo "✅ GameChanger Ultimate installiert!"
echo "=========================================="
echo ""
echo "🚀 Starte mit: gamechanger"
echo "🔄 Das Icon erscheint in der Taskleiste"
echo "🌈 RGB Farben: Klicke auf das Icon"
echo "🔄 SYSTEM UPDATE: Im Menü oder Dashboard!"
echo ""
