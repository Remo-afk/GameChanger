# 🎮 GameChanger (Beta)

```text
  ____                         ____ _                                      
 / ___| __ _ _ __ ___   ___   / ___| |__   __ _ _ __   __ _  ___ _ __ 
| |  _ / _` | '_ ` _ \ / _ \ | |   | '_ \ / _` | '_ \ / _` |/ _ \ '__|
| |_| | (_| | | | | | |  __/ | |___| | | | (_| | | | | (_| |  __/ |   
 \____|\__,_|_| |_| |_|\___|  \____|_| |_|\__,_|_| |_|\__, |\___|_|   
                                                      |___/            
           🛡️  Hybrid Battery & Hardware Hub v1.0 BETA
           The smartest way to monitor your gaming gear on Linux.
cat > /mnt/Vault/Dev/GameChanger/README.md << 'EOF'
# 🎮 GameChanger v2.1 – The Ultimate Gaming Control Center

**GameChanger** ist ein vollständiges Gaming-Kontrollzentrum für CachyOS/Arch Linux. Es überwacht deine Hardware, steuert RGB-Beleuchtung und passt sich automatisch an deine Spiele an – alles in einem eleganten Tray-Icon.

[![GitHub Release](https://img.shields.io/github/v/release/Remo-afk/GameChanger)](https://github.com/Remo-afk/GameChanger/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![AUR](https://img.shields.io/aur/version/gamechanger)](https://aur.archlinux.org/packages/gamechanger)

---

## ✨ Features

### 🖥️ Hardware-Monitoring
- **GPU** – Temperatur, Lüftergeschwindigkeit (AMD/amdgpu)
- **CPU** – Temperatur, Auslastung, Taktrate (AMD/k10temp)
- **RAM** – Aktuelle Auslastung
- **Echtzeit-Updates** – Alle 3 Sekunden im Tray

### 🔋 Akku-Monitoring
- 🖱️ **Logitech G502 X / G515** – Akkustand in Prozent
- 🎮 **PS5 DualSense** – Akku-Warnung mit LED-Alarm
- 🎧 **NUBWO G06** – Automatische Headset-Erkennung
- ⚡ **Lade-Status** – Erkennung, ob Gerät lädt

### 🌈 RGB-Steuerung (OpenRGB SDK)
- **Direkte Anbindung** – Kein subprocess, keine Verzögerung
- **7 Farben** – Rot, Grün, Blau, Gelb, Pink, Weiß, Aus
- **Auto-Fallback** – LED-Modus (Caps/Num Lock) wenn OpenRGB nicht verfügbar

### 🎮 Game Profiler
- **Automatische Erkennung** – RGB wechselt beim Spielstart
- **GUI-Editor** – Spiele hinzufügen, löschen, Farben wählen
- **Beispiele** – Final Fantasy XIV → Rot, Cyberpunk → Pink
- **Einfach erweiterbar** – JSON-Konfiguration im Hintergrund

### 📊 Dashboard
- **Schwebendes Fenster** – Verschiebbar, ohne Rahmen
- **LevelBars** – RPG-ähnliche Gesundheitsbalken für Akkus
- **Hardware-Übersicht** – Alle wichtigen Werte auf einen Blick

### 🛠️ System-Tools
- **System Update** – Ein-Klick mit `cachyos-rate-mirrors`
- **Autostart** – Startet mit deinem System
- **Tray-Icon** – Farbcodierte Warnungen (Rot = kritisch)
---
## 📦 Installation

### AUR (empfohlen)
```bash
paru -S gamechanger
# oder
yay -S gamechanger
