import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

PlasmaExtras.Representation {
    id: root
    width: 380
    height: contentItem.implicitHeight + PlasmaCore.Units.largeSpacing * 2
    
    property variant batteryData: ({})
    property variant hardwareData: ({})
    
    header: PlasmaExtras.Title {
        text: i18n("GameChanger – Gaming Control Center")
        icon: "input-gaming"
    }
    
    contentItem: ColumnLayout {
        id: contentItem
        spacing: PlasmaCore.Units.smallSpacing
        width: root.width
        
        PlasmaComponents.Label {
            text: i18n("⚡ System Status")
            font.bold: true
            opacity: 0.7
            Layout.fillWidth: true
            Layout.topMargin: PlasmaCore.Units.smallSpacing
        }
        
        GridLayout {
            columns: 2
            rowSpacing: PlasmaCore.Units.smallSpacing
            columnSpacing: PlasmaCore.Units.largeSpacing
            Layout.fillWidth: true
            
            PlasmaComponents.Label { text: "🌡️ GPU:" }
            PlasmaComponents.Label { text: (hardwareData.gpu_temp || "0") + "°C" }
            
            PlasmaComponents.Label { text: "🌀 GPU Lüfter:" }
            PlasmaComponents.Label { text: (hardwareData.gpu_fan || "0") + " RPM" }
            
            PlasmaComponents.Label { text: "🔥 CPU:" }
            PlasmaComponents.Label { text: (hardwareData.cpu_temp || "0") + "°C" }
            
            PlasmaComponents.Label { text: "📊 CPU Auslastung:" }
            PlasmaComponents.Label { text: (hardwareData.cpu_usage || "0") + "%" }
            
            PlasmaComponents.Label { text: "⚡ CPU Takt:" }
            PlasmaComponents.Label { text: (hardwareData.cpu_freq || "0") + " GHz" }
            
            PlasmaComponents.Label { text: "🧠 RAM:" }
            PlasmaComponents.Label { text: (hardwareData.ram_usage || "0") + "%" }
        }
        
        PlasmaComponents.Separator { Layout.fillWidth: true }
        
        PlasmaComponents.Label {
            text: i18n("🔋 Gaming Akkus")
            font.bold: true
            opacity: 0.7
            Layout.fillWidth: true
        }
        
        Repeater {
            model: Object.keys(batteryData).length > 0 ? Object.keys(batteryData) : ["Keine Geräte"]
            
            delegate: ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                
                visible: batteryData[modelData] !== undefined || modelData === "Keine Geräte"
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: PlasmaCore.Units.smallSpacing
                    
                    PlasmaCore.IconItem {
                        source: {
                            if (modelData === "Keine Geräte") return "dialog-warning"
                            if (modelData.includes("G502")) return "input-mouse"
                            if (modelData.includes("G515")) return "input-keyboard"
                            if (modelData.includes("PS5")) return "gamepad-symbolic"
                            return "battery-full"
                        }
                        width: PlasmaCore.Units.iconSizes.small
                        height: width
                    }
                    
                    PlasmaComponents.Label {
                        text: modelData === "Keine Geräte" ? "Keine Geräte gefunden" : modelData
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    
                    PlasmaComponents.Label {
                        visible: modelData !== "Keine Geräte"
                        text: (batteryData[modelData]?.percent || "0") + "%"
                        opacity: 0.7
                    }
                }
                
                PlasmaComponents.ProgressBar {
                    visible: modelData !== "Keine Geräte"
                    Layout.fillWidth: true
                    Layout.preferredHeight: PlasmaCore.Units.gridUnit * 0.8
                    value: (batteryData[modelData]?.percent || 0) / 100
                    
                    background: Rectangle {
                        color: PlasmaCore.ColorScope.backgroundColor
                        radius: 2
                    }
                    
                    contentItem: Rectangle {
                        color: {
                            var percent = batteryData[modelData]?.percent || 0
                            if (percent <= 10) return "#f38ba8"
                            if (percent <= 20) return "#fab387"
                            return "#a6e3a1"
                        }
                        radius: 2
                    }
                }
                
                PlasmaComponents.Label {
                    visible: modelData !== "Keine Geräte" && batteryData[modelData]?.charging === true
                    text: "⚡ LÄDT"
                    font.pointSize: 8
                    opacity: 0.6
                    Layout.alignment: Qt.AlignRight
                }
            }
        }
        
        PlasmaComponents.Button {
            text: i18n("📊 Dashboard öffnen")
            icon.name: "settings-configure"
            Layout.fillWidth: true
            Layout.topMargin: PlasmaCore.Units.smallSpacing
            onClicked: {
                dbusSource.call("OpenDashboard", "")
            }
        }
    }
    
    PlasmaCore.DataSource {
        id: dbusSource
        engine: "dbus"
        connected: true
        service: "org.gamechanger"
        path: "/org/gamechanger"
        interface: "org.gamechanger"
        
        onDataChanged: {
            var data = dbusSource.data["DataUpdated"]
            if (data) {
                try {
                    var json = JSON.parse(data.value)
                    if (json.battery) batteryData = json.battery
                    if (json.hardware) hardwareData = json.hardware
                } catch(e) {}
            }
        }
        
        function callGetData() {
            var reply = dbusSource.call("GetHardwareData", "")
            if (reply && reply.length > 0) {
                try {
                    var json = JSON.parse(reply[0])
                    if (json.battery) batteryData = json.battery
                    if (json.hardware) hardwareData = json.hardware
                } catch(e) {}
            }
        }
    }
    
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: dbusSource.callGetData()
    }
    
    Component.onCompleted: {
        dbusSource.callGetData()
    }
}
