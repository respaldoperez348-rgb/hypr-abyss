import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * TelemetryPod.qml - Pod Derecho del Hyper-Utility Glass Deck
 * Estética de Tacómetros Circulares HUD y Reloj de Misión Crítica.
 * - 3 Micro-tacómetros circulares de cristal: CPU, RAM y BATERÍA.
 * - Reloj digital nítido con fecha.
 * - Iconos de estado de Red (WiFi) y Volumen.
 * - Clic en cualquier punto despliega el Centro de Control lateral.
 */
Item {
    id: root

    property var theme
    readonly property Item podCard: card
    signal openControlCenterRequested()
    signal openSectionRequested(string section)

    Process {
        id: cmdProc
        command: []
        running: false
    }

    function launchCommand(cmd) {
        cmdProc.command = ["bash", "-c", cmd];
        cmdProc.running = true;
    }

    implicitHeight: card.height
    implicitWidth: card.width

    // Datos de Telemetría
    property int cpuVal: 0
    property int ramVal: 0
    property int batVal: 100
    property string batStatus: "Discharging"
    property string wifiSsid: "Connected"
    property int wifiSignal: 0
    property int volumeVal: 50
    property bool volMuted: false

    // Proceso de telemetría de alta velocidad
    Process {
        id: statsProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/stats.sh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    if (data.cpu !== undefined) root.cpuVal = data.cpu;
                    if (data.ram !== undefined) root.ramVal = data.ram;
                    if (data.bat !== undefined) root.batVal = data.bat;
                    if (data.bat_status) root.batStatus = data.bat_status;
                    if (data.wifi_ssid) root.wifiSsid = data.wifi_ssid;
                    if (data.wifi_signal !== undefined) root.wifiSignal = data.wifi_signal;
                    if (data.volume !== undefined) root.volumeVal = data.volume;
                    if (data.vol_muted !== undefined) root.volMuted = data.vol_muted;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statsProc.running) {
                statsProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/stats.sh"];
                statsProc.running = true;
            }
        }
    }

    // Reloj y Fecha en tiempo real
    property string currentTime: "00:00"
    property string currentDate: "LUN 01 ENE"

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date();
            var hours = now.getHours().toString().padStart(2, '0');
            var mins = now.getMinutes().toString().padStart(2, '0');
            root.currentTime = hours + ":" + mins;

            var days = ["DOM", "LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB"];
            var months = ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"];
            var dName = days[now.getDay()];
            var dNum = now.getDate().toString().padStart(2, '0');
            var mName = months[now.getMonth()];
            root.currentDate = dName + " " + dNum + " " + mName;
        }
    }

    // ==========================================
    // Cápsula Visual Frosted Glass
    // ==========================================
    Rectangle {
        id: card
        height: 32
        width: contentRow.implicitWidth + 24
        radius: 16

        color: root.theme ? root.theme.background : Qt.rgba(0.05, 0.07, 0.09, 0.75)
        border.width: 1.2
        border.color: podMouse.containsMouse
                      ? (root.theme ? root.theme.accent : "#00ffcc")
                      : (root.theme ? root.theme.border : Qt.rgba(0, 1, 0.8, 0.28))

        Behavior on border.color { ColorAnimation { duration: 200 } }

        // Resplandor exterior neón
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.width: 1
            border.color: root.theme ? root.theme.accentGlow : Qt.rgba(0, 1, 0.8, 0.20)
            opacity: podMouse.containsMouse ? 1.0 : 0.4
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        MouseArea {
            id: podMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 9

            // ----------------------------------------------------
            // 1. Tacómetros HUD Circulares (CPU, RAM, BATERÍA)
            // ----------------------------------------------------
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Tacómetro 1: CPU (Cian Neón)
                Item {
                    width: 24
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: cpuCanvas
                        anchors.fill: parent
                        property int pct: root.cpuVal
                        onPctChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            // Fondo pista
                            ctx.beginPath();
                            ctx.arc(12, 12, 9, 0, 2 * Math.PI);
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.10)";
                            ctx.lineWidth = 2.2;
                            ctx.stroke();
                            // Arco de progreso
                            ctx.beginPath();
                            var start = -Math.PI / 2;
                            var end = start + Math.min(1.0, Math.max(0.05, pct / 100)) * (2 * Math.PI);
                            ctx.arc(12, 12, 9, start, end);
                            ctx.strokeStyle = pct > 80 ? "#ff5555" : (root.theme ? root.theme.accent : "#00ffcc");
                            ctx.lineWidth = 2.2;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.cpuVal.toString()
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 8
                        font.bold: true
                        color: root.theme ? root.theme.accent : "#00ffcc"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openSectionRequested("cpu")
                    }
                }

                // Tacómetro 2: RAM (Verde Neón)
                Item {
                    width: 24
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: ramCanvas
                        anchors.fill: parent
                        property int pct: root.ramVal
                        onPctChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.beginPath();
                            ctx.arc(12, 12, 9, 0, 2 * Math.PI);
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.10)";
                            ctx.lineWidth = 2.2;
                            ctx.stroke();

                            ctx.beginPath();
                            var start = -Math.PI / 2;
                            var end = start + Math.min(1.0, Math.max(0.05, pct / 100)) * (2 * Math.PI);
                            ctx.arc(12, 12, 9, start, end);
                            ctx.strokeStyle = pct > 85 ? "#ff5555" : (root.theme ? root.theme.cpuColor : "#50fa7b");
                            ctx.lineWidth = 2.2;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.ramVal.toString()
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 8
                        font.bold: true
                        color: root.theme ? root.theme.cpuColor : "#50fa7b"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openSectionRequested("ram")
                    }
                }

                // Tacómetro 3: BATERÍA (Ámbar / Verde)
                Item {
                    width: 24
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property bool isCharging: root.batStatus === "Charging"

                    Canvas {
                        id: batCanvas
                        anchors.fill: parent
                        property int pct: root.batVal
                        property bool charging: parent.isCharging
                        onPctChanged: requestPaint()
                        onChargingChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.beginPath();
                            ctx.arc(12, 12, 9, 0, 2 * Math.PI);
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.10)";
                            ctx.lineWidth = 2.2;
                            ctx.stroke();

                            ctx.beginPath();
                            var start = -Math.PI / 2;
                            var end = start + Math.min(1.0, Math.max(0.05, pct / 100)) * (2 * Math.PI);
                            ctx.arc(12, 12, 9, start, end);
                            ctx.strokeStyle = charging ? "#00ffcc" : (pct < 20 ? "#ff5555" : (root.theme ? root.theme.warning : "#ffb86c"));
                            ctx.lineWidth = 2.2;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.isCharging ? "󱐋" : root.batVal.toString()
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: parent.isCharging ? 10 : 8
                        font.bold: true
                        color: parent.isCharging ? "#00ffcc" : (root.batVal < 20 ? "#ff5555" : (root.theme ? root.theme.warning : "#ffb86c"))
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openSectionRequested("battery")
                    }
                }
            }

            // Separador
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.15)
            }

            // ----------------------------------------------------
            // 2. Reloj y Fecha Digital
            // ----------------------------------------------------
            Item {
                width: clockCol.implicitWidth
                height: clockCol.implicitHeight
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    id: clockCol
                    spacing: 1

                    Text {
                        text: root.currentTime
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.theme ? root.theme.text : "#f0f6fc"
                    }

                    Text {
                        text: root.currentDate
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 8
                        font.bold: true
                        color: root.theme ? root.theme.textDim : "#8b949e"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openSectionRequested("notif")
                }
            }

            // Separador sutil
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 12
                color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.12)
            }

            // ----------------------------------------------------
            // 3. Iconos Rápidos de Red y Sonido (Nerd Font)
            // ----------------------------------------------------
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // WiFi
                Item {
                    width: 16
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: root.wifiSsid !== "Disconnected" ? "󰤨" : "󰤮"
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 11
                        color: root.wifiSsid !== "Disconnected" ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#6e7681")
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openSectionRequested("wifi")
                    }
                }

                // Audio
                Item {
                    width: 16
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: root.volMuted ? "󰕟" : (root.volumeVal > 50 ? "󰕾" : "󰖀")
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 11
                        color: root.volMuted ? "#ff5555" : (root.theme ? root.theme.text : "#f0f6fc")
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.launchCommand("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
                            root.openSectionRequested("volume");
                        }
                        onWheel: (wheel) => {
                            var step = wheel.angleDelta.y > 0 ? "5%+" : "5%-";
                            root.launchCommand("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + step);
                        }
                    }
                }
            }
        }
    }
}
