#!/bin/bash
# GameChanger Ultimate Installer
# All-in-One: Hauptprogramm + Game Profiler + OpenRGB-Server + Draggable Dashboard

set -e

echo "🎮 GameChanger Ultimate Installer"
echo "================================"
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
    sudo pacman -S python-gobject gtk3 libappindicator-gtk3 --noconfirm 2>/dev/null || true
fi

# ========== 3. VERZEICHNISSE ==========
echo ""
echo "📁 Erstelle Verzeichnisse..."
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/gamechanger
mkdir -p ~/.config/autostart
mkdir -p ~/.config/gamechanger/profiles
mkdir -p ~/.config/gamechanger/games

# ========== 4. HAUPTPROGRAMM (mit Draggable Dashboard) ==========
echo ""
echo "🐍 Installiere GameChanger..."
cat > ~/.local/share/gamechanger/gamechanger.py << 'EOF'
#!/usr/bin/env python3
"""
GameChanger Ultimate - Gaming Kontrollzentrum
Mit schwebendem Dashboard, LevelBar und Game Profiler
"""

import os
import time
import subprocess
import threading
import gi
import glob

gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, GLib, AppIndicator3, Gdk

SYS_PATH = "/sys/class/power_supply/"

# ========== TERMINAL-ERKENNUNG ==========
def get_terminal():
    terminals = ["konsole", "gnome-terminal", "xterm", "alacritty", "kitty"]
    for term in terminals:
        if os.path.exists(f"/usr/bin/{term}") or os.path.exists(f"/usr/local/bin/{term}"):
            return term
    return "xterm"

TERMINAL = get_terminal()

# ========== OPENRGB SERVER ==========
def start_openrgb_server():
    try:
        subprocess.run(["openrgb", "--version"], capture_output=True, timeout=2)
        result = subprocess.run(["pgrep", "-f", "openrgb --server"], capture_output=True)
        if result.returncode != 0:
            subprocess.Popen(["openrgb", "--server"], 
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
    except:
        pass
    return False

def start_game_profiler():
    profiler_script = os.path.expanduser("~/.config/gamechanger/game_profiler.sh")
    if os.path.exists(profiler_script):
        subprocess.Popen(["bash", profiler_script], 
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    return False

# ========== LED CONTROLLER ==========
class LEDController:
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

# ========== OPENRGB CONTROLLER ==========
class OpenRGBController:
    def __init__(self):
        self.available = self.check()
        self.devices = []
        if self.available:
            self.scan_devices()
    
    def check(self):
        try:
            subprocess.run(["openrgb", "--version"], capture_output=True, timeout=2)
            return True
        except:
            return False
    
    def scan_devices(self):
        try:
            result = subprocess.run(["openrgb", "--list-devices"], capture_output=True, text=True, timeout=5)
            for line in result.stdout.split('\n'):
                if "Device" in line:
                    self.devices.append(line.strip())
        except:
            pass
    
    def set_color(self, r, g, b):
        if not self.available:
            return False
        try:
            subprocess.Popen(["openrgb", "--noautoconnect", "--color", f"{r},{g},{b}"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except:
            return False
    
    def set_device_color(self, device_name, r, g, b):
        if not self.available:
            return False
        try:
            subprocess.Popen(["openrgb", "--noautoconnect", "--device", device_name, "--color", f"{r},{g},{b}"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except:
            return False
    
    def load_profile(self, profile_name):
        if not self.available:
            return False
        try:
            subprocess.Popen(["openrgb", "--noautoconnect", "--profile", profile_name],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except:
            return False
    
    def rescan(self):
        if not self.available:
            return False
        try:
            subprocess.run(["openrgb", "--rescan"], capture_output=True, timeout=5)
            self.scan_devices()
            return True
        except:
            return False

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
    cmd = "cachyos-rate-mirrors && sudo pacman -Syu" if os.path.exists("/usr/bin/cachyos-rate-mirrors") else "sudo pacman -Syu"
    subprocess.Popen([TERMINAL, "-e", "bash", "-c", 
        f"echo '🔄 System-Update...'; {cmd}; echo ''; echo '✅ Fertig! Drücke Enter'; read"])

# ========== SCHWEBENDES DASHBOARD (mit Dragging) ==========
class FloatingDashboard:
    def __init__(self, parent):
        self.parent = parent
        self.window = Gtk.Window()
        self.window.set_title("🎮 GameChanger")
        self.window.set_default_size(440, 520)
        self.window.set_position(Gtk.WindowPosition.CENTER)
        self.window.set_border_width(20)
        self.window.set_decorated(False)
        self.window.set_keep_above(False)
        
        # Dragging Variablen
        self.drag_start_x = 0
        self.drag_start_y = 0
        self.dragging = False
        
        # Event-Handler für Dragging
        self.window.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | 
                               Gdk.EventMask.BUTTON_RELEASE_MASK | 
                               Gdk.EventMask.POINTER_MOTION_MASK)
        self.window.connect("button-press-event", self.on_button_press)
        self.window.connect("button-release-event", self.on_button_release)
        self.window.connect("motion-notify-event", self.on_motion)
        
        # CSS
        css = b"""
        window {
            background-color: rgba(30, 30, 46, 0.95);
            border-radius: 20px;
            border: 1px solid #45475a;
            box-shadow: 0 8px 20px rgba(0,0,0,0.3);
        }
        label { color: #cdd6f4; font-family: monospace; }
        .title { font-size: 18px; font-weight: bold; color: #a6e3a1; margin-bottom: 10px; }
        .device-card { background-color: #313244; border-radius: 12px; padding: 10px 12px; margin: 5px 0; }
        .level-bar { min-height: 12px; border-radius: 6px; }
        levelbar trough { background-color: #1e1e2e; border-radius: 6px; min-height: 12px; }
        levelbar block.filled { border-radius: 6px; }
        .low-battery block.filled { background-color: #f38ba8; }
        .good-battery block.filled { background-color: #a6e3a1; }
        .warning-battery block.filled { background-color: #fab387; }
        button { background-color: #45475a; color: #cdd6f4; border-radius: 10px; padding: 6px 12px; border: none; margin: 2px; }
        button:hover { background-color: #585b70; }
        .rgb-btn { background-color: #313244; border-radius: 20px; padding: 8px 12px; font-size: 16px; }
        .rgb-btn:hover { background-color: #585b70; }
        """
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(css)
        screen = Gtk.Window.get_screen(self.window)
        Gtk.StyleContext.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        
        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.window.add(self.box)
        
        # Header
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        title = Gtk.Label()
        title.set_markup("<span size='x-large'>🎮 GameChanger</span>")
        title.get_style_context().add_class("title")
        header.pack_start(title, True, True, 0)
        close_btn = Gtk.Button(label="✕")
        close_btn.connect("clicked", lambda x: self.window.hide())
        close_btn.set_size_request(30, 30)
        header.pack_end(close_btn, False, False, 0)
        self.box.pack_start(header, False, False, 0)
        
        # RGB-Status
        self.rgb_status = Gtk.Label()
        if self.parent.openrgb.available:
            self.rgb_status.set_markup("<span color='#a6e3a1'>🌈 OpenRGB-Modus aktiv</span>")
        elif self.parent.led.leds:
            self.rgb_status.set_markup("<span color='#fab387'>💡 LED-Modus aktiv (Caps/Num Lock)</span>")
        else:
            self.rgb_status.set_markup("<span color='#f38ba8'>⚠️ Keine RGB/LEDs verfügbar</span>")
        self.box.pack_start(self.rgb_status, False, False, 0)
        
        # RGB Schnellwahl
        if self.parent.openrgb.available:
            rgb_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            rgb_box.set_halign(Gtk.Align.CENTER)
            colors = [
                ("🔴", (255, 0, 0), "Rot"), ("🟢", (0, 255, 0), "Grün"), ("🔵", (0, 0, 255), "Blau"),
                ("🟡", (255, 255, 0), "Gelb"), ("🟣", (255, 0, 255), "Pink"), ("⚪", (255, 255, 255), "Weiß"),
                ("🌑", (0, 0, 0), "Aus")
            ]
            for icon, rgb, name in colors:
                btn = Gtk.Button(label=icon)
                btn.set_tooltip_text(name)
                btn.get_style_context().add_class("rgb-btn")
                btn.connect("clicked", lambda x, c=rgb: self.parent.set_openrgb_color(None, c))
                rgb_box.pack_start(btn, False, False, 0)
            self.box.pack_start(rgb_box, False, False, 5)
            
            rescan_btn = Gtk.Button(label="🔄 Geräte scannen")
            rescan_btn.connect("clicked", self.parent.rescan_devices)
            self.box.pack_start(rescan_btn, False, False, 0)
        
        # Geräte-Container
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_height(200)
        self.device_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        scroll.add(self.device_container)
        self.box.pack_start(scroll, True, True, 0)
        
        # Update-Button
        update_btn = Gtk.Button(label="🔄 System Update")
        update_btn.connect("clicked", lambda x: threading.Thread(target=system_update, daemon=True).start())
        self.box.pack_start(update_btn, False, False, 0)
        
        self.window.show_all()
    
    def on_button_press(self, widget, event):
        if event.button == 1:
            self.drag_start_x = event.x_root - self.window.get_position()[0]
            self.drag_start_y = event.y_root - self.window.get_position()[1]
            self.dragging = True
    
    def on_button_release(self, widget, event):
        if event.button == 1:
            self.dragging = False
    
    def on_motion(self, widget, event):
        if self.dragging:
            new_x = int(event.x_root - self.drag_start_x)
            new_y = int(event.y_root - self.drag_start_y)
            self.window.move(new_x, new_y)
    
    def refresh(self, devices):
        for child in self.device_container.get_children():
            self.device_container.remove(child)
        
        for icon, name, level, charging in devices:
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            card.get_style_context().add_class("device-card")
            
            header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            name_label = Gtk.Label()
            name_label.set_markup(f"<span size='large'>{icon} {name}</span>")
            name_label.set_halign(Gtk.Align.START)
            header.pack_start(name_label, True, True, 0)
            if charging:
                charge = Gtk.Label()
                charge.set_markup("<span color='#a6e3a1'>⚡ LÄDT</span>")
                header.pack_end(charge, False, False, 0)
            card.pack_start(header, False, False, 0)
            
            if level == "??":
                level_label = Gtk.Label()
                level_label.set_markup("<span color='#f9e2af'>🔍 Scanne...</span>")
                card.pack_start(level_label, False, False, 0)
            else:
                level_bar = Gtk.LevelBar()
                level_bar.set_min_value(0)
                level_bar.set_max_value(100)
                level_bar.set_value(level)
                level_bar.set_size_request(200, 12)
                level_bar.get_style_context().add_class("level-bar")
                if level <= 10:
                    level_bar.get_style_context().add_class("low-battery")
                elif level <= 20:
                    level_bar.get_style_context().add_class("warning-battery")
                else:
                    level_bar.get_style_context().add_class("good-battery")
                
                level_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                level_box.pack_start(level_bar, True, True, 0)
                percent_label = Gtk.Label()
                if level <= 10:
                    percent_label.set_markup(f"<span color='#f38ba8'><b>{level}%</b></span>")
                elif level <= 20:
                    percent_label.set_markup(f"<span color='#fab387'><b>{level}%</b></span>")
                else:
                    percent_label.set_markup(f"<span color='#a6e3a1'><b>{level}%</b></span>")
                level_box.pack_start(percent_label, False, False, 0)
                card.pack_start(level_box, False, False, 2)
            
            self.device_container.pack_start(card, False, False, 0)
        
        if not devices:
            empty = Gtk.Label()
            empty.set_markup("<span color='#f9e2af'>🔍 Keine Geräte gefunden</span>")
            self.device_container.pack_start(empty, False, False, 0)
        
        self.device_container.show_all()

# ========== HAUPTKLASSE ==========
class GameChanger:
    def __init__(self):
        start_openrgb_server()
        start_game_profiler()
        
        self.indicator = AppIndicator3.Indicator.new("gamechanger", "input-gaming", AppIndicator3.IndicatorCategory.SYSTEM_SERVICES)
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        
        self.led = LEDController()
        self.openrgb = OpenRGBController()
        self.last_alarm = {}
        self.dashboard = None
        
        self.build_menu()
        self.indicator.set_menu(self.menu)
        GLib.timeout_add_seconds(30, self.update)
        self.update()
        
        print("🎮 GameChanger läuft")
        print(f"📺 Terminal: {TERMINAL}")
        if self.openrgb.available:
            print(f"✅ OpenRGB-Modus aktiv ({len(self.openrgb.devices)} Geräte)")
        elif self.led.leds:
            print(f"✅ LED-Modus aktiv ({len(self.led.leds)} LEDs)")
        else:
            print("⚠️ Keine RGB/LEDs verfügbar")

    def build_menu(self):
        self.menu = Gtk.Menu()
        self.device_info = Gtk.MenuItem(label="🔍 Scanne...")
        self.device_info.set_sensitive(False)
        self.menu.append(self.device_info)
        self.menu.append(Gtk.SeparatorMenuItem())
        
        rgb_menu = Gtk.MenuItem(label="🌈 RGB Farben")
        rgb_sub = Gtk.Menu()
        
        if self.openrgb.available:
            for name, rgb in [("🔴 Rot", (255,0,0)), ("🟢 Grün", (0,255,0)), ("🔵 Blau", (0,0,255)),
                              ("🟡 Gelb", (255,255,0)), ("🟣 Pink", (255,0,255)), ("⚪ Weiß", (255,255,255)),
                              ("🌑 Aus", (0,0,0))]:
                item = Gtk.MenuItem(label=name)
                item.connect("activate", self.set_openrgb_color, rgb)
                rgb_sub.append(item)
            self.menu.append(Gtk.SeparatorMenuItem())
            rescan_item = Gtk.MenuItem(label="🔄 Geräte neu scannen")
            rescan_item.connect("activate", self.rescan_devices)
            self.menu.append(rescan_item)
        else:
            for name, pattern in [("🔴 Rot (LED blinkt)", "rot"), ("🟢 Grün (LED blinkt)", "gruen"),
                                  ("🔵 Blau (LED blinkt)", "blau"), ("🟡 Gelb (LED an)", "gelb"),
                                  ("⚪ Aus", "aus")]:
                item = Gtk.MenuItem(label=name)
                item.connect("activate", self.set_led_pattern, pattern)
                rgb_sub.append(item)
        
        rgb_menu.set_submenu(rgb_sub)
        self.menu.append(rgb_menu)
        
        dash = Gtk.MenuItem(label="📊 Dashboard")
        dash.connect("activate", self.open_dashboard)
        self.menu.append(dash)
        
        self.menu.append(Gtk.SeparatorMenuItem())
        update_item = Gtk.MenuItem(label="🔄 System Update")
        update_item.connect("activate", lambda w: threading.Thread(target=system_update, daemon=True).start())
        self.menu.append(update_item)
        
        self.menu.append(Gtk.SeparatorMenuItem())
        quit_item = Gtk.MenuItem(label="❌ Beenden")
        quit_item.connect("activate", Gtk.main_quit)
        self.menu.append(quit_item)
        self.menu.show_all()
    
    def set_openrgb_color(self, widget, rgb):
        r, g, b = rgb
        self.openrgb.set_color(r, g, b)
        subprocess.run(["notify-send", "-a", "GameChanger", f"🌈 RGB", f"Farbe gesetzt: {r},{g},{b}"])
    
    def rescan_devices(self, widget):
        if self.openrgb.rescan():
            subprocess.run(["notify-send", "-a", "GameChanger", "🔄 RGB", "Geräte neu gescannt!"])
            if self.dashboard and self.dashboard.window.get_visible():
                self.dashboard.refresh(get_devices())
    
    def set_led_pattern(self, widget, pattern):
        if pattern == "aus":
            self.led.stop()
        else:
            if self.led.is_running():
                self.led.stop()
                time.sleep(0.1)
            threading.Thread(target=self.led.blink_pattern, args=(pattern, 2), daemon=True).start()
    
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
            if not self.led.is_running():
                threading.Thread(target=self.led.blink_pattern, args=("alarm", 2), daemon=True).start()
        elif lowest <= 20:
            self.indicator.set_icon("battery-low")
            self.device_info.set_label(f"⚠️ {count} Geräte - niedrig")
        else:
            self.indicator.set_icon("input-gaming")
            self.device_info.set_label(f"🎮 {count} Geräte")
        
        for _, name, level, _ in devices:
            if level != "??" and level <= 15 and level != self.last_alarm.get(name, 100):
                subprocess.run(["notify-send", "-u", "critical", f"⚠️ {name}", f"{level}%!"])
                if not self.led.is_running():
                    threading.Thread(target=self.led.blink_pattern, args=("alarm", 3), daemon=True).start()
                self.last_alarm[name] = level
            elif level != "??" and level > 20:
                self.last_alarm[name] = 100
        
        if self.dashboard and self.dashboard.window.get_visible():
            self.dashboard.refresh(devices)
        
        return True
    
    def open_dashboard(self, widget):
        if self.dashboard and self.dashboard.window.get_visible():
            self.dashboard.window.present()
            return
        self.dashboard = FloatingDashboard(self)
        self.dashboard.refresh(get_devices())
        self.dashboard.window.show_all()

if __name__ == "__main__":
    hub = GameChanger()
    Gtk.main()
EOF

chmod +x ~/.local/share/gamechanger/gamechanger.py

# ========== 5. STARTER ==========
cat > ~/.local/bin/gamechanger << 'EOF'
#!/bin/bash
if pgrep -f "gamechanger.py" > /dev/null; then
    echo "🎮 GameChanger läuft bereits!"
    exit 0
fi
nohup python3 ~/.local/share/gamechanger/gamechanger.py > /dev/null 2>&1 &
EOF
chmod +x ~/.local/bin/gamechanger

# ========== 6. GAME PROFILER (mit OpenRGB-Warteschleife) ==========
echo ""
echo "🎮 Installiere Game Profiler..."
cat > ~/.config/gamechanger/game_profiler.sh << 'EOF'
#!/bin/bash
# GameChanger Game Profiler - Automatische RGB Profile
# Mit OpenRGB-Warteschleife

PROFILES_DIR="$HOME/.config/gamechanger/profiles"
mkdir -p "$PROFILES_DIR"

# Final Fantasy XIV Profil
cat > "$PROFILES_DIR/final_fantasy.orp" << 'FFEOF'
{"profile":[{"name":"Final Fantasy XIV","colors":[{"name":"Keyboard","color":[255,0,0]},{"name":"Mouse","color":[255,0,0]},{"name":"RAM","color":[255,0,0]},{"name":"GPU","color":[255,0,0]}]}]}
FFEOF

# Desktop Profil
cat > "$PROFILES_DIR/desktop.orp" << 'DSEOF'
{"profile":[{"name":"Desktop","colors":[{"name":"Keyboard","color":[0,255,0]},{"name":"Mouse","color":[0,255,0]},{"name":"RAM","color":[0,255,0]},{"name":"GPU","color":[0,255,0]}]}]}
DSEOF

current_profile=""
load_profile() {
    local profile="$1"
    [ "$current_profile" = "$profile" ] && return
    if openrgb --profile "$PROFILES_DIR/$profile" 2>/dev/null; then
        current_profile="$profile"
        notify-send -a "GameChanger" "🎨 RGB" "$profile aktiviert"
    fi
}

echo "🔍 Warte auf OpenRGB..."
until openrgb --version > /dev/null 2>&1; do
    echo "⏳ OpenRGB noch nicht bereit, warte 2 Sekunden..."
    sleep 2
done
echo "✅ OpenRGB gefunden!"
echo "🎮 Game Profiler gestartet"

while true; do
    if pgrep -f "ffxiv" > /dev/null || pgrep -f "FINAL" > /dev/null; then
        load_profile "final_fantasy.orp"
    else
        load_profile "desktop.orp"
    fi
    sleep 10
done
EOF

chmod +x ~/.config/gamechanger/game_profiler.sh

# ========== 7. AUTOSTART ==========
cat > ~/.config/autostart/gamechanger.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=GameChanger
Exec=$HOME/.local/bin/gamechanger
Icon=battery-full
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

cat > ~/.config/autostart/gamechanger-profiler.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=GameChanger Profiler
Exec=$HOME/.config/gamechanger/game_profiler.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# ========== 8. DESKTOP-ENTRY ==========
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

# ========== 9. UDEV REGEL ==========
echo ""
echo "💡 Richte LED-Zugriff ein..."
sudo tee /etc/udev/rules.d/99-leds.rules << 'EOF'
SUBSYSTEM=="leds", ACTION=="add", RUN+="/bin/chgrp video /sys%p/brightness", RUN+="/bin/chmod g+w /sys%p/brightness"
EOF
sudo udevadm control --reload-rules
sudo groupadd video 2>/dev/null || true
sudo usermod -aG video $USER

# ========== 10. FERTIG! ==========
echo ""
echo "=========================================="
echo "✅ GameChanger Ultimate installiert!"
echo "=========================================="
echo ""
echo "🚀 Starte mit: gamechanger"
echo "🔄 Das Icon erscheint in der Taskleiste"
echo "🎮 Game Profiler: FFXIV → Rot, Desktop → Grün"
echo "🖱️ Dashboard: Mit Maus verschiebbar!"
echo ""
echo "💡 Nach dem Neustart startet GameChanger automatisch!"
