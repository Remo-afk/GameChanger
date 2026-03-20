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

GameChanger bridges the gap between the Linux kernel and your hardware. It monitors batteries and triggers intelligent visual alerts using whatever your system offers.
✨ Key Features
🛡️ Hybrid Alert System

    OpenRGB Mode: Full RGB effects on compatible keyboards

    LED Fallback: Caps/Num/Scroll Lock LEDs blink automatically (No OpenRGB needed!)

    Desktop Notifications: Always active as a reliable backup

🎮 Universal Recognition

    ✅ PS5 DualSense Controller (Full support)

    ✅ Logitech G-Series (G502 X, G515, etc.)

    ✅ NUBWO G06 Wireless Headset (Auto-discovery)

    ✅ Generic HID: Any device reporting battery to the Linux kernel

🎯 Smart Detection

    No-Sudo LED Access: Installer sets up permissions for blinking alerts

    Resource Friendly: Optimized for high-end systems (developed on PCIe 5.0 SSD)

    Zero Bloat: Pure Python, minimal dependencies

🛠️ Installation

git clone https://github.com/Remo-afk/GameChanger.git
cd GameChanger
chmod +x install.sh
./install.sh

🚀 How to use

    Terminal: Simply type gc or gamechanger to see the live monitor

    Autostart: The DBus service runs in the background and warns you via LEDs/RGB

💡 Why GameChanger?

Most Linux battery monitors just show numbers. GameChanger makes you FEEL when your gear is dying:

    RGB Users: Your whole keyboard pulses red when the PS5 controller hits 15%

    Budget/Clean Setups: Your Caps Lock LED flashes – impossible to miss even in-game!

    Zero Config: It detects what you have and chooses the best warning method

🤝 Contributing & Beta Testing

This is a BETA. I need your help to grow:

    Test the Alerts: Does your keyboard blink?

    Report Hardware: If a device shows as "Unknown", open an Issue with your lsusb output

    NUBWO Users: Help me decode the raw battery percentage for the G06!

📄 License

MIT - Free for everyone.

Made for gamers, by gamers! 🔥
