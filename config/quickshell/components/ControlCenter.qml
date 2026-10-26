import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * ControlCenter.qml
 * Panel Lateral de Control y Notificaciones (Estilo Frosted Glass Cyberpunk)
 * - Tamaño optimizado y compacto (300px).
 * - Notificaciones con botón Clear All, descarte individual y Dino Pixel Art en estado vacío.
 * - Keep Awake con toggle fluido y proceso desacoplado.
 * - Screen Recorder y Screenshot que ocultan el panel antes de capturar el área.
 * - Cajones interactivos independientes para WiFi y Bluetooth.
 * - Auto-cierre inteligente al retirar el ratón (con temporizador de seguridad).
 */
Item {
    id: root

    property var theme
    property bool isOpen: false
    property bool isMouseInside: false
    property string barStyle: "deck"
    signal closeRequested()
    signal setBarStyleRequested(string style)

    implicitWidth: 300
    implicitHeight: 720

    // Estados de Notificaciones y Calendario
    property var notifList: []
    property bool isDnd: false
    property string upperTab: "notif" // "notif" o "calendar"
    property var calDate: new Date()
    property int calYear: calDate.getFullYear()
    property int calMonth: calDate.getMonth()
    property int calSelectedDay: calDate.getDate()
    readonly property var monthNames: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]

    function nextMonth() {
        if (calMonth === 11) { calMonth = 0; calYear++; } else { calMonth++; }
    }
    function prevMonth() {
        if (calMonth === 0) { calMonth = 11; calYear--; } else { calMonth--; }
    }
    function jumpToday() {
        var now = new Date();
        calYear = now.getFullYear();
        calMonth = now.getMonth();
        calSelectedDay = now.getDate();
    }

    // Estados de Keep Awake
    property bool keepAwakeActive: false
    property string keepAwakeSince: ""

    // Estados de Grabación
    property bool isRecording: false
    property string recordMode: "fullscreen" // "fullscreen" o "region"
    property string currentRecordingFile: ""

    // Estados de Toggles y Drawers
    property bool wifiPowered: true
    property string wifiCurrentSsid: ""
    property var wifiNetworks: []
    property bool wifiDrawerOpen: false
    property string wifiSelectedSsid: ""
    property string wifiPasswordInput: ""
    property bool wifiConnecting: false

    property bool btPowered: false
    property var btDevices: []
    property bool btDrawerOpen: false
    property bool btScanning: false
    property string btConnectingMac: ""

    property bool micMuted: false

    // Estados de Sliders de Volumen y Brillo
    property int volumePercent: 65
    property bool volumeMuted: false
    property int brightnessPercent: 80

    // Estados de Telemetría (System Vitals)
    property int cpuPercent: 0
    property int cpuTemp: 0
    property int ramPercent: 0
    property string ramUsed: "0G"
    property string ramTotal: "0G"
    property int batPercent: 100
    property string batStatus: "Full"
    property string batDetail: ""
    readonly property bool batCharging: batStatus === "Charging"
    property string highlightSection: ""

    Timer {
        id: highlightTimer
        interval: 3200
        repeat: false
        onTriggered: root.highlightSection = ""
    }

    function focusSection(sec) {
        root.highlightSection = sec;
        if (sec === "calendar") {
            root.upperTab = "calendar";
        } else if (sec === "notif") {
            root.upperTab = "notif";
        } else if (sec === "wifi") {
            root.wifiDrawerOpen = true;
            root.btDrawerOpen = false;
        } else if (sec === "bluetooth") {
            root.btDrawerOpen = true;
            root.wifiDrawerOpen = false;
        }
        highlightTimer.restart();
    }

    property alias card: panelCard
    readonly property bool isAnimating: slideAnim.running

    // Temporizador de auto-cierre al salir el ratón
    Timer {
        id: autoCloseTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (!root.isMouseInside && !root.wifiDrawerOpen && !root.btDrawerOpen && !root.isRecording && !passInput.activeFocus) {
                root.closeRequested();
            }
        }
    }

    // ==========================================
    // Procesos en Segundo Plano
    // ==========================================

    // 1. Notificaciones
    Process {
        id: notifProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/notif_manager.py", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.notifList = data.notifications || [];
                    root.isDnd = !!data.dnd;
                } catch (e) {}
            }
        }
    }

    Process {
        id: notifActionProc
        command: []
        running: false
        onExited: notifProc.running = true
    }

    Process {
        id: dndToggleProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/notif_manager.py", "toggle_dnd"]
        running: false
        onExited: notifProc.running = true
    }

    function clearAllNotifications() {
        root.notifList = [];
        notifActionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/notif_manager.py", "clear"];
        notifActionProc.running = true;
    }

    function dismissNotification(nid) {
        var updated = [];
        for (var i = 0; i < root.notifList.length; i++) {
            if (root.notifList[i].id !== nid) updated.push(root.notifList[i]);
        }
        root.notifList = updated;
        notifActionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/notif_manager.py", "dismiss", nid.toString()];
        notifActionProc.running = true;
    }

    function dismissNotif(nid) {
        root.dismissNotification(nid);
    }

    function toggleDnd() {
        root.isDnd = !root.isDnd;
        dndToggleProc.running = true;
    }

    // 2. Keep Awake
    Process {
        id: keepAwakeProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/keep_awake.sh", "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.keepAwakeActive = !!data.active;
                    root.keepAwakeSince = data.since || "";
                } catch (e) {}
            }
        }
    }

    Process {
        id: keepAwakeToggleProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/keep_awake.sh", "toggle"]
        running: false
        onExited: keepAwakeProc.running = true
    }

    // 3. Screen Recorder
    Process {
        id: recordStatusProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/screen_record.sh", "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.isRecording = !!data.recording;
                    root.currentRecordingFile = data.file || "";
                } catch (e) {}
            }
        }
    }

    Process {
        id: recordActionProc
        command: []
        running: false
        onExited: recordStatusProc.running = true
    }

    function toggleRecording() {
        var cmd = root.isRecording ? "stop" : (root.recordMode === "region" ? "start_region" : "start_full");
        recordActionProc.running = false;
        recordActionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/screen_record.sh", cmd];
        recordActionProc.running = true;
    }

    // 4. Screenshot
    Process {
        id: screenshotProc
        command: []
        running: false
    }

    function takeScreenshot(mode) {
        screenshotProc.running = false;
        screenshotProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/screenshot.sh", mode || "region"];
        screenshotProc.running = true;
    }

    // 5. Wallpaper Shuffle
    Process {
        id: wallChangeProc
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/wallchange.sh"]
        running: false
    }

    function shuffleWallpaper() {
        if (!wallChangeProc.running) {
            wallChangeProc.running = true;
        }
    }

    // 6. WiFi
    Process {
        id: wifiScanProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/wifi_scan.py"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(this.text) || [];
                    root.wifiNetworks = list;
                    for (var i = 0; i < list.length; i++) {
                        if (list[i].in_use) {
                            root.wifiCurrentSsid = list[i].ssid;
                            root.wifiPowered = true;
                            break;
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: wifiConnectProc
        command: []
        running: false
        onExited: {
            root.wifiConnecting = false;
            wifiScanProc.running = true;
        }
    }

    function connectWifi(ssid, pass) {
        root.wifiConnecting = true;
        wifiConnectProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/wifi_connect.sh", ssid, pass || ""];
        wifiConnectProc.running = true;
    }

    // 7. Bluetooth
    Process {
        id: btScanProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/bt_scan.py"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.btPowered = !!data.powered;
                    root.btDevices = data.devices || [];
                    root.btScanning = false;
                } catch (e) {
                    root.btScanning = false;
                }
            }
        }
    }

    Process {
        id: btPowerProc
        command: []
        running: false
        onExited: {
            btScanProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/bt_scan.py"];
            btScanProc.running = true;
        }
    }

    function toggleBtPower(state) {
        var arg = state !== undefined ? (state ? "on" : "off") : "toggle";
        btPowerProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/bt_toggle.sh", arg];
        btPowerProc.running = true;
    }

    Process {
        id: btConnectProc
        command: []
        running: false
        onExited: {
            root.btConnectingMac = "";
            btScanProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/bt_scan.py"];
            btScanProc.running = true;
        }
    }

    function scanBluetooth() {
        root.btScanning = true;
        btScanProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/bt_scan.py", "scan"];
        btScanProc.running = true;
    }

    function connectBt(mac) {
        root.btConnectingMac = mac;
        btConnectProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/bt_connect.sh", mac];
        btConnectProc.running = true;
    }

    // 8. Micrófono
    Process {
        id: micProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/mic_toggle.sh", "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.micMuted = !!data.muted;
                } catch (e) {}
            }
        }
    }

    Process {
        id: micToggleProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/mic_toggle.sh", "toggle"]
        running: false
        onExited: micProc.running = true
    }

    // 9. Sliders de Volumen y Brillo
    Process {
        id: slidersProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_sliders.sh", "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    if (data.volume !== undefined && !volSliderMouse.pressed) root.volumePercent = data.volume;
                    if (data.muted !== undefined) root.volumeMuted = !!data.muted;
                    if (data.brightness !== undefined && !briSliderMouse.pressed) root.brightnessPercent = data.brightness;
                } catch (e) {}
            }
        }
    }

    Process {
        id: slidersActionProc
        command: []
        running: false
    }

    function setSystemVolume(pct) {
        var clamped = Math.max(0, Math.min(100, Math.round(pct)));
        root.volumePercent = clamped;
        root.volumeMuted = false;
        slidersActionProc.running = false;
        slidersActionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_sliders.sh", "set_volume", clamped.toString()];
        slidersActionProc.running = true;
    }

    function toggleSystemMute() {
        root.volumeMuted = !root.volumeMuted;
        slidersActionProc.running = false;
        slidersActionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_sliders.sh", "toggle_mute"];
        slidersActionProc.running = true;
    }

    function setSystemBrightness(pct) {
        var clamped = Math.max(5, Math.min(100, Math.round(pct)));
        root.brightnessPercent = clamped;
        slidersActionProc.running = false;
        slidersActionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_sliders.sh", "set_brightness", clamped.toString()];
        slidersActionProc.running = true;
    }

    Process {
        id: cmdProc
        command: []
        running: false
    }

    function launchCommand(cmd) {
        cmdProc.command = ["bash", "-c", cmd];
        cmdProc.running = true;
    }

    Process {
        id: sysStatsProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/stats.sh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    if (data.cpu !== undefined) root.cpuPercent = data.cpu;
                    if (data.cpu_temp !== undefined) root.cpuTemp = data.cpu_temp;
                    if (data.ram !== undefined) root.ramPercent = data.ram;
                    if (data.ram_used) root.ramUsed = data.ram_used;
                    if (data.ram_total) root.ramTotal = data.ram_total;
                    if (data.bat !== undefined) root.batPercent = data.bat;
                    if (data.bat_status) root.batStatus = data.bat_status;
                    if (data.bat_detail) root.batDetail = data.bat_detail;
                } catch (e) {}
            }
        }
    }

    function refreshAll() {
        if (!notifProc.running) notifProc.running = true;
        if (!keepAwakeProc.running) keepAwakeProc.running = true;
        if (!recordStatusProc.running) recordStatusProc.running = true;
        if (!wifiScanProc.running) wifiScanProc.running = true;
        if (!btScanProc.running) btScanProc.running = true;
        if (!micProc.running) micProc.running = true;
        if (!slidersProc.running) slidersProc.running = true;
        if (!sysStatsProc.running) sysStatsProc.running = true;
    }

    Timer {
        id: updateTimer
        interval: 3500
        running: root.isOpen
        repeat: true
        onTriggered: root.refreshAll()
    }

    onIsOpenChanged: {
        if (isOpen) {
            refreshAll();
        } else {
            root.wifiDrawerOpen = false;
            root.btDrawerOpen = false;
        }
    }

    Component.onCompleted: {
        refreshAll();
    }

    // ==========================================
    // Contenedor Principal Frosted Glass
    // ==========================================
    Rectangle {
        id: panelCard
        width: parent.width - 8
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 4

        radius: 18
        color: root.theme ? root.theme.backgroundSolid : "#0d1117"
        opacity: 0.94

        border.width: 1
        border.color: root.theme ? root.theme.borderHover : "#00ffcc"

        // Desplazamiento animado GPU fluido
        transform: Translate {
            x: root.isOpen ? 0 : 340
            Behavior on x {
                NumberAnimation {
                    id: slideAnim
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Resplandor neón superior sutil
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            height: 1.5
            color: root.theme ? root.theme.accent : "#00ffcc"
            opacity: 0.7
        }

        // Detección de presencia del ratón para el auto-cierre inteligente
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                root.isMouseInside = true;
                autoCloseTimer.stop();
            }
            onPositionChanged: {
                root.isMouseInside = true;
                autoCloseTimer.stop();
            }
            onExited: {
                if (mouseX < 0 || mouseX >= width || mouseY < 0 || mouseY >= height) {
                    root.isMouseInside = false;
                    autoCloseTimer.restart();
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // ==========================================
            // 1. ÁREA DE NOTIFICACIONES (Superior)
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.25)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    // Header con Pestañas: [ 󰂚 Notifs ] [ 󰃭 Calendario ]
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Tab Notificaciones
                        Rectangle {
                            height: 20
                            width: notifTabRow.implicitWidth + 12
                            radius: 10
                            color: root.upperTab === "notif" ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.22) : Qt.rgba(0, 1, 0.8, 0.22)) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: root.upperTab === "notif" ? (root.theme ? root.theme.accent : "#00ffcc") : "transparent"

                            RowLayout {
                                id: notifTabRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "󰂚"
                                    font.family: root.theme ? root.theme.fontMono : "monospace"
                                    font.pixelSize: 9
                                    color: root.upperTab === "notif" ? (root.theme ? root.theme.accent : "#00ffcc") : "#8b949e"
                                }
                                Text {
                                    text: "Notifs"
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 8
                                    font.bold: root.upperTab === "notif"
                                    color: root.upperTab === "notif" ? "#ffffff" : "#8b949e"
                                }
                                Rectangle {
                                    visible: root.notifList.length > 0
                                    height: 12
                                    width: notifBadgeCount.implicitWidth + 6
                                    radius: 6
                                    color: root.theme ? root.theme.accent : "#00ffcc"
                                    Text {
                                        id: notifBadgeCount
                                        anchors.centerIn: parent
                                        text: root.notifList.length
                                        font.pixelSize: 7
                                        font.bold: true
                                        color: "#0d1117"
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.upperTab = "notif"
                            }
                        }

                        // Tab Calendario
                        Rectangle {
                            height: 20
                            width: calTabRow.implicitWidth + 12
                            radius: 10
                            color: root.upperTab === "calendar" ? (root.theme ? Qt.rgba(root.theme.accentAlt.r, root.theme.accentAlt.g, root.theme.accentAlt.b, 0.24) : Qt.rgba(0.74, 0.58, 0.98, 0.24)) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: root.upperTab === "calendar" ? (root.theme ? root.theme.accentAlt : "#bd93f9") : "transparent"

                            RowLayout {
                                id: calTabRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "󰃭"
                                    font.family: root.theme ? root.theme.fontMono : "monospace"
                                    font.pixelSize: 9
                                    color: root.upperTab === "calendar" ? (root.theme ? root.theme.accentAlt : "#bd93f9") : "#8b949e"
                                }
                                Text {
                                    text: "Calendario"
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 8
                                    font.bold: root.upperTab === "calendar"
                                    color: root.upperTab === "calendar" ? "#ffffff" : "#8b949e"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.upperTab = "calendar"
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: root.upperTab === "notif"
                            height: 18
                            width: dndBadgeRow.implicitWidth + 10
                            radius: 9
                            color: root.isDnd ? (root.theme ? root.theme.warning : "#ffb86c") : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: root.isDnd ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                            Layout.alignment: Qt.AlignVCenter

                            RowLayout {
                                id: dndBadgeRow
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    text: root.isDnd ? "🔇" : "🔔"
                                    font.pixelSize: 8
                                }
                                Text {
                                    text: root.isDnd ? "Silenciado" : "Silenciar"
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: root.isDnd ? "#0d1117" : (dndBadgeMouse.containsMouse ? "#ffffff" : (root.theme ? root.theme.textDim : "#8b949e"))
                                }
                            }

                            MouseArea {
                                id: dndBadgeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleDnd()
                            }
                        }

                        // Botón Limpiar Todo
                        Text {
                            visible: root.upperTab === "notif" && root.notifList.length > 0
                            text: "Clear All"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            color: clearMouse.containsMouse ? (root.theme ? root.theme.danger : "#ff5555") : (root.theme ? root.theme.textDim : "#6e7681")
                            Layout.alignment: Qt.AlignVCenter

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearAllNotifications()
                            }
                        }

                        // Botón Cerrar (X Minimalista)
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: closeMouse.containsMouse ? (root.theme ? root.theme.danger : "#ff5555") : Qt.rgba(1, 1, 1, 0.08)
                            Layout.alignment: Qt.AlignVCenter

                            Canvas {
                                id: closeCanvas
                                anchors.centerIn: parent
                                width: 9
                                height: 9
                                rotation: closeMouse.containsMouse ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: 180 } }

                                property color col: closeMouse.containsMouse ? "#ffffff" : (root.theme ? root.theme.textDim : "#6e7681")
                                onColChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = col;
                                    ctx.lineWidth = 1.3;
                                    ctx.lineCap = "round";
                                    ctx.beginPath();
                                    ctx.moveTo(1.2, 1.2); ctx.lineTo(7.8, 7.8);
                                    ctx.moveTo(7.8, 1.2); ctx.lineTo(1.2, 7.8);
                                    ctx.stroke();
                                }
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeRequested()
                            }
                        }
                    }

                    // Contenido: Lista o Empty State con Dino
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Estado Vacío (Dino Pixel Art + Cactus)
                        Column {
                            visible: root.upperTab === "notif" && root.notifList.length === 0
                            anchors.centerIn: parent
                            spacing: 8

                            Canvas {
                                width: 120
                                height: 42
                                anchors.horizontalCenter: parent.horizontalCenter
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.fillStyle = "#6e7681";
                                    ctx.strokeStyle = "#6e7681";
                                    ctx.lineWidth = 1.5;

                                    // Suelo
                                    ctx.beginPath();
                                    ctx.moveTo(10, 38); ctx.lineTo(110, 38);
                                    ctx.stroke();

                                    // Nube
                                    ctx.beginPath();
                                    ctx.arc(55, 10, 3.5, 0, Math.PI * 2);
                                    ctx.arc(61, 8, 5, 0, Math.PI * 2);
                                    ctx.arc(68, 10, 3.5, 0, Math.PI * 2);
                                    ctx.stroke();

                                    // Dino
                                    ctx.fillRect(20, 16, 12, 9);
                                    ctx.fillRect(29, 13, 7, 7);
                                    ctx.fillRect(18, 23, 11, 10);
                                    ctx.fillRect(13, 22, 5, 5);
                                    ctx.fillRect(20, 33, 3, 4);
                                    ctx.fillRect(25, 33, 3, 4);

                                    // Cactus
                                    ctx.fillRect(85, 20, 5, 18);
                                    ctx.fillRect(80, 24, 5, 3);
                                    ctx.fillRect(80, 21, 3, 5);
                                    ctx.fillRect(90, 27, 5, 3);
                                    ctx.fillRect(92, 24, 3, 5);
                                }
                            }

                            Text {
                                text: "No Notifications"
                                font.family: root.theme ? root.theme.fontFamily : "monospace"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.theme ? root.theme.textDim : "#6e7681"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        // Lista de Notificaciones
                        ListView {
                            visible: root.upperTab === "notif" && root.notifList.length > 0
                            anchors.fill: parent
                            clip: true
                            spacing: 5
                            model: root.notifList

                            delegate: Rectangle {
                                width: parent ? parent.width : 260
                                height: 48
                                radius: 8
                                color: notifCardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: notifCardMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.08)

                                MouseArea {
                                    id: notifCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.dismissNotification(modelData.id)
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: modelData.appname
                                            font.pixelSize: 8
                                            font.bold: true
                                            color: root.theme ? root.theme.accent : "#00ffcc"
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: modelData.summary
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: "#ffffff"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        // Botón X para borrar notificación individual
                                        Text {
                                            text: "✕"
                                            font.pixelSize: 8
                                            color: notifDelMouse.containsMouse ? "#ff5555" : "#6e7681"
                                            MouseArea {
                                                id: notifDelMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.dismissNotification(modelData.id)
                                            }
                                        }
                                    }

                                    Text {
                                        text: modelData.body
                                        font.pixelSize: 8
                                        color: root.theme ? root.theme.textDim : "#8b949e"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }

                        // ==========================================
                        // Vista Mini Calendario Interactivo
                        // ==========================================
                        ColumnLayout {
                            visible: root.upperTab === "calendar"
                            anchors.fill: parent
                            spacing: 4

                            // Navegación Mes / Año + Botón Hoy
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: root.monthNames[root.calMonth] + " " + root.calYear
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#ffffff"
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    height: 18
                                    width: hoyLabel.implicitWidth + 8
                                    radius: 5
                                    color: hoyMouse.containsMouse ? (root.theme ? Qt.rgba(root.theme.accentAlt.r, root.theme.accentAlt.g, root.theme.accentAlt.b, 0.35) : Qt.rgba(0.74, 0.58, 0.98, 0.35)) : Qt.rgba(1, 1, 1, 0.06)
                                    border.width: 1
                                    border.color: root.theme ? root.theme.accentAlt : "#bd93f9"
                                    Text {
                                        id: hoyLabel
                                        anchors.centerIn: parent
                                        text: "Hoy"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: root.theme ? root.theme.accentAlt : "#bd93f9"
                                    }
                                    MouseArea {
                                        id: hoyMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.jumpToday()
                                    }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 5
                                    color: prevMonthM.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "‹"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                    MouseArea {
                                        id: prevMonthM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.prevMonth()
                                    }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 5
                                    color: nextMonthM.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "›"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                    MouseArea {
                                        id: nextMonthM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.nextMonth()
                                    }
                                }
                            }

                            // Días de la semana
                            Row {
                                Layout.fillWidth: true
                                spacing: 0
                                readonly property real colW: width / 7.0
                                Repeater {
                                    model: ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]
                                    delegate: Item {
                                        width: parent.colW
                                        height: 16
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pixelSize: 8
                                            font.bold: true
                                            color: (index >= 5) ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#8b949e")
                                        }
                                    }
                                }
                            }

                            // Grid de 42 celdas de días
                            Grid {
                                id: daysGrid
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 7
                                rows: 6
                                spacing: 1

                                readonly property real cellW: (width - 6 * spacing) / 7.0
                                readonly property real cellH: (height - 5 * spacing) / 6.0
                                readonly property int firstDayOfWeek: (new Date(root.calYear, root.calMonth, 1).getDay() + 6) % 7
                                readonly property int daysInMonth: new Date(root.calYear, root.calMonth + 1, 0).getDate()
                                readonly property int daysInPrevMonth: new Date(root.calYear, root.calMonth, 0).getDate()

                                Repeater {
                                    model: 42
                                    delegate: Rectangle {
                                        id: dayCell
                                        width: daysGrid.cellW
                                        height: daysGrid.cellH
                                        radius: 5

                                        readonly property int idx: modelData
                                        readonly property bool isPrevMonth: idx < daysGrid.firstDayOfWeek
                                        readonly property bool isNextMonth: idx >= daysGrid.firstDayOfWeek + daysGrid.daysInMonth
                                        readonly property bool isCurrentMonth: !isPrevMonth && !isNextMonth
                                        readonly property int dayNumber: {
                                            if (isPrevMonth) return daysGrid.daysInPrevMonth - daysGrid.firstDayOfWeek + 1 + idx;
                                            if (isCurrentMonth) return idx - daysGrid.firstDayOfWeek + 1;
                                            return idx - (daysGrid.firstDayOfWeek + daysGrid.daysInMonth) + 1;
                                        }
                                        readonly property bool isToday: {
                                            var now = new Date();
                                            return isCurrentMonth && (dayNumber === now.getDate()) && (root.calMonth === now.getMonth()) && (root.calYear === now.getFullYear());
                                        }
                                        readonly property bool isSelected: isCurrentMonth && (dayNumber === root.calSelectedDay)

                                        color: isToday
                                               ? (root.theme ? root.theme.accent : "#00ffcc")
                                               : (isSelected
                                                  ? (root.theme ? Qt.rgba(root.theme.accentAlt.r, root.theme.accentAlt.g, root.theme.accentAlt.b, 0.28) : Qt.rgba(0.74, 0.58, 0.98, 0.28))
                                                  : (dayMouse.containsMouse && isCurrentMonth ? Qt.rgba(1, 1, 1, 0.08) : "transparent"))

                                        border.width: isSelected && !isToday ? 1 : 0
                                        border.color: root.theme ? root.theme.accentAlt : "#bd93f9"

                                        Text {
                                            anchors.centerIn: parent
                                            text: dayCell.dayNumber
                                            font.pixelSize: dayCell.isToday ? 9 : 8
                                            font.bold: dayCell.isToday || dayCell.isSelected
                                            color: dayCell.isToday
                                                   ? "#0d1117"
                                                   : (dayCell.isCurrentMonth
                                                      ? (dayMouse.containsMouse ? "#ffffff" : "#e6edf3")
                                                      : "#383e47")
                                        }

                                        MouseArea {
                                            id: dayMouse
                                            anchors.fill: parent
                                            hoverEnabled: dayCell.isCurrentMonth
                                            cursorShape: dayCell.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                if (dayCell.isCurrentMonth) {
                                                    root.calSelectedDay = dayCell.dayNumber;
                                                } else if (dayCell.isPrevMonth) {
                                                    root.prevMonth();
                                                    root.calSelectedDay = dayCell.dayNumber;
                                                } else {
                                                    root.nextMonth();
                                                    root.calSelectedDay = dayCell.dayNumber;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 1.3. SYSTEM VITALS HUD (CPU, RAM, BATERÍA Y TERMOMÉTRICA)
            // ==========================================
            Rectangle {
                id: vitalsCard
                Layout.fillWidth: true
                height: 76
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.32)
                border.width: 1
                border.color: (root.highlightSection === "vitals" || root.highlightSection === "cpu" || root.highlightSection === "ram" || root.highlightSection === "battery")
                              ? (root.theme ? root.theme.accent : "#00ffcc")
                              : Qt.rgba(1, 1, 1, 0.06)

                Behavior on border.color { ColorAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 5

                    // Cabecera: Título y acceso directo a Htop
                    RowLayout {
                        Layout.fillWidth: true

                        Row {
                            spacing: 5
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: "󰘚"
                                font.family: root.theme ? root.theme.fontMono : "monospace"
                                font.pixelSize: 11
                                color: root.theme ? root.theme.accent : "#00ffcc"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "System Vitals"
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 10
                                font.bold: true
                                color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Chip interactivo para Htop
                        Rectangle {
                            height: 16
                            width: htopLabel.implicitWidth + 10
                            radius: 8
                            color: htopMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: htopMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.12)
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: htopLabel
                                anchors.centerIn: parent
                                text: " Htop"
                                font.family: root.theme ? root.theme.fontMono : "monospace"
                                font.pixelSize: 8
                                font.bold: true
                                color: htopMouse.containsMouse ? "#0d1117" : (root.theme ? root.theme.textDim : "#8b949e")
                            }

                            MouseArea {
                                id: htopMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.launchCommand("kitty -e htop &")
                            }
                        }
                    }

                    // 3 Métricas: CPU, RAM, BATERÍA
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        // 1. CPU
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 8
                            color: root.highlightSection === "cpu" ? Qt.rgba(0, 1, 0.8, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: root.highlightSection === "cpu" ? 1 : 0
                            border.color: root.theme ? root.theme.cpuColor : "#50fa7b"

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 2

                                Row {
                                    spacing: 3
                                    Text {
                                        text: "󰻠"
                                        font.family: root.theme ? root.theme.fontMono : "monospace"
                                        font.pixelSize: 9
                                        color: root.theme ? root.theme.cpuColor : "#50fa7b"
                                    }
                                    Text {
                                        text: "CPU " + root.cpuPercent + "%"
                                        font.family: root.theme ? root.theme.fontMono : "monospace"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#f0f6fc"
                                    }
                                }

                                Text {
                                    text: root.cpuTemp > 0 ? (root.cpuTemp + "°C") : "Normal"
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 8
                                    color: root.theme ? root.theme.textDim : "#8b949e"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.launchCommand("kitty -e htop &")
                            }
                        }

                        // 2. RAM
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 8
                            color: root.highlightSection === "ram" ? Qt.rgba(0, 1, 0.8, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: root.highlightSection === "ram" ? 1 : 0
                            border.color: root.theme ? root.theme.accent : "#00ffcc"

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 2

                                Row {
                                    spacing: 3
                                    Text {
                                        text: "󰍛"
                                        font.family: root.theme ? root.theme.fontMono : "monospace"
                                        font.pixelSize: 9
                                        color: root.theme ? root.theme.accent : "#00ffcc"
                                    }
                                    Text {
                                        text: "RAM " + root.ramPercent + "%"
                                        font.family: root.theme ? root.theme.fontMono : "monospace"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#f0f6fc"
                                    }
                                }

                                Text {
                                    text: root.ramUsed + " / " + root.ramTotal
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 8
                                    color: root.theme ? root.theme.textDim : "#8b949e"
                                }
                            }
                        }

                        // 3. BATERÍA
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 8
                            color: root.highlightSection === "battery" ? Qt.rgba(1.0, 0.72, 0.42, 0.22) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: root.highlightSection === "battery" ? 1 : 0
                            border.color: root.batCharging ? "#00ffcc" : (root.theme ? root.theme.warning : "#ffb86c")

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 2

                                Row {
                                    spacing: 3
                                    Text {
                                        text: root.batCharging ? "󱐋" : "󰂀"
                                        font.family: root.theme ? root.theme.fontMono : "monospace"
                                        font.pixelSize: 9
                                        color: root.batCharging ? "#00ffcc" : (root.batPercent < 20 ? "#ff5555" : (root.theme ? root.theme.warning : "#ffb86c"))
                                    }
                                    Text {
                                        text: root.batPercent + "%"
                                        font.family: root.theme ? root.theme.fontMono : "monospace"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#f0f6fc"
                                    }
                                }

                                Text {
                                    text: root.batDetail.length > 0 ? root.batDetail : root.batStatus
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                    width: parent.width - 6
                                    color: root.theme ? root.theme.textDim : "#8b949e"
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 1.5. SLIDERS DE VOLUMEN Y BRILLO (Estilo Prototipo Neón)
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                height: 84
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.30)
                border.width: 1
                border.color: root.highlightSection === "volume" ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.06)

                Behavior on border.color { ColorAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    // --- Slider 1: Volumen ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "Volume"
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 9
                                font.bold: true
                                color: "#ffffff"
                            }

                            Text {
                                text: root.volumeMuted ? "(Muted)" : ("(" + root.volumePercent + "%)")
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 9
                                color: root.volumeMuted
                                       ? (root.theme ? root.theme.danger : "#ff5555")
                                       : (root.theme ? root.theme.textDim : "#8b949e")
                            }

                            Item { Layout.fillWidth: true }

                            // Botón rápido Mute / Unmute
                            Text {
                                text: root.volumeMuted ? "Unmute" : "Mute"
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 8
                                font.bold: true
                                color: muteBtnMouse.containsMouse
                                       ? (root.theme ? root.theme.accent : "#00ffcc")
                                       : (root.theme ? root.theme.textDim : "#6e7681")

                                MouseArea {
                                    id: muteBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleSystemMute()
                                }
                            }
                        }

                        Item {
                            id: volTrackContainer
                            Layout.fillWidth: true
                            height: 14

                            Rectangle {
                                id: volTrack
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 5
                                radius: 2.5
                                color: Qt.rgba(1, 1, 1, 0.12)

                                Rectangle {
                                    id: volFill
                                    width: Math.max(0, Math.min(parent.width, parent.width * ((root.volumeMuted ? 0 : root.volumePercent) / 100.0)))
                                    height: parent.height
                                    radius: 2.5
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: root.theme ? root.theme.accent : "#00ffcc" }
                                        GradientStop { position: 1.0; color: root.theme ? root.theme.accentAlt : "#bd93f9" }
                                    }
                                    Behavior on width {
                                        enabled: !volSliderMouse.pressed
                                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                    }
                                }
                            }

                            // Círculo indicador (Thumb)
                            Rectangle {
                                width: volSliderMouse.containsMouse || volSliderMouse.pressed ? 13 : 11
                                height: width
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - width, volFill.width - width / 2))
                                color: root.volumeMuted
                                       ? (root.theme ? root.theme.danger : "#ff5555")
                                       : (root.theme ? root.theme.accentAlt : "#bd93f9")
                                border.width: 1.5
                                border.color: "#ffffff"
                                Behavior on width { NumberAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: volSliderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: (mouse) => {
                                    var pct = (mouse.x / width) * 100.0;
                                    root.setSystemVolume(pct);
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        var pct = (mouse.x / width) * 100.0;
                                        root.setSystemVolume(pct);
                                    }
                                }
                                onWheel: (wheel) => {
                                    var step = wheel.angleDelta.y > 0 ? 5 : -5;
                                    root.setSystemVolume(root.volumePercent + step);
                                }
                            }
                        }
                    }

                    // --- Slider 2: Brillo ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "Brightness"
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 9
                                font.bold: true
                                color: "#ffffff"
                            }

                            Text {
                                text: "(" + root.brightnessPercent + "%)"
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 9
                                color: root.theme ? root.theme.textDim : "#8b949e"
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Item {
                            id: briTrackContainer
                            Layout.fillWidth: true
                            height: 14

                            Rectangle {
                                id: briTrack
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 5
                                radius: 2.5
                                color: Qt.rgba(1, 1, 1, 0.12)

                                Rectangle {
                                    id: briFill
                                    width: Math.max(0, Math.min(parent.width, parent.width * (root.brightnessPercent / 100.0)))
                                    height: parent.height
                                    radius: 2.5
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: root.theme ? root.theme.accent : "#00ffcc" }
                                        GradientStop { position: 1.0; color: root.theme ? root.theme.accentAlt : "#bd93f9" }
                                    }
                                    Behavior on width {
                                        enabled: !briSliderMouse.pressed
                                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                    }
                                }
                            }

                            // Círculo indicador (Thumb)
                            Rectangle {
                                width: briSliderMouse.containsMouse || briSliderMouse.pressed ? 13 : 11
                                height: width
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - width, briFill.width - width / 2))
                                color: root.theme ? root.theme.accentAlt : "#bd93f9"
                                border.width: 1.5
                                border.color: "#ffffff"
                                Behavior on width { NumberAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: briSliderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: (mouse) => {
                                    var pct = (mouse.x / width) * 100.0;
                                    root.setSystemBrightness(pct);
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        var pct = (mouse.x / width) * 100.0;
                                        root.setSystemBrightness(pct);
                                    }
                                }
                                onWheel: (wheel) => {
                                    var step = wheel.angleDelta.y > 0 ? 5 : -5;
                                    root.setSystemBrightness(root.brightnessPercent + step);
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // BAR STYLE SWITCHER (Triple Deck vs Dynamic Island)
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.30)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "󰨞"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: root.theme ? root.theme.accent : "#00ffcc"
                        }

                        Text {
                            text: "Estilo de Barra"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                            color: "#ffffff"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Super+Alt+B"
                            font.family: root.theme ? root.theme.fontFamily : "monospace"
                            font.pixelSize: 8
                            color: root.theme ? root.theme.textDim : "#6e7681"
                        }
                    }

                    // Selector Segmentado de 2 Opciones
                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.05)

                        RowLayout {
                            anchors.fill: parent
                            spacing: 2

                            // Opción 1: Triple Deck
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: root.barStyle === "deck" 
                                       ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.25) : Qt.rgba(0, 1, 0.8, 0.25))
                                       : (optDeckMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                border.width: root.barStyle === "deck" ? 1 : 0
                                border.color: root.theme ? root.theme.accent : "#00ffcc"

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "󰨞"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        color: root.barStyle === "deck" ? (root.theme ? root.theme.accent : "#00ffcc") : "#888888"
                                    }
                                    Text {
                                        text: "Triple Deck"
                                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                        font.pixelSize: 8
                                        font.bold: root.barStyle === "deck"
                                        color: root.barStyle === "deck" ? "#ffffff" : "#888888"
                                    }
                                }

                                MouseArea {
                                    id: optDeckMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setBarStyleRequested("deck")
                                }
                            }

                            // Opción 2: Dynamic Island
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: root.barStyle === "island"
                                       ? (root.theme ? Qt.rgba(root.theme.accentAlt.r, root.theme.accentAlt.g, root.theme.accentAlt.b, 0.25) : Qt.rgba(0.74, 0.58, 0.98, 0.25))
                                       : (optIslandMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                border.width: root.barStyle === "island" ? 1 : 0
                                border.color: root.theme ? root.theme.accentAlt : "#bd93f9"

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text {
                                        text: "󱐋"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        color: root.barStyle === "island" ? (root.theme ? root.theme.accentAlt : "#bd93f9") : "#888888"
                                    }
                                    Text {
                                        text: "Island"
                                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                        font.pixelSize: 8
                                        font.bold: root.barStyle === "island"
                                        color: root.barStyle === "island" ? "#ffffff" : "#888888"
                                    }
                                }

                                MouseArea {
                                    id: optIslandMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setBarStyleRequested("island")
                                }
                            }

                            // Opción 3: Pocket Notch
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: root.barStyle === "notch"
                                       ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.25) : Qt.rgba(0, 1, 0.8, 0.25))
                                       : (optNotchMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                border.width: root.barStyle === "notch" ? 1 : 0
                                border.color: root.theme ? root.theme.accent : "#00ffcc"

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text {
                                        text: "󰍹"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        color: root.barStyle === "notch" ? (root.theme ? root.theme.accent : "#00ffcc") : "#888888"
                                    }
                                    Text {
                                        text: "Pocket"
                                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                        font.pixelSize: 8
                                        font.bold: root.barStyle === "notch"
                                        color: root.barStyle === "notch" ? "#ffffff" : "#888888"
                                    }
                                }

                                MouseArea {
                                    id: optNotchMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setBarStyleRequested("notch")
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 2. KEEP AWAKE CARD (Caffeine)
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.30)
                border.width: 1
                border.color: root.keepAwakeActive ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.06)

                Behavior on border.color { ColorAnimation { duration: 180 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: root.keepAwakeActive ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.08)

                        Canvas {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            property color col: root.keepAwakeActive ? "#0d1117" : (root.theme ? root.theme.accent : "#00ffcc")
                            onColChanged: requestPaint()
                            Component.onCompleted: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.strokeStyle = col;
                                ctx.lineWidth = 1.2;
                                ctx.lineCap = "round";
                                ctx.beginPath();
                                ctx.moveTo(2.5, 4.5); ctx.lineTo(9.5, 4.5);
                                ctx.lineTo(8.5, 11);
                                ctx.arcTo(8.5, 12.5, 7, 12.5, 1);
                                ctx.lineTo(4.5, 12.5);
                                ctx.arcTo(3.5, 12.5, 3.5, 11, 1);
                                ctx.closePath();
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.arc(9.5, 7.5, 2, -Math.PI * 0.4, Math.PI * 0.4);
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.moveTo(4.5, 3); ctx.lineTo(4.5, 1.2);
                                ctx.moveTo(7.5, 3); ctx.lineTo(7.5, 1.2);
                                ctx.stroke();
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Keep Awake"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#ffffff"
                        }

                        Text {
                            text: root.keepAwakeActive ? ("Active since " + root.keepAwakeSince) : "Preventing sleep mode"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 8
                            color: root.keepAwakeActive ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#6e7681")
                        }
                    }

                    // Toggle Switch estilo iOS
                    Rectangle {
                        width: 36
                        height: 18
                        radius: 9
                        color: root.keepAwakeActive ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.15)
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.keepAwakeActive ? 19 : 2

                            Behavior on x {
                                NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.keepAwakeActive = !root.keepAwakeActive;
                                keepAwakeToggleProc.running = true;
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 3. SCREEN RECORDER & SCREENSHOT CARD
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.30)
                border.width: 1
                border.color: root.isRecording ? "#ff5555" : Qt.rgba(1, 1, 1, 0.06)

                Behavior on border.color { ColorAnimation { duration: 180 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    // Icono Grabación
                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: root.isRecording ? "#ff5555" : Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            anchors.centerIn: parent
                            width: root.isRecording ? 8 : 7
                            height: root.isRecording ? 8 : 7
                            radius: root.isRecording ? 2 : 3.5
                            color: root.isRecording ? "#ffffff" : (root.theme ? root.theme.danger : "#ff5555")
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Screen Recorder"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#ffffff"
                        }

                        Text {
                            text: root.isRecording ? "Recording in progress..." : "Recording off"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 8
                            color: root.isRecording ? "#ff5555" : (root.theme ? root.theme.textDim : "#6e7681")
                        }
                    }

                    // Selector Fullscreen / Area
                    Rectangle {
                        height: 20
                        width: modeRow.implicitWidth + 10
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Row {
                            id: modeRow
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                text: root.recordMode === "fullscreen" ? "Full" : "Area"
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 8
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.recordMode = root.recordMode === "fullscreen" ? "region" : "fullscreen";
                            }
                        }
                    }

                    // Botón REC / STOP
                    Rectangle {
                        height: 20
                        width: 38
                        radius: 10
                        color: root.isRecording ? "#ff5555" : (root.theme ? root.theme.accent : "#00ffcc")

                        Text {
                            anchors.centerIn: parent
                            text: root.isRecording ? "STOP" : "REC"
                            font.family: root.theme ? root.theme.fontFamily : "monospace"
                            font.pixelSize: 8
                            font.bold: true
                            color: "#0d1117"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleRecording()
                        }
                    }
                }
            }

            // ==========================================
            // DRAWER DESPLEGABLE: Selector de WiFi
            // ==========================================
            Rectangle {
                visible: root.wifiDrawerOpen
                Layout.fillWidth: true
                Layout.preferredHeight: root.wifiDrawerOpen ? 140 : 0
                implicitHeight: root.wifiDrawerOpen ? 140 : 0
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.45)
                border.width: 1
                border.color: root.theme ? root.theme.accent : "#00ffcc"
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    Text {
                        text: "Redes WiFi Disponibles"
                        font.pixelSize: 8
                        font.bold: true
                        color: root.theme ? root.theme.accent : "#00ffcc"
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 3
                        model: root.wifiNetworks

                        delegate: Rectangle {
                            width: parent ? parent.width : 260
                            height: 22
                            radius: 4
                            color: (root.wifiSelectedSsid === modelData.ssid) 
                                   ? Qt.rgba(1, 1, 1, 0.15) 
                                   : (wifiItemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4

                                Text {
                                    text: (modelData.in_use ? "● " : "") + modelData.ssid
                                    font.pixelSize: 8
                                    font.bold: modelData.in_use
                                    color: modelData.in_use ? (root.theme ? root.theme.accent : "#00ffcc") : "#ffffff"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.signal + "%"
                                    font.pixelSize: 7
                                    color: root.theme ? root.theme.textDim : "#6e7681"
                                }
                            }

                            MouseArea {
                                id: wifiItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.wifiSelectedSsid = modelData.ssid;
                                    passInput.forceActiveFocus();
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            height: 20
                            radius: 4
                            color: Qt.rgba(0, 0, 0, 0.5)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)

                            TextInput {
                                id: passInput
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: 8
                                color: "#ffffff"
                                echoMode: TextInput.Password
                                text: root.wifiPasswordInput
                                onTextChanged: root.wifiPasswordInput = text

                                Text {
                                    text: root.wifiSelectedSsid ? ("Clave para " + root.wifiSelectedSsid) : "Selecciona una red..."
                                    font.pixelSize: 8
                                    color: Qt.rgba(1, 1, 1, 0.3)
                                    visible: parent.text.length === 0
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            width: 50
                            height: 20
                            radius: 4
                            color: root.theme ? root.theme.accent : "#00ffcc"

                            Text {
                                anchors.centerIn: parent
                                text: root.wifiConnecting ? "..." : "Conectar"
                                font.pixelSize: 8
                                font.bold: true
                                color: "#0d1117"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.wifiSelectedSsid) {
                                        root.connectWifi(root.wifiSelectedSsid, root.wifiPasswordInput);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // DRAWER DESPLEGABLE: Selector de Bluetooth
            // ==========================================
            Rectangle {
                visible: root.btDrawerOpen
                Layout.fillWidth: true
                Layout.preferredHeight: root.btDrawerOpen ? 140 : 0
                implicitHeight: root.btDrawerOpen ? 140 : 0
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.45)
                border.width: 1
                border.color: root.theme ? root.theme.accentAlt : "#bd93f9"
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "Dispositivos Bluetooth"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.theme ? root.theme.accentAlt : "#bd93f9"
                        }

                        // Badge / Conmutador de encendido
                        Rectangle {
                            width: 28
                            height: 14
                            radius: 7
                            color: root.btPowered ? (root.theme ? root.theme.accentAlt : "#bd93f9") : Qt.rgba(1, 1, 1, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: root.btPowered ? "ON" : "OFF"
                                font.pixelSize: 7
                                font.bold: true
                                color: root.btPowered ? "#0d1117" : (root.theme ? root.theme.textDim : "#6e7681")
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleBtPower(!root.btPowered)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Botón Escanear
                        Text {
                            visible: root.btPowered
                            text: root.btScanning ? "Buscando..." : "Buscar"
                            font.pixelSize: 8
                            color: root.theme ? root.theme.accent : "#00ffcc"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.scanBluetooth()
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 3
                        model: root.btDevices
                        visible: root.btDevices.length > 0

                        delegate: Rectangle {
                            id: devItem
                            width: parent ? parent.width : 260
                            height: 22
                            radius: 4
                            color: modelData.connected 
                                   ? Qt.rgba(1, 1, 1, 0.12) 
                                   : (devMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 4

                                // Indicador de estado (conectado / vinculado / disponible)
                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: modelData.connected 
                                           ? (root.theme ? root.theme.accentAlt : "#bd93f9") 
                                           : (modelData.paired ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.25))
                                }

                                Text {
                                    text: modelData.name
                                    font.pixelSize: 8
                                    font.bold: modelData.connected
                                    color: modelData.connected 
                                           ? (root.theme ? root.theme.accentAlt : "#bd93f9") 
                                           : (modelData.paired ? (root.theme ? root.theme.text : "#f0f6fc") : (root.theme ? root.theme.textDim : "#8b949e"))
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.mac === root.btConnectingMac 
                                          ? "Conectando..." 
                                          : (modelData.connected ? "Desconectar" : (modelData.paired ? "Conectar" : "Vincular"))
                                    font.pixelSize: 7
                                    font.bold: modelData.connected || modelData.mac === root.btConnectingMac
                                    color: modelData.mac === root.btConnectingMac 
                                           ? (root.theme ? root.theme.warning : "#ffb86c") 
                                           : (modelData.connected 
                                              ? (root.theme ? root.theme.danger : "#ff5555") 
                                              : (root.theme ? root.theme.accent : "#00ffcc"))
                                }
                            }

                            MouseArea {
                                id: devMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectBt(modelData.mac)
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.btDevices.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: !root.btPowered 
                                      ? "Bluetooth desactivado" 
                                      : (root.btScanning ? "Buscando dispositivos..." : "Sin dispositivos encontrados")
                                font.pixelSize: 8
                                color: root.theme ? root.theme.textDim : "#6e7681"
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Rectangle {
                                visible: !root.btPowered
                                width: 70
                                height: 18
                                radius: 4
                                color: root.theme ? root.theme.accentAlt : "#bd93f9"
                                Layout.alignment: Qt.AlignHCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "Activar"
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: "#0d1117"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleBtPower(true)
                                }
                            }

                            Rectangle {
                                visible: root.btPowered && !root.btScanning && root.btDevices.length === 0
                                width: 80
                                height: 18
                                radius: 4
                                color: Qt.rgba(1, 1, 1, 0.08)
                                Layout.alignment: Qt.AlignHCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "Buscar"
                                    font.pixelSize: 8
                                    color: root.theme ? root.theme.accent : "#00ffcc"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.scanBluetooth()
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 4. QUICK TOGGLES (Inferior con 6 Botones + Etiquetas)
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                height: 66
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.30)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Text {
                        text: "Quick Toggles"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 8
                        font.bold: true
                        color: root.theme ? root.theme.textDim : "#6e7681"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // 1. WiFi Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            radius: 13
                            color: root.wifiPowered ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.08)

                            Canvas {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                property color col: root.wifiPowered ? "#0d1117" : (root.theme ? root.theme.textDim : "#6e7681")
                                onColChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = col;
                                    ctx.fillStyle = col;
                                    ctx.lineWidth = 1.3;
                                    ctx.lineCap = "round";
                                    ctx.beginPath();
                                    ctx.arc(6.5, 9.5, 5.5, -Math.PI * 0.75, -Math.PI * 0.25);
                                    ctx.stroke();
                                    ctx.beginPath();
                                    ctx.arc(6.5, 9.5, 3.5, -Math.PI * 0.75, -Math.PI * 0.25);
                                    ctx.stroke();
                                    ctx.beginPath();
                                    ctx.arc(6.5, 10, 1.1, 0, Math.PI * 2);
                                    ctx.fill();
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.wifiDrawerOpen = !root.wifiDrawerOpen;
                                    root.btDrawerOpen = false;
                                }
                            }
                        }

                        // 2. Bluetooth Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            radius: 13
                            color: root.btPowered ? (root.theme ? root.theme.accentAlt : "#bd93f9") : Qt.rgba(1, 1, 1, 0.08)

                            Canvas {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                property color col: root.btPowered ? "#0d1117" : (root.theme ? root.theme.textDim : "#6e7681")
                                onColChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = col;
                                    ctx.lineWidth = 1.3;
                                    ctx.lineCap = "round";
                                    ctx.lineJoin = "round";
                                    ctx.beginPath();
                                    ctx.moveTo(6.5, 1.5);
                                    ctx.lineTo(6.5, 11.5);
                                    ctx.lineTo(9.5, 8.5);
                                    ctx.lineTo(3.5, 4);
                                    ctx.moveTo(3.5, 8.5);
                                    ctx.lineTo(9.5, 4);
                                    ctx.lineTo(6.5, 1.5);
                                    ctx.stroke();
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        root.toggleBtPower(!root.btPowered);
                                    } else {
                                        if (!root.btPowered) {
                                            root.toggleBtPower(true);
                                            root.btDrawerOpen = true;
                                            root.wifiDrawerOpen = false;
                                            root.scanBluetooth();
                                        } else {
                                            root.btDrawerOpen = !root.btDrawerOpen;
                                            root.wifiDrawerOpen = false;
                                            if (root.btDrawerOpen) {
                                                root.scanBluetooth();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 3. Micrófono Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            radius: 13
                            color: root.micMuted ? (root.theme ? root.theme.danger : "#ff5555") : Qt.rgba(1, 1, 1, 0.08)

                            Canvas {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                property color col: root.micMuted ? "#ffffff" : (root.theme ? root.theme.text : "#f0f6fc")
                                onColChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = col;
                                    ctx.fillStyle = col;
                                    ctx.lineWidth = 1.2;
                                    ctx.lineCap = "round";
                                    ctx.strokeRect(4.8, 1.8, 3.4, 5.8);
                                    ctx.beginPath();
                                    ctx.arc(6.5, 5.5, 3.4, 0, Math.PI);
                                    ctx.stroke();
                                    ctx.beginPath();
                                    ctx.moveTo(6.5, 9.0); ctx.lineTo(6.5, 11.5);
                                    ctx.moveTo(4.5, 11.5); ctx.lineTo(8.5, 11.5);
                                    ctx.stroke();
                                    if (root.micMuted) {
                                        ctx.beginPath();
                                        ctx.lineWidth = 1.4;
                                        ctx.moveTo(2, 2); ctx.lineTo(11, 11);
                                        ctx.stroke();
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: micToggleProc.running = true
                            }
                        }

                        // 4. Do Not Disturb (DND)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            radius: 13
                            color: root.isDnd ? (root.theme ? root.theme.warning : "#ffb86c") : Qt.rgba(1, 1, 1, 0.08)

                            Canvas {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                property color col: root.isDnd ? "#0d1117" : (root.theme ? root.theme.text : "#f0f6fc")
                                onColChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = col;
                                    ctx.fillStyle = col;
                                    ctx.lineWidth = 1.2;
                                    ctx.lineCap = "round";
                                    ctx.lineJoin = "round";
                                    ctx.beginPath();
                                    ctx.arc(6.5, 2, 0.7, 0, Math.PI * 2);
                                    ctx.stroke();
                                    ctx.beginPath();
                                    ctx.moveTo(4, 9); ctx.lineTo(9, 9);
                                    ctx.lineTo(8.5, 6);
                                    ctx.arcTo(8.5, 3, 6.5, 3, 2);
                                    ctx.arcTo(4.5, 3, 4.5, 6, 2);
                                    ctx.lineTo(4, 9);
                                    ctx.stroke();
                                    ctx.beginPath();
                                    ctx.arc(6.5, 10, 0.9, 0, Math.PI * 2);
                                    ctx.fill();
                                    if (root.isDnd) {
                                        ctx.beginPath();
                                        ctx.lineWidth = 1.4;
                                        ctx.moveTo(2, 2); ctx.lineTo(11, 11);
                                        ctx.stroke();
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleDnd()
                            }
                        }

                        // 5. Captura de Pantalla
                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            radius: 13
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Canvas {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                property color col: root.theme ? root.theme.textDim : "#6e7681"
                                onColChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = col;
                                    ctx.lineWidth = 1.2;
                                    ctx.lineCap = "round";
                                    ctx.lineJoin = "round";
                                    ctx.beginPath();
                                    ctx.moveTo(4.5, 3.5); ctx.lineTo(5.5, 2); ctx.lineTo(7.5, 2); ctx.lineTo(8.5, 3.5);
                                    ctx.stroke();
                                    ctx.strokeRect(2, 3.5, 9, 7.5);
                                    ctx.beginPath();
                                    ctx.arc(6.5, 7.2, 2, 0, Math.PI * 2);
                                    ctx.stroke();
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        root.takeScreenshot("fullscreen");
                                    } else {
                                        root.takeScreenshot(root.recordMode === "fullscreen" ? "fullscreen" : "region");
                                    }
                                }
                            }
                        }

                        // 6. Wallpaper Shuffle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            radius: 13
                            color: wallChangeProc.running ? (root.theme ? root.theme.accent : "#00ffcc") : (diceMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08))

                            Canvas {
                                id: diceCanvas
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                property color col: wallChangeProc.running ? "#0d1117" : (root.theme ? root.theme.textDim : "#6e7681")
                                onColChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                RotationAnimator on rotation {
                                    running: wallChangeProc.running
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 600
                                }

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = col;
                                    ctx.fillStyle = col;
                                    ctx.lineWidth = 1.2;
                                    ctx.strokeRect(2, 2, 9, 9);
                                    ctx.beginPath();
                                    ctx.arc(4.5, 4.5, 0.8, 0, Math.PI * 2);
                                    ctx.arc(6.5, 6.5, 0.8, 0, Math.PI * 2);
                                    ctx.arc(8.5, 8.5, 0.8, 0, Math.PI * 2);
                                    ctx.fill();
                                }
                            }

                            MouseArea {
                                id: diceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.shuffleWallpaper()
                            }
                        }
                    }

                    // Etiquetas bajo los 6 botones (como en el prototipo)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: ["WiFi", "BT", "Mic", "DND", "Shot", "Wall"]
                            delegate: Text {
                                Layout.fillWidth: true
                                text: modelData
                                horizontalAlignment: Text.AlignHCenter
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 7
                                color: root.theme ? root.theme.textDim : "#8b949e"
                            }
                        }
                    }
                }
            }
        }
    }
}
