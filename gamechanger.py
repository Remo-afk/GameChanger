#!/usr/bin/env python3
"""
GameChanger v2.0 - Ultimate Gaming Control Center
Mit intelligenter Hardware-Erkennung, OpenRGB-Wait und CPU-Auslastung
"""

import os
import time
import subprocess
import threading
import gi
import glob
import psutil
import json

gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, GLib, AppIndicator3, Gdk

SYS_PATH = "/sys/class/power_supply/"
HWMON_PATH = "/sys/class/hwmon/"

# ========== HARDWARE-MONITORING (Intelligent) ==========
class HardwareMonitor:
    def __init__(self):
        self.gpu_temp = 0
        self.gpu_fan = 0
        self.cpu_temp = 0
        self.cpu_usage = 0
        self.cpu_freq = 0
        self.ram_usage = 0
        
    def update(self):
        # Dynamische Erkennung von GPU und CPU über name-Datei
        for hwmon in glob.glob(HWMON_PATH + "hwmon*"):
            name_file = os.path.join(hwmon, "name")
            if not os.path.exists(name_file):
                continue
            try:
                with open(name_file) as f:
                    name = f.read().strip()
                
                # AMD GPU (Sapphire)
                if name == "amdgpu":
                    # Temperatur
                    temp_file = os.path.join(hwmon, "temp1_input")
                    if os.path.exists(temp_file):
                        with open(temp_file) as f:
                            self.gpu_temp = int(f.read().strip()) / 1000
                    # Lüfter
                    fan_file = os.path.join(hwmon, "fan1_input")
                    if os.path.exists(fan_file):
                        with open(fan_file) as f:
                            self.gpu_fan = int(f.read().strip())
                
                # AMD CPU (Ryzen 9600X)
                elif name == "k10temp":
                    temp_file = os.path.join(hwmon, "temp1_input")
                    if os.path.exists(temp_file):
                        with open(temp_file) as f:
                            self.cpu_temp = int(f.read().strip()) / 1000
            except:
                continue
        
        # CPU Auslastung & Frequenz
        self.cpu_usage = psutil.cpu_percent()
        self.cpu_freq = psutil.cpu_freq().current / 1000 if psutil.cpu_freq() else 0
        
        # RAM Auslastung
        self.ram_usage = psutil.virtual_memory().percent
    
    def get_status_text(self):
        return f"🌡️ GPU: {self.gpu_temp:.0f}°C  🌀 Lüfter: {self.gpu_fan} RPM\n" \
               f"🔥 CPU: {self.cpu_temp:.0f}°C  📊 {self.cpu_usage:.0f}%  ⚡ {self.cpu_freq:.1f} GHz\n" \
               f"🧠 RAM: {self.ram_usage}%"

# ========== RGB CONTROLLER (mit OpenRGB-Wait) ==========
class RGBController:
    def __init__(self):
        self.available = False
        self.client = None
        self.devices = []
        self.wait_for_openrgb()
        
    def wait_for_openrgb(self, timeout=10):
        """Wartet auf OpenRGB-Server mit Retry"""
        print("🔍 Warte auf OpenRGB...")
        start = time.time()
        while time.time() - start < timeout:
            try:
                import openrgb
                from openrgb.utils import RGBColor
                self.client = openrgb.OpenRGBClient()
                self.available = True
                self.devices = self.client.devices
                print(f"✅ OpenRGB gefunden: {len(self.devices)} Geräte")
                return True
            except:
                time.sleep(1)
        print("⚠️ OpenRGB nicht verfügbar (Timeout)")
        return False
    
    def set_color(self, r, g, b):
        if not self.available:
            return False
        try:
            from openrgb.utils import RGBColor
            for device in self.devices:
                device.set_color(RGBColor(r, g, b))
            return True
        except:
            return False
    
    def set_device_color(self, device_name, r, g, b):
        if not self.available:
            return False
        try:
            from openrgb.utils import RGBColor
            for device in self.devices:
                if device_name.lower() in device.name.lower():
                    device.set_color(RGBColor(r, g, b))
                    return True
        except:
            pass
        return False

# ========== GAME PROFILER ==========
class GameProfiler:
    def __init__(self):
        self.profiles_dir = os.path.expanduser("~/.config/gamechanger/profiles")
        os.makedirs(self.profiles_dir, exist_ok=True)
        self.load_profiles()
    
    def load_profiles(self):
        profile_file = os.path.join(self.profiles_dir, "profiles.json")
        if os.path.exists(profile_file):
            with open(profile_file) as f:
                self.profiles = json.load(f)
        else:
            # Standard-Profile
            self.profiles = {
                "Final Fantasy XIV": {
                    "rgb": [255, 0, 0],
                    "performance": "gaming",
                    "process": "ffxiv"
                },
                "Cyberpunk 2077": {
                    "rgb": [255, 0, 255],
                    "performance": "gaming",
                    "process": "Cyberpunk2077"
                },
                "Desktop": {
                    "rgb": [0, 255, 0],
                    "performance": "powersave",
                    "process": ""
                }
            }
            self.save_profiles()
    
    def save_profiles(self):
        profile_file = os.path.join(self.profiles_dir, "profiles.json")
        with open(profile_file, 'w') as f:
            json.dump(self.profiles, f, indent=2)
    
    def check_active_game(self):
        for name, profile in self.profiles.items():
            if profile.get("process") and profile["process"]:
                if subprocess.run(["pgrep", "-f", profile["process"]], capture_output=True).returncode == 0:
                    return name, profile
        return "Desktop", self.profiles.get("Desktop", {"rgb": [0,255,0]})

# ========== AKKU LOGIK ==========
def get_battery_devices():
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
    subprocess.Popen(["konsole", "-e", "bash", "-c", 
        f"echo '🔄 System-Update...'; {cmd}; echo ''; echo '✅ Fertig! Drücke Enter'; read"])

# ========== DASHBOARD ==========
class FloatingDashboard:
    def __init__(self, parent):
        self.parent = parent
        self.window = Gtk.Window()
        self.window.set_title("🎮 GameChanger")
        self.window.set_default_size(480, 650)
        self.window.set_position(Gtk.WindowPosition.CENTER)
        self.window.set_border_width(20)
        self.window.set_decorated(False)
        self.window.set_keep_above(False)
        
        # Dragging
        self.drag_start_x = 0
        self.drag_start_y = 0
        self.dragging = False
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
        .section { background-color: #313244; border-radius: 12px; padding: 10px; margin: 5px 0; }
        .level-bar { min-height: 8px; border-radius: 4px; }
        levelbar trough { background-color: #1e1e2e; border-radius: 4px; }
        .good block.filled { background-color: #a6e3a1; }
        .warning block.filled { background-color: #fab387; }
        .critical block.filled { background-color: #f38ba8; }
        button { background-color: #45475a; color: #cdd6f4; border-radius: 8px; padding: 5px 10px; }
        button:hover { background-color: #585b70; }
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
        title.set_markup("<span size='x-large'>🎮 GameChanger v2.0</span>")
        title.get_style_context().add_class("title")
        header.pack_start(title, True, True, 0)
        close_btn = Gtk.Button(label="✕")
        close_btn.connect("clicked", lambda x: self.window.hide())
        close_btn.set_size_request(30, 30)
        header.pack_end(close_btn, False, False, 0)
        self.box.pack_start(header, False, False, 0)
        
        # Hardware Status
        self.hardware_label = Gtk.Label()
        self.hardware_label.set_markup("<span size='large'>🌡️ Hardware</span>")
        self.box.pack_start(self.hardware_label, False, False, 0)
        
        self.hardware_data = Gtk.Label()
        self.hardware_data.set_markup("Lade...")
        self.box.pack_start(self.hardware_data, False, False, 5)
        
        # Batteries
        self.battery_label = Gtk.Label()
        self.battery_label.set_markup("<span size='large'>🔋 Akkus</span>")
        self.box.pack_start(self.battery_label, False, False, 0)
        
        self.battery_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.box.pack_start(self.battery_container, False, False, 5)
        
        # Buttons
        btn_box = Gtk.Box(spacing=10)
        refresh_btn = Gtk.Button(label="🔄 Aktualisieren")
        refresh_btn.connect("clicked", self.refresh)
        btn_box.pack_start(refresh_btn, True, True, 0)
        
        update_btn = Gtk.Button(label="🔄 System Update")
        update_btn.connect("clicked", lambda x: threading.Thread(target=system_update, daemon=True).start())
        btn_box.pack_start(update_btn, True, True, 0)
        
        self.box.pack_start(btn_box, False, False, 0)
        
        self.window.show_all()
        self.refresh()
    
    def on_button_press(self, widget, event):
        if event.button == 1:
            self.drag_start_x = event.x_root - self.window.get_position()[0]
            self.drag_start_y = event.y_root - self.window.get_position()[1]
            self.dragging = True
    
    def on_button_release(self, widget, event):
        self.dragging = False
    
    def on_motion(self, widget, event):
        if self.dragging:
            new_x = int(event.x_root - self.drag_start_x)
            new_y = int(event.y_root - self.drag_start_y)
            self.window.move(new_x, new_y)
    
    def refresh(self, widget=None):
        # Hardware
        self.parent.hardware.update()
        self.hardware_data.set_markup(self.parent.hardware.get_status_text())
        
        # Batteries
        for child in self.battery_container.get_children():
            self.battery_container.remove(child)
        
        devices = get_battery_devices()
        for icon, name, level, charging in devices:
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
            card.get_style_context().add_class("section")
            
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
                level_bar.set_size_request(200, 8)
                level_bar.get_style_context().add_class("level-bar")
                if level <= 10:
                    level_bar.get_style_context().add_class("critical")
                elif level <= 20:
                    level_bar.get_style_context().add_class("warning")
                else:
                    level_bar.get_style_context().add_class("good")
                
                level_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                level_box.pack_start(level_bar, True, True, 0)
                percent_label = Gtk.Label()
                percent_label.set_markup(f"{level}%")
                level_box.pack_start(percent_label, False, False, 0)
                card.pack_start(level_box, False, False, 0)
            
            self.battery_container.pack_start(card, False, False, 0)
        
        self.battery_container.show_all()

# ========== HAUPTKLASSE ==========
class GameChanger:
    def __init__(self):
        self.indicator = AppIndicator3.Indicator.new("gamechanger", "input-gaming", AppIndicator3.IndicatorCategory.SYSTEM_SERVICES)
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        
        self.hardware = HardwareMonitor()
        self.rgb = RGBController()
        self.profiler = GameProfiler()
        self.dashboard = None
        self.last_alarm = {}
        
        self.build_menu()
        self.indicator.set_menu(self.menu)
        
        # Updates
        GLib.timeout_add_seconds(30, self.update_battery)
        GLib.timeout_add_seconds(3, self.update_hardware)  # Hardware öfter aktualisieren
        self.update_battery()
        self.update_hardware()
        
        print("🎮 GameChanger v2.0 läuft")
        if self.rgb.available:
            print(f"✅ RGB aktiv ({len(self.rgb.devices)} Geräte)")
    
    def build_menu(self):
        self.menu = Gtk.Menu()
        
        # Geräte-Info
        self.device_info = Gtk.MenuItem(label="🔍 Scanne...")
        self.device_info.set_sensitive(False)
        self.menu.append(self.device_info)
        self.menu.append(Gtk.SeparatorMenuItem())
        
        # Hardware Status
        self.hardware_info = Gtk.MenuItem(label="🌡️ Hardware...")
        self.hardware_info.set_sensitive(False)
        self.menu.append(self.hardware_info)
        self.menu.append(Gtk.SeparatorMenuItem())
        
        # RGB Menü
        if self.rgb.available:
            rgb_menu = Gtk.MenuItem(label="🌈 RGB Farben")
            rgb_sub = Gtk.Menu()
            for name, rgb in [("🔴 Rot", (255,0,0)), ("🟢 Grün", (0,255,0)), ("🔵 Blau", (0,0,255)),
                              ("🟡 Gelb", (255,255,0)), ("🟣 Pink", (255,0,255)), ("⚪ Weiß", (255,255,255)),
                              ("🌑 Aus", (0,0,0))]:
                item = Gtk.MenuItem(label=name)
                item.connect("activate", self.set_rgb, rgb)
                rgb_sub.append(item)
            rgb_menu.set_submenu(rgb_sub)
            self.menu.append(rgb_menu)
        
        # Dashboard
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
    
    def set_rgb(self, widget, rgb):
        self.rgb.set_color(*rgb)
        subprocess.run(["notify-send", "-a", "GameChanger", f"🌈 RGB", f"Farbe gesetzt: {rgb}"])
    
    def update_hardware(self):
        self.hardware.update()
        self.hardware_info.set_label(f"🌡️ GPU: {self.hardware.gpu_temp:.0f}°C  🌀 {self.hardware.gpu_fan} RPM  |  🔥 CPU: {self.hardware.cpu_temp:.0f}°C  📊 {self.hardware.cpu_usage:.0f}%")
        return True
    
    def update_battery(self):
        devices = get_battery_devices()
        count = len(devices)
        
        # Game Profiler
        game, profile = self.profiler.check_active_game()
        if game != "Desktop":
            self.device_info.set_label(f"🎮 {game} aktiv")
            if self.rgb.available:
                self.rgb.set_color(*profile.get("rgb", [0,255,0]))
        else:
            self.device_info.set_label(f"🎮 {count} Geräte")
        
        # Warnungen
        for _, name, level, _ in devices:
            if level != "??" and level <= 15 and level != self.last_alarm.get(name, 100):
                subprocess.run(["notify-send", "-u", "critical", f"⚠️ {name}", f"{level}%!"])
                self.last_alarm[name] = level
        
        return True
    
    def open_dashboard(self, widget):
        if self.dashboard and self.dashboard.window.get_visible():
            self.dashboard.window.present()
            return
        self.dashboard = FloatingDashboard(self)
        self.dashboard.window.show_all()

if __name__ == "__main__":
    hub = GameChanger()
    Gtk.main()
