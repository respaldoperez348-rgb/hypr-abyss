import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland

/**
 * NotchIsland.qml
 * Tercera Barra: Dynamic Island Notch estilo "Pocket" (Arch + Hyprland).
 * - Adherida al bisel superior de la pantalla con bordes inferiores curvados.
 * - En reposo: Notch minimalista y compacto (Reloj, workspaces/cava, batería, volumen).
 * - Al expandirse ("drop down"): Despliega paneles interactivos hacia abajo:
 *   1. [Media]: Reproductor musical vivo con carátula, scrubber, marquee y controles.
 *   2. [Control]: Sliders rápidos de volumen y brillo, más toggles de sistema.
 *   3. [Pocket]: Compañero pixel cyber con XP dinámico y nivel de actividad.
 * - Sincronizado dinámicamente con Pywal y el tema global.
 */
Item {
    id: root

    implicitWidth: notchContainer.width
    implicitHeight: notchContainer.height
    width: implicitWidth
    height: implicitHeight

    property var theme
    signal toggleControlCenterRequested()
    signal toggleMusicPlayerRequested()
    signal openWallpaperSelectorRequested()
    signal openPowerMenuRequested()
    signal toggleExpandRequested()
    signal collapseRequested()
    signal expandRequested()
    signal setTabRequested(string tab)

    // Control de Expansión
    property bool expanded: false
    property string activeTab: "media" // "media", "control", "pocket"

    readonly property Item notchCard: notchContainer
    readonly property int expandedHeight: notchContainer.height + 4

    // OSD temporal cuando sube/baja volumen
    property bool osdActive: false
    property string osdText: ""
    property int osdValue: 50

    Timer {
        id: osdTimer
        interval: 1800
        repeat: false
        onTriggered: root.osdActive = false
    }

    function showOsd(mode, val, muted) {
        root.osdValue = val;
        root.osdText = (mode === "volume") ? (muted ? "Silenciado" : "Vol " + val + "%") : ("Brillo " + val + "%");
        root.osdActive = true;
        osdTimer.restart();
    }

    // ==========================================
    // 1. Integración MPRIS y Media
    // ==========================================
    property MprisPlayer activePlayer: null

    function updateActivePlayer() {
        var players = Mpris.players.values;
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) {
                root.activePlayer = players[i];
                return;
            }
        }
        if (players.length > 0) {
            root.activePlayer = players[0];
        } else {
            root.activePlayer = null;
        }
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.updateActivePlayer(); }
    }

    Component.onCompleted: {
        root.updateActivePlayer();
        statsTimer.start();
        statsProc.running = true;
    }

    readonly property bool isPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : false
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "Sin reproducción") : "Sin reproducción"
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "Pocket Audio") : "Pocket Island"
    readonly property string trackArtUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property real trackLength: activePlayer ? (activePlayer.trackLength || 0) : 0
    readonly property real trackPosition: activePlayer ? (activePlayer.trackPosition || 0) : 0

    // ==========================================
    // 2. Telemetría Rápida (Stats)
    // ==========================================
    property int cpuVal: 0
    property int ramVal: 0
    property int batVal: 100
    property string batStatus: "Discharging"
    property int volVal: 50
    property bool volMuted: false
    property int brightnessVal: 70
    property int gitCommits: 24

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
                    if (data.vol !== undefined) root.volVal = data.vol;
                    if (data.vol_muted !== undefined) root.volMuted = data.vol_muted;
                } catch (e) {}
            }
        }
    }

    Timer {
        id: statsTimer
        interval: 2000
        repeat: true
        onTriggered: {
            if (!statsProc.running) statsProc.running = true;
        }
    }

    // Proceso auxiliar para volumen / brillo / reproductor
    Process {
        id: cmdProc
        command: []
        running: false
    }

    function runCmd(cmdStr) {
        cmdProc.command = ["bash", "-c", cmdStr];
        cmdProc.running = true;
    }

    function setVolume(pct) {
        root.volVal = Math.max(0, Math.min(100, pct));
        runCmd("pamixer --set-volume " + root.volVal);
    }

    function setBrightness(pct) {
        root.brightnessVal = Math.max(5, Math.min(100, pct));
        runCmd("brightnessctl s " + root.brightnessVal + "%");
    }

    // ==========================================
    // Contenedor Visual del Notch Flotante Superior
    // ==========================================
    Rectangle {
        id: notchContainer
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        // Dimensiones animadas con dinámica fluida tipo iOS / Pocket
        width: root.expanded ? 520 : (root.osdActive ? 420 : 380)
        height: root.expanded ? 240 : 38

        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        // Geometría Notch: Pegado al marco superior, esquinas inferiores curvadas
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.expanded ? 24 : 18
        bottomRightRadius: root.expanded ? 24 : 18

        // Fondo frosted oscuro cyberpunk / pywal
        color: root.theme ? root.theme.backgroundSolid : "#0d1117"
        opacity: 0.94

        border.width: 1.2
        border.color: root.theme ? root.theme.borderHover : "#00ffcc"

        clip: true

        // Línea sutil de resplandor neón inferior
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1.5
            color: root.theme ? root.theme.accent : "#00ffcc"
            opacity: root.expanded ? 0.85 : 0.35
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }

        // ==========================================
        // CABECERA SUPERIOR DEL NOTCH (Siempre visible)
        // ==========================================
        Item {
            id: notchHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 38

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleExpandRequested()
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0) root.setVolume(root.volVal + 3);
                    else if (wheel.angleDelta.y < 0) root.setVolume(root.volVal - 3);
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                // 1. Izquierda: Indicador de Música / OSD / Workspaces
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 7

                    // Punto neón pulsante
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.isPlaying ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.accentAlt : "#bd93f9")

                        SequentialAnimation on opacity {
                            running: root.isPlaying
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.4; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 1.0; to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Mini ecualizador de 3 barras si hay música sonando
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        visible: root.isPlaying

                        Repeater {
                            model: [10, 14, 8]
                            Rectangle {
                                width: 2.2
                                height: modelData
                                radius: 1
                                color: root.theme ? root.theme.accent : "#00ffcc"
                                anchors.bottom: parent.bottom

                                SequentialAnimation on height {
                                    running: root.isPlaying
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 4; to: modelData; duration: 250 + (index * 80); easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: modelData; to: 4; duration: 250 + (index * 80); easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                    }

                    // Texto de estado compacto
                    Text {
                        text: root.osdActive ? root.osdText : (root.isPlaying ? root.trackTitle : "Pocket Notch")
                        elide: Text.ElideRight
                        width: Math.min(130, implicitWidth)
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.theme ? root.theme.text : "#f0f6fc"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item { Layout.fillWidth: true }

                // 2. Centro: Reloj Minimalista
                Text {
                    text: Qt.formatDateTime(new Date(), "hh:mm")
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    font.bold: true
                    color: root.theme ? root.theme.text : "#f0f6fc"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // 3. Derecha: Batería, Nivel y Chevron de Expansión
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8

                    // Batería
                    Text {
                        text: root.batVal + "%"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        color: root.batVal <= 20 ? (root.theme ? root.theme.danger : "#ff5555") : (root.theme ? root.theme.textDim : "#8b949e")
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Chevron indicador de Drop-Down
                    Text {
                        text: root.expanded ? "▲" : "▼"
                        font.pixelSize: 9
                        color: root.theme ? root.theme.accent : "#00ffcc"
                        anchors.verticalCenter: parent.verticalCenter

                        scale: headerHover.containsMouse ? 1.25 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }
                    }
                }
            }

            MouseArea {
                id: headerHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }

        // ==========================================
        // CUERPO DESPLEGABLE (DROP-DOWN PANELS)
        // ==========================================
        Item {
            id: expandedBody
            anchors.top: notchHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: notchContainer.height > 60
            opacity: Math.max(0, (notchContainer.height - 60) / 180.0)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 4
                spacing: 10

                // 1. Selector de Pestañas (Media | Control | Pocket)
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    height: 26
                    width: tabRow.implicitWidth + 8
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.08)

                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 4

                        // Tab Media
                        Rectangle {
                            height: 20
                            width: 68
                            radius: 10
                            color: root.activeTab === "media" ? (root.theme ? root.theme.accent : "#00ffcc") : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "♫ Media"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.activeTab === "media" ? "#0d1117" : (root.theme ? root.theme.textDim : "#8b949e")
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setTabRequested("media")
                            }
                        }

                        // Tab Control
                        Rectangle {
                            height: 20
                            width: 76
                            radius: 10
                            color: root.activeTab === "control" ? (root.theme ? root.theme.accent : "#00ffcc") : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "⚡ Control"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.activeTab === "control" ? "#0d1117" : (root.theme ? root.theme.textDim : "#8b949e")
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setTabRequested("control")
                            }
                        }

                        // Tab Pocket Companion
                        Rectangle {
                            height: 20
                            width: 76
                            radius: 10
                            color: root.activeTab === "pocket" ? (root.theme ? root.theme.accentAlt : "#bd93f9") : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "◈ Pocket"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.activeTab === "pocket" ? "#0d1117" : (root.theme ? root.theme.textDim : "#8b949e")
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setTabRequested("pocket")
                            }
                        }
                    }
                }

                // ==========================================
                // PANEL 1: MEDIA PLAYER (Pocket Audio)
                // ==========================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.activeTab === "media"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 14

                        // Carátula de Álbum Viva
                        Rectangle {
                            width: 90
                            height: 90
                            radius: 14
                            color: "#090d13"
                            border.width: 1.5
                            border.color: root.isPlaying ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(255, 255, 255, 0.12)
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: root.trackArtUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: root.trackArtUrl.length > 0
                            }

                            // Fallback icono musical si no hay carátula
                            Text {
                                anchors.centerIn: parent
                                text: "♫"
                                font.pixelSize: 32
                                color: root.theme ? root.theme.accent : "#00ffcc"
                                visible: root.trackArtUrl.length === 0
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleMusicPlayerRequested()
                            }
                        }

                        // Información & Controles
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: root.trackTitle
                                font.family: "JetBrains Mono"
                                font.pixelSize: 13
                                font.bold: true
                                color: root.theme ? root.theme.text : "#f0f6fc"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.trackArtist
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                color: root.theme ? root.theme.textDim : "#8b949e"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Barra de progreso (Scrubber)
                            Rectangle {
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: Qt.rgba(255, 255, 255, 0.10)

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: (root.trackLength > 0) ? (parent.width * (root.trackPosition / root.trackLength)) : 0
                                    radius: 2
                                    color: root.theme ? root.theme.accent : "#00ffcc"
                                }
                            }

                            // Botones de Reproducción
                            Row {
                                spacing: 14
                                Layout.alignment: Qt.AlignHCenter

                                // Prev
                                Rectangle {
                                    width: 30; height: 30; radius: 15
                                    color: prevHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                                    Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 12; color: "#ffffff" }
                                    MouseArea {
                                        id: prevHover; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer) root.activePlayer.previous();
                                    }
                                }

                                // Play / Pause
                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: root.theme ? root.theme.accent : "#00ffcc"
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isPlaying ? "⏸" : "▶"
                                        font.pixelSize: 14
                                        color: "#0d1117"
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer) root.activePlayer.playPause();
                                    }
                                }

                                // Next
                                Rectangle {
                                    width: 30; height: 30; radius: 15
                                    color: nextHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                                    Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 12; color: "#ffffff" }
                                    MouseArea {
                                        id: nextHover; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer) root.activePlayer.next();
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // PANEL 2: QUICK CONTROLS (Sliders & Toggles)
                // ==========================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.activeTab === "control"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        // Slider de Volumen
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text { text: "VOL"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true; color: root.theme ? root.theme.accent : "#00ffcc" }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 16
                                radius: 8
                                color: Qt.rgba(255, 255, 255, 0.08)

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * (root.volVal / 100.0)
                                    radius: 8
                                    color: root.theme ? root.theme.accent : "#00ffcc"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => root.setVolume(Math.round((mouse.x / width) * 100))
                                }
                            }
                            Text { text: root.volVal + "%"; font.family: "JetBrains Mono"; font.pixelSize: 10; color: "#ffffff"; Layout.preferredWidth: 32 }
                        }

                        // Slider de Brillo
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text { text: "BRI"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true; color: root.theme ? root.theme.accentAlt : "#bd93f9" }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 16
                                radius: 8
                                color: Qt.rgba(255, 255, 255, 0.08)

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * (root.brightnessVal / 100.0)
                                    radius: 8
                                    color: root.theme ? root.theme.accentAlt : "#bd93f9"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => root.setBrightness(Math.round((mouse.x / width) * 100))
                                }
                            }
                            Text { text: root.brightnessVal + "%"; font.family: "JetBrains Mono"; font.pixelSize: 10; color: "#ffffff"; Layout.preferredWidth: 32 }
                        }

                        // Botones de Acceso Rápido
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            // Wallpaper Selector
                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 8
                                color: wpBtnHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.10)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: "🖼"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Fondos"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true; color: "#fff"; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: wpBtnHover; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.collapseRequested();
                                        root.openWallpaperSelectorRequested();
                                    }
                                }
                            }

                            // Control Center
                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 8
                                color: ccBtnHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.10)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: "⚙"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Ajustes"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true; color: "#fff"; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: ccBtnHover; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.collapseRequested();
                                        root.toggleControlCenterRequested();
                                    }
                                }
                            }

                            // Power Menu
                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 8
                                color: pwrBtnHover.containsMouse ? (root.theme ? root.theme.danger : "#ff5555") : Qt.rgba(255, 255, 255, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.10)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: "⏻"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Energía"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true; color: "#fff"; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: pwrBtnHover; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.collapseRequested();
                                        root.openPowerMenuRequested();
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // PANEL 3: POCKET COMPANION (Pokémon / XP Evolution)
                // ==========================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.activeTab === "pocket"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 14

                        // Avatar Pixel Cyber-Companion
                        Rectangle {
                            width: 88
                            height: 88
                            radius: 16
                            color: "#0a0d14"
                            border.width: 1.5
                            border.color: root.theme ? root.theme.accentAlt : "#bd93f9"

                            // Sprite pixel art cyber auténtico (8x8 vector grid)
                            Item {
                                id: petSprite
                                width: 52
                                height: 52
                                anchors.centerIn: parent

                                Grid {
                                    anchors.centerIn: parent
                                    columns: 8
                                    rows: 8
                                    spacing: 1.5

                                    Repeater {
                                        model: [
                                            0,1,0,0,0,0,1,0,
                                            0,1,1,0,0,1,1,0,
                                            1,1,1,1,1,1,1,1,
                                            1,0,1,1,1,1,0,1,
                                            1,1,1,1,1,1,1,1,
                                            0,1,0,1,1,0,1,0,
                                            1,0,1,0,0,1,0,1,
                                            0,1,0,0,0,0,1,0
                                        ]
                                        Rectangle {
                                            width: 4.5
                                            height: 4.5
                                            radius: 1
                                            color: modelData === 1 ? (root.theme ? root.theme.accentAlt : "#bd93f9") : "transparent"
                                        }
                                    }
                                }

                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 1.12; duration: 600; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 1.12; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                                }
                            }

                            // Badge de Nivel
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 4
                                height: 16
                                width: 34
                                radius: 4
                                color: root.theme ? root.theme.accent : "#00ffcc"
                                Text {
                                    anchors.centerIn: parent
                                    text: "LV. 42"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: "#0d1117"
                                }
                            }
                        }

                        // Métricas del Compañero (Evolución por actividad)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Cyber-Gengar"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: root.theme ? root.theme.text : "#f0f6fc"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "XP: 840 / 1000"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 9
                                    color: root.theme ? root.theme.accentAlt : "#bd93f9"
                                }
                            }

                            // Barra de Experiencia (XP)
                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: Qt.rgba(255, 255, 255, 0.08)

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * 0.84
                                    radius: 3
                                    color: root.theme ? root.theme.accentAlt : "#bd93f9"
                                }
                            }

                            Text {
                                text: "Evoluciona con commits de GitHub y horas de uptime en Arch Linux."
                                font.family: "JetBrains Mono"
                                font.pixelSize: 9
                                color: root.theme ? root.theme.textDim : "#8b949e"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            // Botón de interacción
                            Rectangle {
                                height: 24
                                width: pokeText.implicitWidth + 20
                                radius: 6
                                color: pokeHover.containsMouse ? Qt.rgba(0, 255, 204, 0.25) : Qt.rgba(0, 255, 204, 0.12)
                                border.width: 1
                                border.color: root.theme ? root.theme.accent : "#00ffcc"

                                Text {
                                    id: pokeText
                                    anchors.centerIn: parent
                                    text: "⚡ Feed & Train"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.theme ? root.theme.accent : "#00ffcc"
                                }

                                MouseArea {
                                    id: pokeHover
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        petSprite.scale = 1.35;
                                        root.runCmd("notify-send -a 'Pocket Companion' '👾 Cyber-Gengar' '+50 XP ganado por entrenar!' 2>/dev/null || true");
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
