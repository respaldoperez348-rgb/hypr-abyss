import QtQuick
import Quickshell
import Quickshell.Io

/**
 * HackerStats.qml
 * Módulo de estado del sistema: CPU, WiFi, Bluetooth y Batería (Sin RAM).
 * Diseñado con componentes vectoriales nativos para garantizar nitidez total
 * en pantallas con escalado fraccional (1.5x) y sin depender de fuentes externas rotas.
 * 
 * Interacciones:
 * - Clic en WiFi: expande nombre de red (SSID); segundo clic lo contrae a estado normal.
 * - Clic en BT: expande nombre de dispositivo conectado; segundo clic lo contrae.
 * - Clic en Batería: expande estado detallado (Charging/Discharging); segundo clic lo contrae.
 */
Item {
    id: root

    property var theme
    property int cpu: 0
    property int bat: 100
    property string batStatus: "Full"
    property string batTime: ""
    property string batDetail: ""
    property string wifiSsid: "Disconnected"
    property int wifiSignal: 0
    property bool bt: false
    property string btDevice: ""

    // Propiedades sincronizadas para OSD y ventana activa
    property int volume: -1
    property bool volMuted: false
    property int brightness: -1
    property string activeApp: "Desktop"
    property bool initialLoadDone: false

    signal osdTriggered(string osdType, int osdValue, bool osdMuted)
    signal openControlCenterRequested()

    // Estados de expansión por clic
    property bool showWifiName: false
    property bool showBtName: false
    property bool showBatDetail: false

    implicitHeight: 20
    implicitWidth: statsRow.implicitWidth

    // Proceso que ejecuta scripts/stats.sh
    Process {
        id: statsProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/stats.sh"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    if (data.cpu !== undefined) root.cpu = data.cpu;
                    if (data.bat !== undefined) root.bat = data.bat;
                    if (data.bat_status) root.batStatus = data.bat_status;
                    if (data.bat_time !== undefined) root.batTime = data.bat_time;
                    if (data.bat_detail) root.batDetail = data.bat_detail;
                    if (data.wifi_ssid) root.wifiSsid = data.wifi_ssid;
                    if (data.wifi_signal !== undefined) root.wifiSignal = data.wifi_signal;
                    if (data.bt !== undefined) root.bt = data.bt;
                    if (data.bt_device !== undefined) root.btDevice = data.bt_device;
                    if (data.active_app) root.activeApp = data.active_app;

                    if (data.volume !== undefined) {
                        var newVol = data.volume;
                        var newMuted = !!data.vol_muted;
                        if (root.initialLoadDone && (newVol !== root.volume || newMuted !== root.volMuted)) {
                            root.osdTriggered("volume", newVol, newMuted);
                        }
                        root.volume = newVol;
                        root.volMuted = newMuted;
                    }

                    if (data.brightness !== undefined) {
                        var newBri = data.brightness;
                        if (root.initialLoadDone && newBri !== root.brightness) {
                            root.osdTriggered("brightness", newBri, false);
                        }
                        root.brightness = newBri;
                    }

                    root.initialLoadDone = true;
                } catch (e) {
                    // Ignora streams incompletos
                }
            }
        }
    }

    // Proceso que conmuta el encendido y apagado de Bluetooth
    Process {
        id: btToggleProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/bt_toggle.sh"]
        running: false
        onExited: {
            if (!statsProc.running) {
                statsProc.running = true;
            }
        }
    }

    // Temporizador para contraer suavemente el estado tras mostrar feedback
    Timer {
        id: btFeedbackTimer
        interval: 2500
        repeat: false
        onTriggered: {
            root.showBtName = false;
        }
    }

    Timer {
        id: updateTimer
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!statsProc.running) {
                statsProc.running = true;
            }
        }
    }

    Row {
        id: statsRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // ==========================================
        // 1. CPU (Texto nítido + punto neón)
        // ==========================================
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 4
                radius: 2
                color: root.cpu >= 80 
                       ? (root.theme ? root.theme.danger : "#ff5555") 
                       : (root.theme ? root.theme.accent : "#00ffcc")
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CPU"
                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                font.pixelSize: 9
                font.bold: true
                color: root.theme ? root.theme.textDim : "#6e7681"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.cpu < 10 ? "0" : "") + root.cpu + "%"
                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                font.pixelSize: 10
                font.bold: true
                color: root.theme ? root.theme.text : "#f0f6fc"
            }
        }

        // Separador
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 9
            color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.12)
        }

        // ==========================================
        // 2. WiFi (Píldora interactiva click-to-expand)
        // ==========================================
        Rectangle {
            id: wifiPill
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            width: wifiRow.implicitWidth + 8
            radius: 10

            color: wifiMouse.containsMouse 
                   ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.08)) 
                   : (root.showWifiName 
                      ? (root.theme ? root.theme.surfaceActive : Qt.rgba(1, 1, 1, 0.06)) 
                      : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.03)))

            border.width: 1
            border.color: wifiMouse.containsMouse 
                          ? (root.theme ? root.theme.borderHover : "#00ffcc") 
                          : (root.showWifiName 
                             ? (root.theme ? root.theme.accent : "#00ffcc") 
                             : (root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.08)))

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            MouseArea {
                id: wifiMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        root.openControlCenterRequested();
                    } else {
                        root.showWifiName = !root.showWifiName;
                    }
                }
            }

            Row {
                id: wifiRow
                anchors.centerIn: parent
                spacing: 5

                // Barras vectoriales de señal
                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    spacing: 1.5

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: 2
                        height: 3
                        radius: 0.5
                        color: root.wifiSignal >= 15 ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.2)
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: 2
                        height: 6
                        radius: 0.5
                        color: root.wifiSignal >= 40 ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.2)
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: 2
                        height: 9
                        radius: 0.5
                        color: root.wifiSignal >= 65 ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.2)
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: 2
                        height: 12
                        radius: 0.5
                        color: root.wifiSignal >= 85 ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.2)
                    }
                }

                // Contenedor animado del nombre SSID (se abre y cierra al hacer clic)
                Item {
                    id: wifiNameContainer
                    visible: width > 0
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14
                    implicitWidth: ssidLabel.implicitWidth
                    width: root.showWifiName ? implicitWidth : 0
                    opacity: root.showWifiName ? 1.0 : 0.0

                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                    }

                    Text {
                        id: ssidLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.wifiSsid && root.wifiSsid !== "Disconnected") ? root.wifiSsid : "Offline"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 9
                        font.bold: true
                        color: (root.wifiSsid && root.wifiSsid !== "Disconnected") 
                               ? (root.theme ? root.theme.accent : "#00ffcc") 
                               : (root.theme ? root.theme.danger : "#ff5555")
                    }
                }
            }
        }

        // ==========================================
        // 3. Bluetooth (Píldora interactiva 'BT')
        // ==========================================
        Rectangle {
            id: btPill
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            width: btRow.implicitWidth + 8
            radius: 10

            color: btMouse.containsMouse 
                   ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.08)) 
                   : (root.showBtName 
                      ? (root.theme ? root.theme.surfaceActive : Qt.rgba(1, 1, 1, 0.06)) 
                      : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.03)))

            border.width: 1
            border.color: btMouse.containsMouse 
                          ? (root.theme ? root.theme.borderHover : "#00ffcc") 
                          : (root.showBtName 
                             ? (root.theme ? root.theme.accentAlt : "#bd93f9") 
                             : (root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.08)))

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            MouseArea {
                id: btMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        root.openControlCenterRequested();
                    } else {
                        // 1. Conmutar el estado en la interfaz de inmediato
                        root.bt = !root.bt;
                        if (!root.bt) {
                            root.btDevice = "";
                        }
                        // 2. Mostrar la etiqueta con el nuevo estado (ON / OFF)
                        root.showBtName = true;
                        btFeedbackTimer.restart();

                        // 3. Ejecutar bluetoothctl power on/off mediante el script
                        if (!btToggleProc.running) {
                            btToggleProc.running = true;
                        }
                    }
                }
            }

            Row {
                id: btRow
                anchors.centerIn: parent
                spacing: 4

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 4
                    radius: 2
                    color: root.bt ? (root.theme ? root.theme.accentAlt : "#bd93f9") : Qt.rgba(1, 1, 1, 0.2)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BT"
                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                    font.pixelSize: 9
                    font.bold: true
                    color: root.bt ? (root.theme ? root.theme.accentAlt : "#bd93f9") : (root.theme ? root.theme.textDim : "#6e7681")
                    opacity: root.bt ? 1.0 : 0.4
                }

                // Contenedor animado del dispositivo o estado BT
                Item {
                    id: btDetailContainer
                    visible: width > 0
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14
                    implicitWidth: btDetailText.implicitWidth
                    width: root.showBtName ? implicitWidth : 0
                    opacity: root.showBtName ? 1.0 : 0.0

                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                    }

                    Text {
                        id: btDetailText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.btDevice.length > 0 ? root.btDevice : (root.bt ? "ON" : "OFF")
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 9
                        font.bold: true
                        color: root.bt 
                               ? (root.btDevice.length > 0 ? (root.theme ? root.theme.text : "#f0f6fc") : (root.theme ? root.theme.accentAlt : "#bd93f9"))
                               : (root.theme ? root.theme.danger : "#ff5555")
                    }
                }
            }
        }

        // Separador
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 9
            color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.12)
        }

        // ==========================================
        // 4. Batería (Píldora interactiva con nivel)
        // ==========================================
        Rectangle {
            id: batPill
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            width: batRow.implicitWidth + 8
            radius: 10

            color: batMouse.containsMouse 
                   ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.08)) 
                   : (root.showBatDetail 
                      ? (root.theme ? root.theme.surfaceActive : Qt.rgba(1, 1, 1, 0.06)) 
                      : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.03)))

            border.width: 1
            border.color: batMouse.containsMouse 
                          ? (root.theme ? root.theme.borderHover : "#00ffcc") 
                          : (root.showBatDetail 
                             ? (root.theme ? root.theme.accent : "#00ffcc") 
                             : (root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.08)))

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            MouseArea {
                id: batMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.showBatDetail = !root.showBatDetail;
                }
            }

            Row {
                id: batRow
                anchors.centerIn: parent
                spacing: 4

                // Chasis vectorial de la batería
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Rectangle {
                        width: 18
                        height: 9
                        radius: 2
                        color: "transparent"
                        border.width: 1
                        border.color: root.bat <= 20 
                                      ? (root.theme ? root.theme.danger : "#ff5555") 
                                      : (root.theme ? root.theme.textDim : "#6e7681")

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 1.5
                            width: Math.max(1, (parent.width - 3) * Math.min(1.0, root.bat / 100.0))
                            radius: 1

                            color: {
                                if (root.batStatus === "Charging") return root.theme ? root.theme.accent : "#00ffcc";
                                if (root.bat <= 20) return root.theme ? root.theme.danger : "#ff5555";
                                if (root.bat <= 40) return root.theme ? root.theme.warning : "#ffb86c";
                                return root.theme ? root.theme.cpuColor : "#50fa7b";
                            }
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1.5
                        height: 4
                        radius: 0.5
                        color: root.theme ? root.theme.textDim : "#6e7681"
                    }
                }

                // Porcentaje
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.batStatus === "Charging" ? "⚡" : "") + root.bat + "%"
                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                    font.pixelSize: 10
                    font.bold: true
                    color: root.theme ? root.theme.text : "#f0f6fc"
                }

                // Contenedor animado de estado de batería (Charging / Discharging)
                Item {
                    id: batDetailContainer
                    visible: width > 0
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14
                    implicitWidth: batDetailText.implicitWidth
                    width: root.showBatDetail ? implicitWidth : 0
                    opacity: root.showBatDetail ? 1.0 : 0.0

                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                    }

                    Text {
                        id: batDetailText
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (root.batDetail) return root.batDetail;
                            if (root.batTime) {
                                if (root.batStatus === "Discharging") return root.batTime + " restantes";
                                if (root.batStatus === "Charging") return "Cargando (" + root.batTime + ")";
                            }
                            if (root.batStatus === "Charging") return "Cargando";
                            if (root.batStatus === "Full") return "Completa";
                            return "Calculando...";
                        }
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 9
                        font.bold: true
                        color: {
                            if (root.batStatus === "Charging") return root.theme ? root.theme.accent : "#00ffcc";
                            if (root.bat <= 20) return root.theme ? root.theme.danger : "#ff5555";
                            if (root.bat <= 40) return root.theme ? root.theme.warning : "#ffb86c";
                            return root.theme ? root.theme.accent : "#00ffcc";
                        }
                    }
                }
            }
        }
    }
}
