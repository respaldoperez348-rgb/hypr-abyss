import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

/**
 * MediaPod.qml - Pod Central del Hyper-Utility Glass Deck
 * Estética Aerodinámica Cyberpunk con carátula viva, ecualizador neón y controles de cristal.
 * Interacciones:
 * - Scroll Wheel sobre la cápsula: Sube/Baja el volumen del sistema instantáneamente.
 * - Clic en carátula o título: Abre/Cierra Aura Music flotante.
 * - Controles Play/Pause, Prev, Next táctiles.
 */
Item {
    id: root

    property var theme
    readonly property Item podCard: card
    signal toggleMusicPlayerRequested()

    implicitHeight: card.height
    implicitWidth: card.width

    // ==========================================
    // 1. Integración Reactiva con MPRIS
    // ==========================================
    property MprisPlayer activePlayer: null

    function updateActivePlayer() {
        var players = Mpris.players ? Mpris.players.values : [];
        if (!players || players.length === 0) {
            root.activePlayer = null;
            return;
        }

        // 1. Prioridad: Quien esté sonando
        for (var i = 0; i < players.length; i++) {
            var p = players[i];
            if (p && (p.isPlaying || p.playbackState === MprisPlaybackState.Playing)) {
                root.activePlayer = p;
                return;
            }
        }

        // 2. Si el actual aún tiene título, mantenerlo
        if (root.activePlayer && root.activePlayer.trackTitle && root.activePlayer.trackTitle.length > 0) {
            return;
        }

        // 3. Fallback
        for (var k = 0; k < players.length; k++) {
            if (players[k] && players[k].trackTitle && players[k].trackTitle.length > 0) {
                root.activePlayer = players[k];
                return;
            }
        }
        root.activePlayer = players[0];
    }

    Instantiator {
        model: Mpris.players
        delegate: Item {
            required property MprisPlayer modelData
            Connections {
                target: modelData
                function onPlaybackStateChanged() { root.updateActivePlayer(); }
                function onTrackTitleChanged() { root.updateActivePlayer(); }
                function onIsPlayingChanged() { root.updateActivePlayer(); }
            }
        }
        onObjectAdded: root.updateActivePlayer()
        onObjectRemoved: root.updateActivePlayer()
    }

    Component.onCompleted: root.updateActivePlayer()

    readonly property bool isPlaying: activePlayer !== null && (activePlayer.isPlaying || activePlayer.playbackState === MprisPlaybackState.Playing)
    readonly property string trackTitle: activePlayer && activePlayer.trackTitle ? activePlayer.trackTitle : "Aura Music"
    readonly property string trackArtist: activePlayer && activePlayer.trackArtist ? activePlayer.trackArtist : "Ready to play"
    readonly property string trackCover: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""

    Process {
        id: mediaNextProc
        command: ["quickshell", "ipc", "call", "musicplayer", "next"]
        running: false
    }

    Process {
        id: mediaPrevProc
        command: ["quickshell", "ipc", "call", "musicplayer", "prev"]
        running: false
    }

    Process {
        id: volProc
        command: []
        running: false
    }

    function adjustVolume(up) {
        volProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", up ? "5%+" : "5%-"];
        volProc.running = true;
    }

    // ==========================================
    // 2. Cápsula Visual Frosted Glass
    // ==========================================
    Rectangle {
        id: card
        height: 32
        width: rowLayout.implicitWidth + 20
        radius: 16

        color: root.theme ? root.theme.background : Qt.rgba(0.05, 0.07, 0.09, 0.75)
        border.width: 1.2
        border.color: podMouse.containsMouse
                      ? (root.theme ? root.theme.accent : "#00ffcc")
                      : (root.isPlaying
                         ? (root.theme ? root.theme.mediaColor : "#ff79c6")
                         : (root.theme ? root.theme.border : Qt.rgba(0, 1, 0.8, 0.28)))

        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        // Resplandor exterior neón dinámico (Rosa Cyber si suena música, Cian si reposa)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1.5
            radius: parent.radius + 1.5
            color: "transparent"
            border.width: 1
            border.color: root.isPlaying ? Qt.rgba(1.0, 0.47, 0.77, 0.35) : (root.theme ? root.theme.accentGlow : Qt.rgba(0, 1, 0.8, 0.20))
            opacity: podMouse.containsMouse || root.isPlaying ? 1.0 : 0.4
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // Área interactiva de volumen por Scroll
        MouseArea {
            id: podMouse
            anchors.fill: parent
            hoverEnabled: true
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) root.adjustVolume(true);
                else if (wheel.angleDelta.y < 0) root.adjustVolume(false);
            }
        }

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 8

            // 1. Carátula / Thumbnail redondeada con halo
            Rectangle {
                width: 22
                height: 22
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.08)
                clip: true
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: root.trackCover
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.trackCover || parent.children[0].status !== Image.Ready
                    text: "🎵"
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMusicPlayerRequested()
                }
            }

            // 2. Ecualizador de Audio Neón (4 Barras animadas)
            Item {
                width: eqRow.implicitWidth
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: eqRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: [
                            { minH: 3, maxH: 14, dur: 320, del: 0 },
                            { minH: 4, maxH: 11, dur: 240, del: 60 },
                            { minH: 2, maxH: 15, dur: 360, del: 120 },
                            { minH: 3, maxH: 9,  dur: 280, del: 40 }
                        ]

                        delegate: Rectangle {
                            id: eqBar
                            required property var modelData
                            width: 2.2
                            height: root.isPlaying ? modelData.minH : (podMouse.containsMouse ? 8 : 3)
                            radius: 1.1
                            color: root.isPlaying
                                   ? (root.theme ? root.theme.accent : "#00ffcc")
                                   : (root.theme ? root.theme.textDim : "#6e7681")
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation {
                                running: root.isPlaying
                                loops: Animation.Infinite
                                PauseAnimation { duration: eqBar.modelData.del }
                                NumberAnimation {
                                    target: eqBar
                                    property: "height"
                                    to: eqBar.modelData.maxH
                                    duration: eqBar.modelData.dur
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    target: eqBar
                                    property: "height"
                                    to: eqBar.modelData.minH
                                    duration: eqBar.modelData.dur
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMusicPlayerRequested()
                }
            }

            // 3. Título y Artista
            Item {
                width: titleCol.implicitWidth
                height: titleCol.implicitHeight
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    id: titleCol
                    spacing: 1

                    Text {
                        text: root.trackTitle
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.theme ? root.theme.text : "#f0f6fc"
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: Math.min(implicitWidth, 140)
                    }

                    Text {
                        text: root.trackArtist
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 9
                        color: root.theme ? root.theme.textDim : "#8b949e"
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: Math.min(implicitWidth, 140)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMusicPlayerRequested()
                }
            }

            // Separador
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.15)
            }

            // 4. Mini Controles de Reproducción
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // Prev
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: prevM.containsMouse ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.12)) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "⏮"
                        font.pixelSize: 9
                        color: prevM.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#8b949e")
                    }

                    MouseArea {
                        id: prevM
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous();
                            else { mediaPrevProc.running = false; mediaPrevProc.running = true; }
                        }
                    }
                }

                // Play / Pause
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: playM.containsMouse ? Qt.rgba(0, 1, 0.8, 0.28) : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    border.color: root.theme ? root.theme.accent : "#00ffcc"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "⏸" : "▶"
                        font.pixelSize: 9
                        color: root.theme ? root.theme.text : "#f0f6fc"
                    }

                    MouseArea {
                        id: playM
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer) root.activePlayer.togglePlaying();
                            else root.toggleMusicPlayerRequested();
                        }
                    }
                }

                // Next
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: nextM.containsMouse ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.12)) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "⏭"
                        font.pixelSize: 9
                        color: nextM.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#8b949e")
                    }

                    MouseArea {
                        id: nextM
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next();
                            else { mediaNextProc.running = false; mediaNextProc.running = true; }
                        }
                    }
                }
            }
        }
    }
}
