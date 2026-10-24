import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

/**
 * MediaIsland.qml
 * Módulo de reproducción de música para la Dynamic Island Cyberpunk.
 * - Detecta y rastrea reactivamente reproductores MPRIS con Instantiator y Connections.
 * - Siempre sincronizado en tiempo real, al pausar, cambiar de canción o reanudar.
 * - Ecualizador de ondas animado con resplandor neón.
 * - Carátula / Thumbnail redondeado.
 * - Título y Artista con tipografía nítida y elipsis.
 * - Botones interactivos (Anterior, Play/Pause toggle, Siguiente).
 * - Ocultación automática cuando no hay música activa.
 */
Item {
    id: root

    property var theme

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

    property MprisPlayer activePlayer: null

    function updateActivePlayer() {
        var players = Mpris.players ? Mpris.players.values : [];
        if (!players || players.length === 0) {
            root.activePlayer = null;
            return;
        }

        // 1. Prioridad: Buscar cualquier reproductor que esté reproduciendo activamente
        for (var i = 0; i < players.length; i++) {
            var p = players[i];
            if (p && (p.isPlaying || p.playbackState === MprisPlaybackState.Playing)) {
                root.activePlayer = p;
                return;
            }
        }

        // 2. Segunda prioridad: Si el activePlayer actual todavía existe y tiene título, mantenerlo
        if (root.activePlayer) {
            for (var j = 0; j < players.length; j++) {
                if (players[j] === root.activePlayer && players[j].trackTitle && players[j].trackTitle.length > 0) {
                    return;
                }
            }
        }

        // 3. Tercera prioridad: Primer reproductor que tenga un título válido
        for (var k = 0; k < players.length; k++) {
            if (players[k] && players[k].trackTitle && players[k].trackTitle.length > 0) {
                root.activePlayer = players[k];
                return;
            }
        }

        // 4. Fallback al primer reproductor si existe
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
            }
        }

        onObjectAdded: root.updateActivePlayer()
        onObjectRemoved: root.updateActivePlayer()
    }

    // Timer de seguridad para verificar periódicamente por si una app web no emite señales
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateActivePlayer()
    }

    Component.onCompleted: root.updateActivePlayer()

    // Metadatos de respaldo en RAM de Aura Music (para carátula y artista en mpv)
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
    readonly property bool hasMedia: activePlayer !== null && ((activePlayer.trackTitle !== undefined && activePlayer.trackTitle.length > 0) || (isMpvActive && auraTitle.length > 0))
    readonly property bool isPlaying: activePlayer ? (activePlayer.isPlaying || activePlayer.playbackState === MprisPlaybackState.Playing) : false
    readonly property string title: {
        if (isMpvActive && auraTitle.length > 0) return auraTitle;
        return activePlayer ? (activePlayer.trackTitle || "Aura Music") : "Aura Music";
    }
    readonly property string artist: {
        if (isMpvActive && auraArtist.length > 0) return auraArtist;
        return activePlayer ? (activePlayer.trackArtist || "") : "";
    }
    readonly property string artUrl: {
        if (activePlayer && activePlayer.trackArtUrl && activePlayer.trackArtUrl.length > 0) return activePlayer.trackArtUrl;
        if (isMpvActive && auraCover.length > 0) return auraCover;
        return "";
    }

    // Control de visibilidad con tiempo de gracia al pausar
    property bool keepVisiblePaused: false

    Timer {
        id: pauseHideTimer
        interval: 8000
        repeat: false
        onTriggered: root.keepVisiblePaused = false
    }

    onIsPlayingChanged: {
        if (isPlaying) {
            pauseHideTimer.stop();
            root.keepVisiblePaused = true;
        } else if (hasMedia) {
            root.keepVisiblePaused = true;
            pauseHideTimer.restart();
        } else {
            root.keepVisiblePaused = false;
        }
    }

    onActivePlayerChanged: {
        if (isPlaying) {
            pauseHideTimer.stop();
            root.keepVisiblePaused = true;
        }
    }

    onHasMediaChanged: {
        if (hasMedia && isPlaying) {
            pauseHideTimer.stop();
            root.keepVisiblePaused = true;
        }
    }

    signal toggleMusicPlayerRequested()
    readonly property bool isHovered: mediaHoverArea.containsMouse || eqLauncherMouse.containsMouse || titleMouse.containsMouse || prevMouse.containsMouse || playMouse.containsMouse || nextMouse.containsMouse
    readonly property bool shouldDisplay: hasMedia && (isPlaying || keepVisiblePaused)

    implicitHeight: 24
    implicitWidth: shouldDisplay ? (contentRow.implicitWidth + 8) : 26
    width: implicitWidth
    visible: true
    opacity: 1.0
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: 320; easing.type: Easing.OutQuad }
    }

    // ==========================================
    // Componente de Barra de Ecualizador Neón
    // ==========================================
    Component {
        id: eqBarComponent
        Rectangle {
            id: bar
            property int minH: 3ento
            property int maxH: 14
            property int animDuration: 320
            property int delay: 0

            width: 2.5
            height: root.isPlaying ? minH : (eqLauncherMouse.containsMouse ? 9 : 4)
            radius: 1.2
            color: eqLauncherMouse.containsMouse
                   ? (root.theme ? root.theme.mediaColor : "#ff79c6")
                   : (root.theme ? root.theme.accent : "#00ffcc")
            anchors.verticalCenter: parent.verticalCenter

            Behavior on height { NumberAnimation { duration: 150 } }
            Behavior on color { ColorAnimation { duration: 150 } }

            SequentialAnimation {
                running: root.isPlaying
                loops: Animation.Infinite

                PauseAnimation { duration: bar.delay }
                NumberAnimation {
                    target: bar
                    property: "height"
                    to: bar.maxH
                    duration: bar.animDuration
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: bar
                    property: "height"
                    to: bar.minH
                    duration: bar.animDuration
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    MouseArea {
        id: mediaHoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
    }

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        // 1. Ecualizador de Audio Neón (4 Barras) — Clic abre Aura Music siempre
        Rectangle {
            implicitWidth: 20
            width: 20
            implicitHeight: 20
            height: 20
            radius: 10
            color: eqLauncherMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Row {
                anchors.centerIn: parent
                spacing: 1.5

                Loader {
                    sourceComponent: eqBarComponent
                    onLoaded: { item.minH = 4; item.maxH = 14; item.animDuration = 300; item.delay = 0; }
                }
                Loader {
                    sourceComponent: eqBarComponent
                    onLoaded: { item.minH = 3; item.maxH = 11; item.animDuration = 240; item.delay = 60; }
                }
                Loader {
                    sourceComponent: eqBarComponent
                    onLoaded: { item.minH = 5; item.maxH = 15; item.animDuration = 360; item.delay = 120; }
                }
                Loader {
                    sourceComponent: eqBarComponent
                    onLoaded: { item.minH = 2; item.maxH = 9; item.animDuration = 280; item.delay = 40; }
                }
            }

            MouseArea {
                id: eqLauncherMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleMusicPlayerRequested()
            }
        }

        // 2. Carátula del Álbum (si está expandido y existe)
        Rectangle {
            visible: root.shouldDisplay && root.artUrl.length > 0
            implicitWidth: visible ? 18 : 0
            width: implicitWidth
            implicitHeight: 18
            height: 18
            radius: 4
            color: Qt.rgba(1, 1, 1, 0.05)
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        // 3. Título de Pista y Artista
        Item {
            visible: root.shouldDisplay
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: visible ? textCol.implicitWidth : 0
            width: implicitWidth
            implicitHeight: textCol.implicitHeight
            height: implicitHeight

            Column {
                id: textCol
                spacing: 0

                Text {
                    id: titleLabel
                    text: root.title
                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                    font.pixelSize: 10
                    font.bold: true
                    color: root.theme ? root.theme.text : "#f0f6fc"
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 140)
                }

                Text {
                    id: artistLabel
                    visible: root.artist.length > 0
                    text: root.artist
                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                    font.pixelSize: 9
                    color: root.theme ? root.theme.textDim : "#8b949e"
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 120)
                }
            }

            // Clic para abrir Aura Music o traer la ventana del reproductor al frente
            MouseArea {
                id: titleMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton || (root.activePlayer && root.activePlayer.identity && root.activePlayer.identity.indexOf("mpv") !== -1)) {
                        root.toggleMusicPlayerRequested();
                    } else if (root.activePlayer && root.activePlayer.canControl) {
                        root.activePlayer.raise();
                    } else {
                        root.toggleMusicPlayerRequested();
                    }
                }
            }
        }

        // 4. Botones de Control [⏮ ⏸/▶ ⏭]
        Row {
            visible: root.shouldDisplay
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // Botón Anterior
            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: prevMouse.containsMouse ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1,1,1,0.12)) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "⏮"
                    font.pixelSize: 9
                    color: prevMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#8b949e")
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.activePlayer && root.activePlayer.canGoPrevious) {
                            root.activePlayer.previous();
                        } else {
                            mediaPrevProc.running = false;
                            mediaPrevProc.running = true;
                        }
                    }
                }
            }

            // Botón Play / Pausa (Destacado)
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: playMouse.containsMouse 
                       ? (root.theme ? root.theme.accent : "#00ffcc") 
                       : (root.isPlaying ? Qt.rgba(0, 1, 0.8, 0.15) : Qt.rgba(1, 1, 1, 0.08))
                border.width: 1
                border.color: root.isPlaying ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.15)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "⏸" : "▶"
                    font.pixelSize: 9
                    font.bold: true
                    color: playMouse.containsMouse 
                           ? "#0d1117" 
                           : (root.isPlaying ? (root.theme ? root.theme.accent : "#00ffcc") : "#ffffff")
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.activePlayer) {
                            root.activePlayer.togglePlaying();
                        }
                    }
                }
            }

            // Botón Siguiente
            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: nextMouse.containsMouse ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1,1,1,0.12)) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "⏭"
                    font.pixelSize: 9
                    color: nextMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#8b949e")
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.activePlayer && root.activePlayer.canGoNext) {
                            root.activePlayer.next();
                        } else {
                            mediaNextProc.running = false;
                            mediaNextProc.running = true;
                        }
                    }
                }
            }
        }

        // Separador derecho (Media -> Siguiente módulo)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 10
            color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.12)
        }
    }
}
