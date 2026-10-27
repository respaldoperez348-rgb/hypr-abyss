import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland

/**
 * NotchIsland.qml
 * Barra Estilo 3: Dynamic Island Flotante estilo "Pocket" (r/unixporn inspired).
 * - Cápsula flotante desacoplada del bisel con esquinas 100% redondeadas en reposo.
 * - Reloj atómico reactivo con SystemClock (cero desfase, centrado perfecto).
 * - Detección universal de música: MPRIS (Spotify/Browser/MPV) + Aura Music (/dev/shm).
 * - Controles multimedia robustos (togglePlaying, next, prev) con fallback a playerctl.
 * - 3 Pestañas limpias y funcionales: [ Media | Control | Atajos ].
 * - Espacios de trabajo (Workspaces) dinámicos cuando no hay música activa.
 * - Sincronizado dinámicamente con Pywal y el tema activo.
 */
Item {
    id: root

    implicitWidth: notchContainer.width
    implicitHeight: notchContainer.height + 8
    width: implicitWidth
    height: implicitHeight

    property var theme
    signal toggleControlCenterRequested()
    signal toggleMusicPlayerRequested()
    signal openWallpaperSelectorRequested()
    signal openPowerMenuRequested()
    signal openAppMenuRequested()
    signal toggleExpandRequested()
    signal collapseRequested()
    signal expandRequested()
    signal setTabRequested(string tab)

    // Control de Expansión (3 pestañas limpias: media, control, shortcuts)
    property bool expanded: false
    property string activeTab: "media"
    property bool showDate: false

    readonly property Item notchCard: notchContainer
    readonly property int expandedHeight: notchContainer.height + 12

    // Reloj del Sistema Quickshell (Precisión a nivel de segundo, siempre al día)
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

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
        if (mode === "volume") {
            root.volVal = val;
            root.volMuted = !!muted;
        } else if (mode === "brightness") {
            root.brightnessVal = val;
        }
        root.osdValue = val;
        root.osdText = (mode === "volume") ? (muted ? "Silenciado" : "Vol " + val + "%") : ("Brillo " + val + "%");
        root.osdActive = true;
        osdTimer.restart();
    }

    // ==========================================
    // 1. Integración Universal MPRIS & Aura Music
    // ==========================================
    property MprisPlayer activePlayer: null

    function updateActivePlayer() {
        var players = Mpris.players ? Mpris.players.values : [];
        if (!players || players.length === 0) {
            root.activePlayer = null;
            return;
        }

        // 1. Prioridad: Reproductor reproduciendo activamente
        for (var i = 0; i < players.length; i++) {
            var p = players[i];
            if (p && (p.isPlaying || p.playbackState === MprisPlaybackState.Playing)) {
                root.activePlayer = p;
                return;
            }
        }

        // 2. Prioridad: Si el actual aún existe y está en pausa con título, conservarlo
        if (root.activePlayer) {
            for (var j = 0; j < players.length; j++) {
                if (players[j] === root.activePlayer && players[j].trackTitle && players[j].trackTitle.length > 0 && players[j].playbackState === MprisPlaybackState.Paused) {
                    return;
                }
            }
        }

        // 3. Prioridad: Primer reproductor que tenga metadatos válidos
        for (var k = 0; k < players.length; k++) {
            if (players[k] && players[k].trackTitle && players[k].trackTitle.length > 0 && players[k].playbackState !== MprisPlaybackState.Stopped) {
                root.activePlayer = players[k];
                return;
            }
        }

        root.activePlayer = players[0];
    }

    // Instantiator reactivo: escucha eventos en TODOS los reproductores del sistema
    Instantiator {
        id: playerWatcher
        model: Mpris.players

        delegate: Item {
            id: playerItem
            required property MprisPlayer modelData

            Connections {
                target: playerItem.modelData
                function onIsPlayingChanged() { root.updateActivePlayer(); }
                function onPlaybackStateChanged() { root.updateActivePlayer(); }
                function onTrackTitleChanged() { root.updateActivePlayer(); }
                function onTrackArtistChanged() { root.updateActivePlayer(); }
                function onTrackArtUrlChanged() { root.updateActivePlayer(); }
                function onPositionChanged() { }
                function onLengthChanged() { }
            }
        }

        onObjectAdded: root.updateActivePlayer()
        onObjectRemoved: root.updateActivePlayer()
    }

    // Timer de sondeo de respaldo para MPRIS
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateActivePlayer()
    }

    // Metadatos en memoria compartida de Aura Music
    property string auraTitle: ""
    property string auraArtist: ""
    property string auraCover: ""

    FileView {
        id: auraMetaFile
        path: "/dev/shm/aura_now_playing.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var raw = auraMetaFile.text();
                if (!raw || raw.trim() === "") return;
                var d = JSON.parse(raw);
                root.auraTitle = d.title || "";
                root.auraArtist = d.artist || "";
                root.auraCover = d.thumbnail || "";
            } catch (e) {}
        }
    }

    readonly property bool isMpvActive: activePlayer !== null && activePlayer.identity !== undefined && activePlayer.identity.indexOf("mpv") !== -1
    readonly property bool isPlaying: activePlayer ? (activePlayer.isPlaying || activePlayer.playbackState === MprisPlaybackState.Playing) : false
    readonly property bool hasMedia: (activePlayer !== null && activePlayer.trackTitle !== undefined && activePlayer.trackTitle.length > 0) || (auraTitle.length > 0)

    readonly property string trackTitle: {
        if (activePlayer && activePlayer.trackTitle && activePlayer.trackTitle.length > 0) return activePlayer.trackTitle;
        if (auraTitle.length > 0) return auraTitle;
        return "Sin reproducción";
    }

    readonly property string trackArtist: {
        if (activePlayer && activePlayer.trackArtist && activePlayer.trackArtist.length > 0) return activePlayer.trackArtist;
        if (auraArtist.length > 0) return auraArtist;
        return "Pocket Island";
    }

    readonly property string trackArtUrl: {
        if (activePlayer && activePlayer.trackArtUrl && activePlayer.trackArtUrl.length > 0) return activePlayer.trackArtUrl;
        if (auraCover.length > 0) return auraCover;
        return "";
    }

    readonly property real trackLength: activePlayer ? (activePlayer.length || 0) : 0
    readonly property real trackPosition: activePlayer ? (activePlayer.position || 0) : 0

    function formatTime(secs) {
        if (!secs || isNaN(secs) || secs < 0) return "0:00";
        var totalSecs = Math.floor(secs);
        var m = Math.floor(totalSecs / 60);
        var s = totalSecs % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function togglePlayback() {
        if (root.activePlayer && root.activePlayer.canControl) {
            root.activePlayer.togglePlaying();
        } else {
            root.runCmd("quickshell ipc call musicplayer playpause 2>/dev/null || playerctl play-pause 2>/dev/null || true");
        }
    }

    function nextTrack() {
        if (root.activePlayer && root.activePlayer.canGoNext) {
            root.activePlayer.next();
        } else {
            root.runCmd("quickshell ipc call musicplayer next 2>/dev/null || playerctl next 2>/dev/null || true");
        }
    }

    function prevTrack() {
        if (root.activePlayer && root.activePlayer.canGoPrevious) {
            root.activePlayer.previous();
        } else {
            root.runCmd("quickshell ipc call musicplayer prev 2>/dev/null || playerctl previous 2>/dev/null || true");
        }
    }

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

    Process {
        id: statsProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/stats.sh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var clean = this.text.trim();
                    if (!clean) return;
                    var data = JSON.parse(clean);
                    if (data.cpu !== undefined) root.cpuVal = data.cpu;
                    if (data.ram !== undefined) root.ramVal = data.ram;
                    if (data.bat !== undefined) root.batVal = data.bat;
                    if (data.bat_status) root.batStatus = data.bat_status;
                    if (data.volume !== undefined) root.volVal = data.volume;
                    else if (data.vol !== undefined) root.volVal = data.vol;
                    if (data.vol_muted !== undefined) root.volMuted = !!data.vol_muted;
                    if (data.brightness !== undefined) root.brightnessVal = data.brightness;
                } catch (e) {}
            }
        }
    }

    Timer {
        id: statsTimer
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!statsProc.running) {
                statsProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/stats.sh"];
                statsProc.running = true;
            }
        }
    }

    Component.onCompleted: {
        root.updateActivePlayer();
        if (!statsProc.running) {
            statsProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/stats.sh"];
            statsProc.running = true;
        }
    }

    // Procesos dedicados para volumen y brillo
    Process {
        id: volProc
        command: []
        running: false
    }

    Process {
        id: briProc
        command: []
        running: false
    }

    Process {
        id: cmdProc
        command: []
        running: false
    }

    function runCmd(cmdStr) {
        cmdProc.running = false;
        cmdProc.command = ["bash", "-c", cmdStr];
        cmdProc.running = true;
    }

    function setVolume(pct) {
        var clamped = Math.max(0, Math.min(100, Math.round(pct)));
        root.volVal = clamped;
        root.volMuted = false;
        volProc.running = false;
        volProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_sliders.sh", "set_volume", clamped.toString()];
        volProc.running = true;
    }

    function setBrightness(pct) {
        var clamped = Math.max(5, Math.min(100, Math.round(pct)));
        root.brightnessVal = clamped;
        briProc.running = false;
        briProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_sliders.sh", "set_brightness", clamped.toString()];
        briProc.running = true;
    }

    // ==========================================
    // Contenedor Visual de la Cápsula Flotante (Dynamic Island)
    // ==========================================
    Rectangle {
        id: notchContainer
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter

        // Dimensiones elásticas fluidas
        width: root.expanded ? 500 : (root.osdActive ? 420 : (root.hasMedia ? 420 : 350))
        height: root.expanded ? 235 : 36
        radius: root.expanded ? 24 : 18

        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

        // Fondo Frosted Glass Profundo OLED
        color: "#f20a0d14"
        border.width: 1.5
        border.color: root.expanded 
                      ? (root.theme ? root.theme.borderHover : "#00f2fe")
                      : (headerHover.containsMouse ? (root.theme ? root.theme.accent : "#00f2fe") : Qt.rgba(255, 255, 255, 0.12))

        clip: true

        // Resplandor exterior suave con tono dinámico
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: parent.radius + 3
            color: "transparent"
            border.width: 1
            border.color: root.expanded ? Qt.rgba(0, 242, 254, 0.25) : Qt.rgba(255, 255, 255, 0.04)
            z: -1
        }

        // Línea sutil de resplandor neón inferior
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1.5
            color: root.theme ? root.theme.accent : "#00f2fe"
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
            height: 36

            MouseArea {
                id: headerHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        root.toggleControlCenterRequested();
                    } else {
                        root.toggleExpandRequested();
                    }
                }
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0) root.setVolume(root.volVal + 3);
                    else if (wheel.angleDelta.y < 0) root.setVolume(root.volVal - 3);
                }
            }

            // ----------------------------------------------------
            // 1. IZQUIERDA: Módulo Musical o Workspaces Dinámicos
            // ----------------------------------------------------
            Item {
                id: leftModule
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: leftRow.implicitWidth

                Row {
                    id: leftRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    // Caso A: Si hay música detectada (reproduciendo o pausada)
                    Row {
                        visible: root.hasMedia
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // Ecualizador de 3 barras (baila si está en play, fijo si está en pausa)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2.2

                            Repeater {
                                model: [11, 15, 9]
                                Rectangle {
                                    width: 2.2
                                    height: root.isPlaying ? modelData : (index === 1 ? 8 : 5)
                                    radius: 1
                                    color: root.theme ? root.theme.accent : "#00f2fe"
                                    anchors.bottom: parent.bottom

                                    SequentialAnimation on height {
                                        running: root.isPlaying
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 3; to: modelData; duration: 220 + (index * 70); easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: modelData; to: 3; duration: 220 + (index * 70); easing.type: Easing.InOutQuad }
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.osdActive ? root.osdText : root.trackTitle
                            elide: Text.ElideRight
                            width: Math.min(105, implicitWidth)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                            font.bold: true
                            color: root.theme ? root.theme.text : "#f0f6fc"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Caso B: Si NO hay música detectada -> Workspaces (1..5)
                    Row {
                        visible: !root.hasMedia
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Repeater {
                            model: [1, 2, 3, 4, 5]

                            delegate: Rectangle {
                                id: wsDot
                                readonly property int wsId: modelData
                                readonly property bool isCurrent: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
                                readonly property bool hasWindows: {
                                    if (!Hyprland.workspaces || !Hyprland.workspaces.values) return false;
                                    var wlist = Hyprland.workspaces.values;
                                    for (var i = 0; i < wlist.length; i++) {
                                        if (wlist[i].id === wsId) {
                                            return (wlist[i].windows || 0) > 0;
                                        }
                                    }
                                    return false;
                                }

                                width: isCurrent ? 16 : (hasWindows ? 6.5 : 4)
                                height: 6.5
                                radius: 3.25
                                anchors.verticalCenter: parent.verticalCenter

                                color: isCurrent 
                                       ? (root.theme ? root.theme.accent : "#00f2fe")
                                       : (hasWindows ? (root.theme ? root.theme.accentAlt : "#e056fd") : Qt.rgba(255, 255, 255, 0.25))

                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + wsDot.wsId)
                                }
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // 2. CENTRO: Reloj Atómico de Precisión (Siempre Dead-Center)
            // ----------------------------------------------------
            Item {
                id: centerClockModule
                anchors.centerIn: parent
                height: parent.height
                width: clockRow.implicitWidth

                Row {
                    id: clockRow
                    anchors.centerIn: parent
                    spacing: 3

                    // Micro-punto pulsante
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: root.theme ? root.theme.accent : "#00f2fe"
                        opacity: (sysClock.date.getSeconds() % 2 === 0) ? 1.0 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    // Hora (24h formato estándar HH - NUNCA SE CORTA)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(sysClock.date, "HH")
                        font.family: "JetBrainsMono Nerd Font Bold"
                        font.pixelSize: 12
                        font.bold: true
                        color: root.theme ? root.theme.accent : "#00f2fe"
                    }

                    // Separador parpadeante
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ":"
                        font.family: "JetBrainsMono Nerd Font Bold"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#ffffff"
                        opacity: (sysClock.date.getSeconds() % 2 === 0) ? 1.0 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    // Minutos (mm - Cero retraso o desfase)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(sysClock.date, "mm")
                        font.family: "JetBrainsMono Nerd Font Bold"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#ffffff"
                    }

                    // Fecha expandible al dar clic en el reloj
                    Item {
                        id: dateExpander
                        anchors.verticalCenter: parent.verticalCenter
                        height: 14
                        width: root.showDate ? (dateText.implicitWidth + 8) : 0
                        clip: true
                        visible: width > 0
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Rectangle {
                                width: 1; height: 10
                                color: Qt.rgba(255, 255, 255, 0.20)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: dateText
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDateTime(sysClock.date, "ddd d MMM").toUpperCase()
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.theme ? root.theme.accentAlt : "#e056fd"
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            root.toggleControlCenterRequested();
                        } else {
                            root.showDate = !root.showDate;
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // 3. DERECHA: Telemetría Rápida & Indicador de Expansión
            // ----------------------------------------------------
            Item {
                id: rightModule
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: rightRow.implicitWidth

                Row {
                    id: rightRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Volumen con Icono Nerd
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            text: root.volMuted ? "󰝟" : (root.volVal > 50 ? "󰕾" : (root.volVal > 0 ? "󰖀" : "󰕿"))
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: root.volMuted ? "#ff5555" : (root.theme ? root.theme.accent : "#00f2fe")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.volVal + "%"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                            font.bold: true
                            color: Qt.rgba(255, 255, 255, 0.8)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Separador micro
                    Rectangle {
                        width: 1
                        height: 9
                        color: Qt.rgba(255, 255, 255, 0.15)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Batería con Icono Dinámico
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            text: root.batStatus === "Charging" ? "󰂄" : (root.batVal > 80 ? "󰁹" : (root.batVal > 40 ? "󰁾" : (root.batVal > 20 ? "󰁻" : "󰂃")))
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: root.batVal <= 20 ? "#ff5555" : (root.batStatus === "Charging" ? "#2ed573" : (root.theme ? root.theme.accentAlt : "#e056fd"))
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.batVal + "%"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                            font.bold: true
                            color: root.batVal <= 20 ? "#ff5555" : Qt.rgba(255, 255, 255, 0.8)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Botón Morphing Chevron de Drop-Down
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: headerHover.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.06)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: root.expanded ? "󰅃" : "󰅀"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 9
                            color: root.theme ? root.theme.accent : "#00f2fe"
                        }
                    }
                }
            }
        }

        // ==========================================
        // CUERPO DESPLEGABLE (DROP-DOWN PANELS: 3 PESTAÑAS)
        // ==========================================
        Item {
            id: expandedBody
            anchors.top: notchHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: notchContainer.height > 60
            opacity: Math.max(0, (notchContainer.height - 60) / 175.0)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                anchors.topMargin: 2
                spacing: 8

                // 1. Selector de Pestañas Limpias (Media | Control | Atajos)
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

                        // Tab 1: Media
                        Rectangle {
                            height: 20
                            width: 76
                            radius: 10
                            color: root.activeTab === "media" ? (root.theme ? root.theme.accent : "#00f2fe") : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "♫ Media"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.activeTab === "media" ? "#0a0d14" : (root.theme ? root.theme.textDim : "#8b949e")
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setTabRequested("media")
                            }
                        }

                        // Tab 2: Control
                        Rectangle {
                            height: 20
                            width: 80
                            radius: 10
                            color: root.activeTab === "control" ? (root.theme ? root.theme.accent : "#00f2fe") : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "⚡ Control"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.activeTab === "control" ? "#0a0d14" : (root.theme ? root.theme.textDim : "#8b949e")
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setTabRequested("control")
                            }
                        }

                        // Tab 3: Atajos / Quick Apps
                        Rectangle {
                            height: 20
                            width: 76
                            radius: 10
                            color: root.activeTab === "shortcuts" ? (root.theme ? root.theme.accent : "#00f2fe") : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰀻 Atajos"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.activeTab === "shortcuts" ? "#0a0d14" : (root.theme ? root.theme.textDim : "#8b949e")
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setTabRequested("shortcuts")
                            }
                        }
                    }
                }

                // ==========================================
                // PANEL 1: MEDIA PLAYER (MPRIS + Aura Music Universal)
                // ==========================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.activeTab === "media"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 14

                        // Carátula de Álbum Viva (Clic abre el reproductor completo)
                        Rectangle {
                            width: 90
                            height: 90
                            radius: 14
                            color: "#090d13"
                            border.width: 1.5
                            border.color: root.isPlaying ? (root.theme ? root.theme.accent : "#00f2fe") : Qt.rgba(255, 255, 255, 0.12)
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: root.trackArtUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: root.trackArtUrl.length > 0
                                asynchronous: true
                            }

                            // Fallback icono musical si no hay carátula
                            Text {
                                anchors.centerIn: parent
                                text: "♫"
                                font.pixelSize: 32
                                color: root.theme ? root.theme.accent : "#00f2fe"
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
                                font.pixelSize: 12
                                font.bold: true
                                color: root.theme ? root.theme.text : "#f0f6fc"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.trackArtist
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                color: root.theme ? root.theme.textDim : "#8b949e"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Barra de progreso (Scrubber) interactiva y reactiva en tiempo real
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Rectangle {
                                    id: scrubberTrack
                                    Layout.fillWidth: true
                                    height: 5
                                    radius: 2.5
                                    color: Qt.rgba(255, 255, 255, 0.12)

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: (root.trackLength > 0) ? Math.min(parent.width, Math.max(0, parent.width * (root.trackPosition / root.trackLength))) : 0
                                        radius: 2.5
                                        color: root.theme ? root.theme.accent : "#00f2fe"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            if (root.activePlayer && root.activePlayer.canSeek && root.trackLength > 0) {
                                                var ratio = Math.max(0, Math.min(1, mouse.x / width));
                                                root.activePlayer.position = ratio * root.trackLength;
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: root.formatTime(root.trackPosition)
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 8
                                        color: root.theme ? root.theme.textDim : "#8b949e"
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.formatTime(root.trackLength)
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 8
                                        color: root.theme ? root.theme.textDim : "#8b949e"
                                    }
                                }
                            }

                            // Botones de Reproducción
                            Row {
                                spacing: 14
                                Layout.alignment: Qt.AlignHCenter

                                // Prev
                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: prevHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                                    Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 12; color: "#ffffff" }
                                    MouseArea {
                                        id: prevHover; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.prevTrack()
                                    }
                                }

                                // Play / Pause
                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: root.theme ? root.theme.accent : "#00f2fe"
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isPlaying ? "⏸" : "▶"
                                        font.pixelSize: 14
                                        color: "#0a0d14"
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.togglePlayback()
                                    }
                                }

                                // Next
                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: nextHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                                    Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 12; color: "#ffffff" }
                                    MouseArea {
                                        id: nextHover; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.nextTrack()
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // PANEL 2: QUICK CONTROLS (Sliders de Volumen y Brillo)
                // ==========================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.activeTab === "control"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        // Slider de Volumen
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "VOL"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.theme ? root.theme.accent : "#00f2fe"
                                Layout.preferredWidth: 30
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 18
                                radius: 9
                                color: Qt.rgba(255, 255, 255, 0.08)

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * (root.volVal / 100.0)
                                    radius: 9
                                    color: root.theme ? root.theme.accent : "#00f2fe"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    function applyPos(mx) {
                                        var p = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                        root.setVolume(p);
                                    }
                                    onClicked: (mouse) => applyPos(mouse.x)
                                    onPositionChanged: (mouse) => {
                                        if (pressed) applyPos(mouse.x);
                                    }
                                }
                            }
                            Text {
                                text: root.volVal + "%"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                color: "#ffffff"
                                Layout.preferredWidth: 34
                            }
                        }

                        // Slider de Brillo
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "BRI"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.theme ? root.theme.accentAlt : "#e056fd"
                                Layout.preferredWidth: 30
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 18
                                radius: 9
                                color: Qt.rgba(255, 255, 255, 0.08)

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * (root.brightnessVal / 100.0)
                                    radius: 9
                                    color: root.theme ? root.theme.accentAlt : "#e056fd"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    function applyPos(mx) {
                                        var p = Math.max(5, Math.min(100, Math.round((mx / width) * 100)));
                                        root.setBrightness(p);
                                    }
                                    onClicked: (mouse) => applyPos(mouse.x)
                                    onPositionChanged: (mouse) => {
                                        if (pressed) applyPos(mouse.x);
                                    }
                                }
                            }
                            Text {
                                text: root.brightnessVal + "%"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                color: "#ffffff"
                                Layout.preferredWidth: 34
                            }
                        }

                        // Métricas Rápidas
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                radius: 8
                                color: Qt.rgba(255, 255, 255, 0.05)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.08)
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: "󰍛"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: root.theme ? root.theme.accent : "#00f2fe" }
                                    Text { text: "CPU " + root.cpuVal + "%"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true; color: "#fff" }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                radius: 8
                                color: Qt.rgba(255, 255, 255, 0.05)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.08)
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: "󰘚"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: root.theme ? root.theme.accentAlt : "#e056fd" }
                                    Text { text: "RAM " + root.ramVal + "%"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true; color: "#fff" }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // PANEL 3: ATAJOS DE ACCESO RÁPIDO (Apps, Wallpapers, Settings, Power)
                // ==========================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.activeTab === "shortcuts"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        // 1. App Drawer (Rofi Pocket Grid)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: appsCardHover.containsMouse ? Qt.rgba(0, 242, 254, 0.20) : Qt.rgba(255, 255, 255, 0.05)
                            border.width: 1.2
                            border.color: appsCardHover.containsMouse ? (root.theme ? root.theme.accent : "#00f2fe") : Qt.rgba(255, 255, 255, 0.10)

                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: "󰣇"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 24
                                    color: root.theme ? root.theme.accent : "#00f2fe"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: "Apps"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#ffffff"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            MouseArea {
                                id: appsCardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.collapseRequested();
                                    root.openAppMenuRequested();
                                }
                            }
                        }

                        // 2. Wallpaper Selector
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: wpCardHover.containsMouse ? Qt.rgba(224, 86, 253, 0.20) : Qt.rgba(255, 255, 255, 0.05)
                            border.width: 1.2
                            border.color: wpCardHover.containsMouse ? (root.theme ? root.theme.accentAlt : "#e056fd") : Qt.rgba(255, 255, 255, 0.10)

                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: "󰸉"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 24
                                    color: root.theme ? root.theme.accentAlt : "#e056fd"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: "Fondos"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#ffffff"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            MouseArea {
                                id: wpCardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.collapseRequested();
                                    root.openWallpaperSelectorRequested();
                                }
                            }
                        }

                        // 3. Control Center
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: ccCardHover.containsMouse ? Qt.rgba(0, 242, 254, 0.20) : Qt.rgba(255, 255, 255, 0.05)
                            border.width: 1.2
                            border.color: ccCardHover.containsMouse ? (root.theme ? root.theme.accent : "#00f2fe") : Qt.rgba(255, 255, 255, 0.10)

                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: "󰒓"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 24
                                    color: root.theme ? root.theme.accent : "#00f2fe"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: "Ajustes"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#ffffff"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            MouseArea {
                                id: ccCardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.collapseRequested();
                                    root.toggleControlCenterRequested();
                                }
                            }
                        }

                        // 4. Power Menu
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: pwrCardHover.containsMouse ? Qt.rgba(255, 71, 87, 0.25) : Qt.rgba(255, 255, 255, 0.05)
                            border.width: 1.2
                            border.color: pwrCardHover.containsMouse ? "#ff4757" : Qt.rgba(255, 255, 255, 0.10)

                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: "󰐥"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 24
                                    color: "#ff4757"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: "Energía"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#ffffff"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            MouseArea {
                                id: pwrCardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.collapseRequested();
                                    root.openPowerMenuRequested();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
