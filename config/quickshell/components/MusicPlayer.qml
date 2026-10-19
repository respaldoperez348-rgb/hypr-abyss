import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

/**
 * MusicPlayer.qml - Aura Music
 * Reproductor de Música nativo, ultra ligero y reactivo en QML.
 * - Sincronizado dinámicamente con Pywal (Theme.qml): cambia de color con el wallpaper.
 * - Cierre instantáneo con Super + Q, Super + Y o Esc.
 * - Sin fondo oscurecido que cubra la pantalla: flota estéticamente sobre el escritorio.
 * - Lista expandida de canciones con espaciado cómodo.
 * - Conexión en tiempo real con Quickshell MPRIS (Dynamic Island) y mpv.
 */
Item {
    id: root

    property var theme
    property bool isOpen: false
    signal closeRequested()
    property alias card: dialogCard

    // ==========================================
    // 1. Colores reactivos con Pywal (Theme.qml)
    // ==========================================
    readonly property color colAccent: root.theme ? root.theme.accent : "#00ffcc"
    readonly property color colMedia: root.theme ? root.theme.mediaColor : "#ff79c6"
    readonly property color colAccentAlt: root.theme ? root.theme.accentAlt : "#bd93f9"
    readonly property color colBgSolid: root.theme ? root.theme.backgroundSolid : "#0d1117"
    readonly property color colSurface: root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.04)
    readonly property color colSurfaceHover: root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.09)
    readonly property color colBorder: root.theme ? root.theme.border : Qt.rgba(0, 1, 0.8, 0.30)
    readonly property color colBorderSubtle: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.08)
    readonly property color colText: root.theme ? root.theme.text : "#f0f6fc"
    readonly property color colTextDim: root.theme ? root.theme.textDim : "#8b949e"

    // Estado interno
    property bool isSearching: false
    property int currentSongIndex: 0
    property int volumePercent: 80
    property bool hasStartedPlayback: false
    property bool shuffleMode: false
    property bool repeatOneMode: false

    // Canciones iniciales con portadas oficiales reales
    property var radioResults: [
        {
            "id": "yKNxeF4KMsY",
            "title": "Yellow",
            "artist": "Coldplay",
            "duration": "04:33",
            "durationSec": 273,
            "url": "https://www.youtube.com/watch?v=yKNxeF4KMsY",
            "thumbnail": "https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg"
        },
        {
            "id": "dvgZkm1xWPE",
            "title": "Viva La Vida",
            "artist": "Coldplay",
            "duration": "04:02",
            "durationSec": 242,
            "url": "https://www.youtube.com/watch?v=dvgZkm1xWPE",
            "thumbnail": "https://i.ytimg.com/vi/dvgZkm1xWPE/hqdefault.jpg"
        },
        {
            "id": "k4V3Mo61fJM",
            "title": "Fix You",
            "artist": "Coldplay",
            "duration": "04:55",
            "durationSec": 295,
            "url": "https://www.youtube.com/watch?v=k4V3Mo61fJM",
            "thumbnail": "https://i.ytimg.com/vi/k4V3Mo61fJM/hqdefault.jpg"
        },
        {
            "id": "RB-RcX5DS5A",
            "title": "The Scientist",
            "artist": "Coldplay",
            "duration": "04:26",
            "durationSec": 266,
            "url": "https://www.youtube.com/watch?v=RB-RcX5DS5A",
            "thumbnail": "https://i.ytimg.com/vi/RB-RcX5DS5A/hqdefault.jpg"
        },
        {
            "id": "VPRjCeoBqrI",
            "title": "A Sky Full of Stars",
            "artist": "Coldplay",
            "duration": "04:28",
            "durationSec": 268,
            "url": "https://www.youtube.com/watch?v=VPRjCeoBqrI",
            "thumbnail": "https://i.ytimg.com/vi/VPRjCeoBqrI/hqdefault.jpg"
        },
        {
            "id": "1G4isv_Fylg",
            "title": "Paradise",
            "artist": "Coldplay",
            "duration": "04:38",
            "durationSec": 278,
            "url": "https://www.youtube.com/watch?v=1G4isv_Fylg",
            "thumbnail": "https://i.ytimg.com/vi/1G4isv_Fylg/hqdefault.jpg"
        },
        {
            "id": "d020hcWA_Wg",
            "title": "Clocks",
            "artist": "Coldplay",
            "duration": "04:16",
            "durationSec": 256,
            "url": "https://www.youtube.com/watch?v=d020hcWA_Wg",
            "thumbnail": "https://i.ytimg.com/vi/d020hcWA_Wg/hqdefault.jpg"
        },
        {
            "id": "llWhsWaPes4",
            "title": "Somewhere Only We Know",
            "artist": "Keane",
            "duration": "03:55",
            "durationSec": 235,
            "url": "https://www.youtube.com/watch?v=llWhsWaPes4",
            "thumbnail": "https://i.ytimg.com/vi/llWhsWaPes4/hqdefault.jpg"
        }
    ]

    // Control de qué lista se está reproduciendo: "radio" o "favorites"
    property string activePlaylistType: "radio"

    // Lista que se encuentra actualmente sonando en el reproductor
    readonly property var currentPlayingList: (activePlaylistType === "favorites") ? favoritesList : radioResults

    // ==========================================
    // 2. Integración Reactiva con MPRIS (D-Bus)
    // ==========================================
    property MprisPlayer activePlayer: null

    function updateActivePlayer() {
        var players = Mpris.players ? Mpris.players.values : [];
        if (!players || players.length === 0) {
            root.activePlayer = null;
            return;
        }

        // 1. mpv
        for (var i = 0; i < players.length; i++) {
            var p = players[i];
            if (p && p.identity && p.identity.indexOf("mpv") !== -1) {
                root.activePlayer = p;
                return;
            }
        }

        // 2. Reproductor que esté sonando activamente
        for (var j = 0; j < players.length; j++) {
            var pj = players[j];
            if (pj && (pj.isPlaying || pj.playbackState === MprisPlaybackState.Playing)) {
                root.activePlayer = pj;
                return;
            }
        }

        // 3. Fallback
        root.activePlayer = players[0];
    }

    Instantiator {
        id: playerWatcher
        model: Mpris.players

        delegate: Item {
            id: playerItem
            required property MprisPlayer modelData

            Connections {
                target: playerItem.modelData
                function onIsPlayingChanged() { 
                    root.updateActivePlayer(); 
                    if (playerItem.modelData.isPlaying) {
                        root.isChangingSong = false;
                        root.hasStartedPlayback = true;
                        changeDelayTimer.stop();
                    }
                }
                function onPlaybackStateChanged() { 
                    root.updateActivePlayer(); 
                    if (playerItem.modelData.playbackState === MprisPlaybackState.Playing) {
                        root.isChangingSong = false;
                        root.hasStartedPlayback = true;
                        changeDelayTimer.stop();
                    } else if (playerItem.modelData.playbackState === MprisPlaybackState.Stopped) {
                        if (root.autoPlayMix && !root.isChangingSong && root.currentSeconds > 5) {
                            root.autoNext();
                        }
                    }
                }
                function onTrackTitleChanged() { root.updateActivePlayer(); }
                function onTrackArtistChanged() { root.updateActivePlayer(); }
                function onTrackArtUrlChanged() { root.updateActivePlayer(); }
                function onLengthChanged() {
                    if (playerItem.modelData.length > 0) {
                        root.durationSeconds = Math.floor(playerItem.modelData.length);
                    }
                }
                function onVolumeChanged() {
                    if (playerItem.modelData.volume !== undefined) {
                        root.volumePercent = Math.round(playerItem.modelData.volume * 100);
                    }
                }
            }
        }

        onObjectAdded: root.updateActivePlayer()
        onObjectRemoved: root.updateActivePlayer()
    }

    Timer {
        interval: 1000
        running: root.isOpen
        repeat: true
        onTriggered: root.updateActivePlayer()
    }

    readonly property bool isMpvPlayer: activePlayer !== null && activePlayer.identity !== undefined && activePlayer.identity.indexOf("mpv") !== -1
    readonly property bool isPlaying: activePlayer ? (activePlayer.isPlaying || activePlayer.playbackState === MprisPlaybackState.Playing) : false
    readonly property string currentTitle: {
        var list = root.currentPlayingList;
        if (isMpvPlayer && list && list.length > currentSongIndex && list[currentSongIndex]) {
            return list[currentSongIndex].title;
        }
        if (activePlayer && activePlayer.trackTitle && activePlayer.trackTitle.length > 0) return activePlayer.trackTitle;
        if (list && list.length > currentSongIndex && list[currentSongIndex]) return list[currentSongIndex].title;
        return "Yellow";
    }
    readonly property string currentArtist: {
        var list = root.currentPlayingList;
        if (isMpvPlayer && list && list.length > currentSongIndex && list[currentSongIndex]) {
            return list[currentSongIndex].artist;
        }
        if (activePlayer && activePlayer.trackArtist && activePlayer.trackArtist.length > 0) return activePlayer.trackArtist;
        if (list && list.length > currentSongIndex && list[currentSongIndex]) return list[currentSongIndex].artist;
        return "Coldplay";
    }
    readonly property string currentCover: {
        if (activePlayer && activePlayer.trackArtUrl && activePlayer.trackArtUrl.length > 0) return activePlayer.trackArtUrl;
        var list = root.currentPlayingList;
        if (list && list.length > currentSongIndex && list[currentSongIndex]) return list[currentSongIndex].thumbnail;
        return "https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg";
    }

    // Estado reactivo de tiempo continuo y autoplay
    property int currentSeconds: 0
    property int durationSeconds: 273
    property bool autoPlayMix: true
    property bool isChangingSong: false

    // Timer para avance continuo y exacto de segundos
    Timer {
        id: playbackTimer
        interval: 1000
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (activePlayer && activePlayer.position !== undefined) {
                var pos = Math.floor(activePlayer.position);
                if (root.isChangingSong && pos > 5) {
                    root.currentSeconds = 0;
                } else if (!isNaN(pos) && pos >= 0) {
                    root.currentSeconds = pos;
                } else {
                    root.currentSeconds++;
                }
                var dur = Math.floor(activePlayer.length);
                if (!isNaN(dur) && dur > 0) {
                    root.durationSeconds = dur;
                }
            } else {
                root.currentSeconds++;
            }
        }
    }

    function formatTime(sec) {
        if (isNaN(sec) || sec < 0) sec = 0;
        var m = Math.floor(sec / 60);
        var s = Math.floor(sec % 60);
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // ==========================================
    // 3. Sistema de Favoritos ("Me Encanta") y Procesos
    // ==========================================
    property var favoritesList: []
    property bool showFavoritesTab: false

    Process {
        id: favListProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/favorites.py", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    if (Array.isArray(parsed)) {
                        root.favoritesList = parsed;
                    }
                } catch(e) {
                    console.log("[Aura Music] Error loading favorites:", e);
                }
            }
        }
    }

    Process {
        id: favToggleProc
        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    if (Array.isArray(parsed)) {
                        root.favoritesList = parsed;
                    }
                } catch(e) {
                    console.log("[Aura Music] Error updating favorites:", e);
                }
            }
        }
    }

    function loadFavorites() {
        favListProc.running = true;
    }

    function toggleFavorite(song) {
        if (!song) return;
        var songJson = JSON.stringify({
            "id": song.id || song.url,
            "title": song.title || "Canción",
            "artist": song.artist || "Artista",
            "duration": song.duration || "--:--",
            "durationSec": song.durationSec || 200,
            "url": song.url || "",
            "thumbnail": song.thumbnail || ""
        });
        favToggleProc.command = [
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/scripts/favorites.py",
            "toggle",
            songJson
        ];
        favToggleProc.running = true;
    }

    function isSongFavorite(songId) {
        if (!songId || !root.favoritesList) return false;
        for (var i = 0; i < root.favoritesList.length; i++) {
            var item = root.favoritesList[i];
            if (item && (item.id === songId || item.url === songId)) {
                return true;
            }
        }
        return false;
    }

    function playAllFavorites() {
        if (!root.favoritesList || root.favoritesList.length === 0) return;
        root.showFavoritesTab = true;
        root.playSong(0, "favorites");
    }

    Component.onCompleted: {
        root.loadFavorites();
    }

    Process {
        id: searchProc
        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        root.radioResults = parsed;
                        root.showFavoritesTab = false;
                        // No auto-reproducir inmediatamente para que el usuario pueda ver la lista primero
                    }
                } catch(e) {
                    console.log("[Aura Music] Error parsing search results:", e);
                }
                root.isSearching = false;
            }
        }
    }

    Process {
        id: playProc
        command: []
        running: false
    }

    Process {
        id: controlProc
        command: []
        running: false
    }

    function runSearch(query) {
        if (!query || query.trim().length === 0) return;
        root.showFavoritesTab = false;
        root.isSearching = true;
        searchProc.command = [
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/scripts/music_search.py",
            query.trim()
        ];
        searchProc.running = true;
    }

    Timer {
        id: changeDelayTimer
        interval: 2500
        repeat: false
        onTriggered: root.isChangingSong = false
    }

    property double lastSongChangeTime: 0

    function playSong(idx, playlistType, isManual) {
        var now = Date.now();
        var threshold = isManual ? 350 : 1200;
        if (now - root.lastSongChangeTime < threshold) {
            return;
        }
        root.lastSongChangeTime = now;

        if (playlistType !== undefined) {
            root.activePlaylistType = playlistType;
        }
        var list = root.currentPlayingList;
        if (!list || idx < 0 || idx >= list.length) return;
        root.isChangingSong = true;
        root.hasStartedPlayback = true;
        root.currentSongIndex = idx;
        root.currentSeconds = 0;
        var s = list[idx];
        if (s.durationSec && s.durationSec > 0) {
            root.durationSeconds = s.durationSec;
        } else {
            root.durationSeconds = 180;
        }
        playProc.running = false;
        playProc.command = [
            Quickshell.env("HOME") + "/.config/quickshell/scripts/music_play.sh",
            s.url || "",
            s.title || "Música",
            s.artist || "Aura Music",
            s.thumbnail || ""
        ];
        playProc.running = true;
        changeDelayTimer.restart();
    }

    function autoNext() {
        if (root.repeatOneMode) {
            root.lastSongChangeTime = 0;
            root.playSong(root.currentSongIndex, undefined, false);
        } else if (root.autoPlayMix) {
            root.playNextSong(false);
        }
    }

    function playNextSong(isManual) {
        var list = root.currentPlayingList;
        if (!list || list.length === 0) return;
        var next = 0;
        if (root.shuffleMode && list.length > 1) {
            do {
                next = Math.floor(Math.random() * list.length);
            } while (next === root.currentSongIndex);
        } else {
            next = (root.currentSongIndex + 1) % list.length;
        }
        if (next < 0 || isNaN(next)) next = 0;
        root.playSong(next, undefined, isManual);
    }

    function playPreviousSong(isManual) {
        var list = root.currentPlayingList;
        if (!list || list.length === 0) return;
        var prev = (root.currentSongIndex - 1 + list.length) % list.length;
        if (prev < 0 || isNaN(prev)) prev = 0;
        root.playSong(prev, undefined, isManual);
    }

    function togglePlay() {
        if (root.isChangingSong) {
            return;
        }
        if (!root.hasStartedPlayback && !root.isPlaying) {
            root.playSong(root.currentSongIndex, root.activePlaylistType, true);
            return;
        }
        if (activePlayer && activePlayer.canControl) {
            activePlayer.togglePlaying();
        } else {
            controlProc.running = false;
            controlProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/music_control.sh", "toggle"];
            controlProc.running = true;
        }
    }

    function seekRelative(delta) {
        controlProc.running = false;
        controlProc.command = [
            Quickshell.env("HOME") + "/.config/quickshell/scripts/music_control.sh",
            "seek",
            delta.toString()
        ];
        controlProc.running = true;
    }

    function seekAbsolute(targetSec) {
        root.currentSeconds = targetSec;
        controlProc.running = false;
        controlProc.command = [
            Quickshell.env("HOME") + "/.config/quickshell/scripts/music_control.sh",
            "seek_abs",
            targetSec.toString()
        ];
        controlProc.running = true;
    }

    function setVolume(pct) {
        root.volumePercent = Math.max(0, Math.min(100, pct));
        controlProc.running = false;
        controlProc.command = [
            Quickshell.env("HOME") + "/.config/quickshell/scripts/music_control.sh",
            "volume",
            root.volumePercent.toString()
        ];
        controlProc.running = true;
    }

    function stopPlaybackOnly() {
        playProc.running = false;
        root.hasStartedPlayback = false;
        root.isChangingSong = false;
        root.currentSeconds = 0;
        if (activePlayer && activePlayer.canControl && root.isMpvPlayer) {
            activePlayer.stop();
        }
        controlProc.running = false;
        controlProc.command = [
            Quickshell.env("HOME") + "/.config/quickshell/scripts/music_control.sh",
            "quit"
        ];
        controlProc.running = true;
    }

    function stopAndClose() {
        root.stopPlaybackOnly();
        root.closeRequested();
    }

    // ==========================================
    // 4. Tarjeta Flotante (Aura Music)
    // Sin fondo negro que cubra la pantalla
    // ==========================================
    Rectangle {
        id: dialogCard
        width: (root.width > 200) ? Math.min(920, root.width - 40) : 920
        height: (root.height > 200) ? Math.min(640, root.height - 40) : 640
        
        // Centrado inicial reactivo, pero libremente arrastrable con el ratón
        x: Math.round(((root.width > 200 ? root.width : 1920) - width) / 2)
        y: Math.round(((root.height > 200 ? root.height : 1080) - height) / 2)

        // Fondo y bordes reactivos con Pywal
        color: Qt.rgba(root.colBgSolid.r, root.colBgSolid.g, root.colBgSolid.b, 0.92)
        radius: 24
        border.width: 1.5
        border.color: root.colBorder

        scale: root.isOpen ? 1.0 : 0.94
        opacity: root.isOpen ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 240; easing.type: Easing.OutBack }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        // Columna vertical principal
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ----------------------------------------------------
            // ENCABEZADO: Nuevo Nombre, Icono y Mango de Arrastre Libre
            // ----------------------------------------------------
            Rectangle {
                id: headerBar
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: Qt.rgba(root.colBgSolid.r, root.colBgSolid.g, root.colBgSolid.b, 0.96)
                radius: 24

                // MouseArea para arrastrar toda la tarjeta a cualquier parte de la pantalla
                MouseArea {
                    id: headerDragArea
                    anchors.fill: parent
                    drag.target: dialogCard
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 10
                    drag.maximumX: Math.max(10, root.width - dialogCard.width - 10)
                    drag.minimumY: 10
                    drag.maximumY: Math.max(10, root.height - dialogCard.height - 10)
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 24
                    color: parent.color
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: root.colBorderSubtle
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 14

                    // Nuevo Icono Exclusivo con Canvas (Onda y Anillo Neón con Pywal)
                    Rectangle {
                        width: 42
                        height: 42
                        radius: 13
                        color: root.colSurface

                        Canvas {
                            id: logoCanvas
                            anchors.fill: parent
                            property color cAccent: root.colAccent
                            property color cMedia: root.colMedia
                            onCAccentChanged: requestPaint()
                            onCMediaChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width / 2;
                                var cy = height / 2;

                                // Anillo de brillo exterior
                                ctx.beginPath();
                                ctx.arc(cx, cy, 14, 0, Math.PI * 2);
                                ctx.strokeStyle = cMedia;
                                ctx.lineWidth = 2.0;
                                ctx.stroke();

                                // Ondas de sonido centrales
                                ctx.beginPath();
                                ctx.strokeStyle = cAccent;
                                ctx.lineWidth = 2.5;
                                ctx.lineCap = "round";

                                // Barra 1
                                ctx.moveTo(cx - 7, cy - 4);
                                ctx.lineTo(cx - 7, cy + 4);

                                // Barra 2 (central)
                                ctx.moveTo(cx, cy - 9);
                                ctx.lineTo(cx, cy + 9);

                                // Barra 3
                                ctx.moveTo(cx + 7, cy - 5);
                                ctx.lineTo(cx + 7, cy + 5);

                                ctx.stroke();
                            }
                        }
                    }

                    // Título y Subtítulo
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Aura Music"
                            color: root.colText
                            font.pixelSize: 16
                            font.bold: true
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        }

                        Text {
                            text: "Streaming & Audio Engine • Arch Linux"
                            color: root.colTextDim
                            font.pixelSize: 11
                        }
                    }

                    // Indicador de arrastre y botones de acción de ventana
                    RowLayout {
                        spacing: 10

                        RowLayout {
                            spacing: 6
                            opacity: headerDragArea.containsMouse ? 0.9 : 0.45
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Text {
                                text: "⋮⋮ ARRASTRAR"
                                color: root.colTextDim
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1.5
                            }
                        }

                        // Botón Detener Audio (■) si hay música activa
                        Rectangle {
                            visible: root.isPlaying || root.hasStartedPlayback
                            width: 30
                            height: 30
                            radius: 9
                            color: stopHeaderMouse.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.22) : root.colSurface
                            border.width: 1
                            border.color: stopHeaderMouse.containsMouse ? "#ff5555" : root.colBorderSubtle

                            Text {
                                anchors.centerIn: parent
                                text: "■"
                                color: stopHeaderMouse.containsMouse ? "#ff5555" : root.colTextDim
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: stopHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.stopPlaybackOnly()
                            }
                        }

                        // Botón Cerrar / Minimizar a la Dynamic Island (✕)
                        Rectangle {
                            width: 30
                            height: 30
                            radius: 9
                            color: closeHeaderMouse.containsMouse ? root.colSurfaceHover : root.colSurface
                            border.width: 1
                            border.color: closeHeaderMouse.containsMouse ? root.colAccent : root.colBorderSubtle

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: closeHeaderMouse.containsMouse ? root.colAccent : root.colTextDim
                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                id: closeHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeRequested()
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // BARRA DE BÚSQUEDA Y CHIPS RÁPIDOS (Sin emojis rotos)
            // ----------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                color: Qt.rgba(root.colBgSolid.r, root.colBgSolid.g, root.colBgSolid.b, 0.70)

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: root.colBorderSubtle
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // Input de búsqueda con acento dinámico de Pywal
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 12
                        color: root.colSurface
                        border.width: 1.5
                        border.color: searchField.activeFocus ? root.colAccent : root.colBorderSubtle

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 6
                            spacing: 10

                            // Icono de Lupa vectorial limpio
                            Canvas {
                                width: 16
                                height: 16
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = root.colTextDim;
                                    ctx.lineWidth = 1.8;
                                    ctx.beginPath();
                                    ctx.arc(6, 6, 5, 0, Math.PI * 2);
                                    ctx.moveTo(10, 10);
                                    ctx.lineTo(15, 15);
                                    ctx.stroke();
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: searchField.text.length === 0
                                    text: "Buscar canción, artista o mix en YouTube..."
                                    color: root.colTextDim
                                    font.pixelSize: 13
                                    opacity: 0.65
                                }

                                TextInput {
                                    id: searchField
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: "Coldplay Yellow"
                                    color: root.colText
                                    font.pixelSize: 13
                                    clip: true
                                    selectByMouse: true
                                    Keys.onReturnPressed: {
                                        searchField.focus = false;
                                        root.runSearch(searchField.text);
                                    }
                                    Keys.onEnterPressed: {
                                        searchField.focus = false;
                                        root.runSearch(searchField.text);
                                    }
                                }
                            }

                            // Botón limpiar texto de búsqueda (✕)
                            Rectangle {
                                visible: searchField.text.length > 0
                                width: 22
                                height: 22
                                radius: 11
                                color: clearSearchMouse.containsMouse ? root.colSurfaceHover : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: clearSearchMouse.containsMouse ? root.colText : root.colTextDim
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    id: clearSearchMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchField.text = "";
                                        searchField.forceActiveFocus();
                                    }
                                }
                            }

                            // Botón Buscar con degradado Pywal
                            Rectangle {
                                width: 92
                                height: 32
                                radius: 9
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.colMedia }
                                    GradientStop { position: 1.0; color: root.colAccent }
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: root.isSearching ? "Buscando" : "Buscar"
                                        color: "#0d1117"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                    Text {
                                        text: "➔"
                                        color: "#0d1117"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    id: btnSearchArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchField.focus = false;
                                        root.runSearch(searchField.text);
                                    }
                                }
                            }
                        }
                    }

                    // Chips rápidos limpios y modernos con Sección Destacada de MIX
                    Row {
                        Layout.fillWidth: true
                        spacing: 8

                        // Botón de Sección Destacada de MIX (Mix Infinito)
                        Rectangle {
                            width: mixChipRow.implicitWidth + 26
                            height: 30
                            radius: 9
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: root.colMedia }
                                GradientStop { position: 1.0; color: root.colAccent }
                            }

                            Row {
                                id: mixChipRow
                                anchors.centerIn: parent
                                spacing: 6

                                Canvas {
                                    width: 11
                                    height: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.fillStyle = "#0d1117";
                                        ctx.beginPath();
                                        ctx.moveTo(6.5, 0.5);
                                        ctx.lineTo(2.0, 6.0);
                                        ctx.lineTo(5.5, 6.0);
                                        ctx.lineTo(4.5, 11.5);
                                        ctx.lineTo(9.5, 5.0);
                                        ctx.lineTo(6.0, 5.0);
                                        ctx.closePath();
                                        ctx.fill();
                                    }
                                }

                                Text {
                                    text: "Mix Infinito"
                                    color: "#0d1117"
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchField.text = "Mix Variado 2026";
                                    root.runSearch("mix canciones exitos variados 2026 playlist");
                                }
                            }
                        }

                        // Botón de Favoritas Destacado
                        Rectangle {
                            width: favChipRow.implicitWidth + 26
                            height: 30
                            radius: 9
                            color: root.showFavoritesTab ? root.colMedia : root.colSurface
                            border.width: 1
                            border.color: root.showFavoritesTab ? root.colMedia : root.colBorderSubtle

                            Row {
                                id: favChipRow
                                anchors.centerIn: parent
                                spacing: 6

                                Canvas {
                                    width: 12
                                    height: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    property color heartCol: root.showFavoritesTab ? "#0d1117" : root.colMedia
                                    onHeartColChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.fillStyle = heartCol;
                                        ctx.beginPath();
                                        ctx.moveTo(6, 3.5);
                                        ctx.bezierCurveTo(6, 2.0, 4.6, 0.8, 3.0, 0.8);
                                        ctx.bezierCurveTo(1.3, 0.8, 0.5, 2.0, 0.5, 3.8);
                                        ctx.bezierCurveTo(0.5, 6.2, 3.6, 8.8, 6, 11.2);
                                        ctx.bezierCurveTo(8.4, 8.8, 11.5, 6.2, 11.5, 3.8);
                                        ctx.bezierCurveTo(11.5, 2.0, 10.7, 0.8, 9.0, 0.8);
                                        ctx.bezierCurveTo(7.4, 0.8, 6, 2.0, 6, 3.5);
                                        ctx.fill();
                                    }
                                }

                                Text {
                                    text: "Favoritas (" + root.favoritesList.length + ")"
                                    color: root.showFavoritesTab ? "#0d1117" : root.colText
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.loadFavorites();
                                    root.showFavoritesTab = !root.showFavoritesTab;
                                }
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 18
                            color: root.colBorderSubtle
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                            model: [
                                { label: "Mix Diario", query: "daily mix canciones variadas musica" },
                                { label: "Mix Urbano", query: "mix reggaeton trap latino exitos" },
                                { label: "Mix Rock", query: "mix rock en espanol e ingles clasicos" },
                                { label: "Mix Lofi", query: "lofi chill mix beats to relax study to" },
                                { label: "Mix Synthwave", query: "synthwave retro 80s continuous mix" }
                            ]

                            delegate: Rectangle {
                                width: chipText.implicitWidth + 24
                                height: 30
                                radius: 9
                                color: chipArea.containsMouse ? root.colSurfaceHover : root.colSurface
                                border.width: 1
                                border.color: chipArea.containsMouse ? root.colAccent : root.colBorderSubtle

                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: chipArea.containsMouse ? root.colAccent : root.colText
                                    font.pixelSize: 11
                                    font.bold: chipArea.containsMouse
                                }

                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchField.text = modelData.label;
                                        root.runSearch(modelData.query);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // CUERPO PRINCIPAL (2 COLUMNAS)
            // ----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ==========================================
                // COLUMNA IZQUIERDA: REPRODUCTOR
                // ==========================================
                Rectangle {
                    Layout.preferredWidth: 320
                    Layout.fillHeight: true
                    color: Qt.rgba(root.colBgSolid.r, root.colBgSolid.g, root.colBgSolid.b, 0.40)

                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: 1
                        color: root.colBorderSubtle
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        // Carátula Grande
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 194
                            height: 194
                            radius: 16
                            color: root.colSurface
                            border.width: 2
                            border.color: root.colBorderSubtle
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: (root.isOpen && root.currentCover) ? root.currentCover : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                onStatusChanged: {
                                    if (status === Image.Error) source = ""
                                }
                            }

                            // Badge Superior Izquierda
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 8
                                width: 78
                                height: 20
                                radius: 6
                                color: "#dd000000"
                                border.width: 1
                                border.color: root.colAccent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Aura Player"
                                    color: root.colAccent
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            // Ecualizador Animado de 5 Ondas (Colores Pywal)
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 8
                                width: 44
                                height: 24
                                radius: 8
                                color: "#dd000000"
                                border.width: 1
                                border.color: root.colBorderSubtle

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Rectangle {
                                        width: 3; height: 8; radius: 1.5; color: root.colMedia
                                        SequentialAnimation on height {
                                            running: root.isPlaying && root.isOpen; loops: Animation.Infinite
                                            PropertyAnimation { to: 16; duration: 450; easing.type: Easing.InOutQuad }
                                            PropertyAnimation { to: 6; duration: 450; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                    Rectangle {
                                        width: 3; height: 12; radius: 1.5; color: root.colAccent
                                        SequentialAnimation on height {
                                            running: root.isPlaying && root.isOpen; loops: Animation.Infinite
                                            PropertyAnimation { to: 18; duration: 380; easing.type: Easing.InOutQuad }
                                            PropertyAnimation { to: 8; duration: 380; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                    Rectangle {
                                        width: 3; height: 15; radius: 1.5; color: root.colAccentAlt
                                        SequentialAnimation on height {
                                            running: root.isPlaying && root.isOpen; loops: Animation.Infinite
                                            PropertyAnimation { to: 20; duration: 520; easing.type: Easing.InOutQuad }
                                            PropertyAnimation { to: 7; duration: 520; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                    Rectangle {
                                        width: 3; height: 10; radius: 1.5; color: root.colMedia
                                        SequentialAnimation on height {
                                            running: root.isPlaying && root.isOpen; loops: Animation.Infinite
                                            PropertyAnimation { to: 17; duration: 410; easing.type: Easing.InOutQuad }
                                            PropertyAnimation { to: 5; duration: 410; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                    Rectangle {
                                        width: 3; height: 7; radius: 1.5; color: root.colAccent
                                        SequentialAnimation on height {
                                            running: root.isPlaying && root.isOpen; loops: Animation.Infinite
                                            PropertyAnimation { to: 15; duration: 490; easing.type: Easing.InOutQuad }
                                            PropertyAnimation { to: 6; duration: 490; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                }
                            }
                        }

                        // Badge Estado (SONANDO AHORA / EN PAUSA) y Modo Mix
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            Rectangle {
                                width: stateRow.implicitWidth + 24
                                height: 24
                                radius: 12
                                color: root.isChangingSong ? Qt.rgba(root.colMedia.r, root.colMedia.g, root.colMedia.b, 0.20) : (root.isPlaying ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15) : Qt.rgba(1, 0.7, 0, 0.15))
                                border.width: 1
                                border.color: root.isChangingSong ? root.colMedia : (root.isPlaying ? root.colAccent : "#f59e0b")

                                Row {
                                    id: stateRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Rectangle {
                                        width: 6; height: 6; radius: 3
                                        color: root.isChangingSong ? root.colMedia : (root.isPlaying ? root.colAccent : "#f59e0b")
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: root.isChangingSong ? "CARGANDO..." : (root.isPlaying ? "SONANDO AHORA" : "EN PAUSA")
                                        color: root.isChangingSong ? root.colMedia : (root.isPlaying ? root.colAccent : "#f59e0b")
                                        font.pixelSize: 10
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Botón de Alternancia Auto-Play Mix
                            Rectangle {
                                width: mixStateRow.implicitWidth + 24
                                height: 24
                                radius: 12
                                color: root.autoPlayMix ? Qt.rgba(root.colMedia.r, root.colMedia.g, root.colMedia.b, 0.20) : root.colSurface
                                border.width: 1
                                border.color: root.autoPlayMix ? root.colMedia : root.colBorderSubtle

                                Row {
                                    id: mixStateRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "∞"
                                        color: root.autoPlayMix ? root.colMedia : root.colTextDim
                                        font.pixelSize: 13
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: root.autoPlayMix ? "AUTO-PLAY" : "MANUAL"
                                        color: root.autoPlayMix ? root.colMedia : root.colTextDim
                                        font.pixelSize: 9
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.autoPlayMix = !root.autoPlayMix
                                }
                            }
                        }

                        // Título, Artista y Botón "Me Encanta" (Favoritos)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: root.currentTitle
                                    color: root.colText
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.currentArtist
                                    color: root.colTextDim
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            // Botón de Corazón "Me Encanta" con Vector Canvas
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 10
                                color: heartArea.containsMouse ? root.colSurfaceHover : root.colSurface
                                border.width: 1
                                border.color: isFavNow ? root.colMedia : root.colBorderSubtle

                                readonly property bool isFavNow: {
                                    var list = root.currentPlayingList;
                                    var curr = (list && list.length > root.currentSongIndex) ? list[root.currentSongIndex] : null;
                                    var idToCheck = curr ? (curr.id || curr.url) : root.currentTitle;
                                    return root.isSongFavorite(idToCheck);
                                }

                                Canvas {
                                    id: heartMainCanvas
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    property bool fav: parent.isFavNow
                                    property color favCol: root.colMedia
                                    property color dimCol: root.colTextDim
                                    onFavChanged: requestPaint()
                                    onFavColChanged: requestPaint()
                                    scale: heartArea.pressed ? 0.85 : (fav ? 1.15 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.beginPath();
                                        ctx.moveTo(8, 4.8);
                                        ctx.bezierCurveTo(8, 2.7, 6.1, 1.4, 4.0, 1.4);
                                        ctx.bezierCurveTo(1.8, 1.4, 0.7, 3.0, 0.7, 5.2);
                                        ctx.bezierCurveTo(0.7, 8.4, 4.9, 11.9, 8, 14.8);
                                        ctx.bezierCurveTo(11.1, 11.9, 15.3, 8.4, 15.3, 5.2);
                                        ctx.bezierCurveTo(15.3, 3.0, 14.2, 1.4, 12.0, 1.4);
                                        ctx.bezierCurveTo(9.9, 1.4, 8, 2.7, 8, 4.8);
                                        if (fav) {
                                            ctx.fillStyle = favCol;
                                            ctx.fill();
                                        } else {
                                            ctx.strokeStyle = dimCol;
                                            ctx.lineWidth = 1.4;
                                            ctx.stroke();
                                        }
                                    }
                                }

                                MouseArea {
                                    id: heartArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        var list = root.currentPlayingList;
                                        var curr = (list && list.length > root.currentSongIndex) ? list[root.currentSongIndex] : null;
                                        if (!curr) {
                                            curr = {
                                                "id": root.currentTitle,
                                                "title": root.currentTitle,
                                                "artist": root.currentArtist,
                                                "duration": root.formatTime(root.durationSeconds),
                                                "durationSec": root.durationSeconds,
                                                "url": "",
                                                "thumbnail": root.currentCover
                                            };
                                        }
                                        if (curr) {
                                            root.toggleFavorite(curr);
                                        }
                                    }
                                }
                            }
                        }

                        // Barra de Progreso y Tiempo con Control Deslizante Neón
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: root.formatTime(root.currentSeconds)
                                    color: root.colAccent
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.formatTime(root.durationSeconds)
                                    color: root.colTextDim
                                    font.pixelSize: 11
                                }
                            }

                            Rectangle {
                                id: progressTrack
                                Layout.fillWidth: true
                                height: 7
                                radius: 3.5
                                color: root.colSurface

                                readonly property real progressRatio: Math.min(1.0, Math.max(0.0, root.currentSeconds / Math.max(1, root.durationSeconds)))

                                Rectangle {
                                    id: progressFill
                                    height: parent.height
                                    width: progressTrack.progressRatio * parent.width
                                    radius: 3.5
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: root.colMedia }
                                        GradientStop { position: 1.0; color: root.colAccent }
                                    }
                                }

                                // Cabezal neón (Thumb)
                                Rectangle {
                                    width: progressMouse.containsMouse || progressMouse.pressed ? 13 : 9
                                    height: width
                                    radius: width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(0, Math.min(parent.width - width, progressFill.width - width / 2))
                                    color: "#ffffff"
                                    border.width: 2
                                    border.color: root.colAccent
                                    Behavior on width { NumberAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: progressMouse
                                    anchors.fill: parent
                                    anchors.topMargin: -5
                                    anchors.bottomMargin: -5
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: (mouse) => {
                                        var pct = Math.max(0, Math.min(1, mouse.x / width));
                                        root.currentSeconds = Math.floor(pct * root.durationSeconds);
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (pressed) {
                                            var pct = Math.max(0, Math.min(1, mouse.x / width));
                                            root.currentSeconds = Math.floor(pct * root.durationSeconds);
                                        }
                                    }
                                    onReleased: (mouse) => {
                                        var pct = Math.max(0, Math.min(1, mouse.x / width));
                                        var targetSec = Math.floor(pct * root.durationSeconds);
                                        root.seekAbsolute(targetSec);
                                    }
                                }
                            }
                        }

                        // Botones Principales (Shuffle, Anterior, Play/Pausa, Siguiente, Repeat One)
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            // Botón Aleatorio (Shuffle)
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 10
                                color: root.shuffleMode
                                       ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.20)
                                       : (btnShuffleArea.containsMouse ? root.colSurfaceHover : root.colSurface)
                                border.width: 1
                                border.color: root.shuffleMode ? root.colAccent : root.colBorderSubtle

                                Text {
                                    anchors.centerIn: parent
                                    text: "⇄"
                                    color: root.shuffleMode ? root.colAccent : root.colTextDim
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                MouseArea {
                                    id: btnShuffleArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.shuffleMode = !root.shuffleMode
                                }
                            }

                            // Botón Anterior
                            Rectangle {
                                width: 38
                                height: 38
                                radius: 12
                                color: btnPrevArea.containsMouse ? root.colSurfaceHover : root.colSurface
                                border.width: 1
                                border.color: btnPrevArea.containsMouse ? root.colAccent : root.colBorderSubtle

                                Text {
                                    anchors.centerIn: parent
                                    text: "⏮"
                                    color: root.colText
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                MouseArea {
                                    id: btnPrevArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playPreviousSong(true)
                                }
                            }

                            // Botón Central Play / Pausa
                            Rectangle {
                                width: 50
                                height: 50
                                radius: 16
                                scale: btnPlayArea.pressed ? 0.93 : (btnPlayArea.containsMouse ? 1.05 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 120 } }
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.colMedia }
                                    GradientStop { position: 1.0; color: root.colAccent }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.isPlaying ? "❚❚" : "▶"
                                    color: "#0d1117"
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                MouseArea {
                                    id: btnPlayArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.togglePlay()
                                }
                            }

                            // Botón Siguiente
                            Rectangle {
                                width: 38
                                height: 38
                                radius: 12
                                color: btnNextArea.containsMouse ? root.colSurfaceHover : root.colSurface
                                border.width: 1
                                border.color: btnNextArea.containsMouse ? root.colAccent : root.colBorderSubtle

                                Text {
                                    anchors.centerIn: parent
                                    text: "⏭"
                                    color: root.colText
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                MouseArea {
                                    id: btnNextArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playNextSong(true)
                                }
                            }

                            // Botón Repetir Pista Actual (Repeat 1)
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 10
                                color: root.repeatOneMode
                                       ? Qt.rgba(root.colMedia.r, root.colMedia.g, root.colMedia.b, 0.22)
                                       : (btnRepeatArea.containsMouse ? root.colSurfaceHover : root.colSurface)
                                border.width: 1
                                border.color: root.repeatOneMode ? root.colMedia : root.colBorderSubtle

                                Text {
                                    anchors.centerIn: parent
                                    text: "↻1"
                                    color: root.repeatOneMode ? root.colMedia : root.colTextDim
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    id: btnRepeatArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.repeatOneMode = !root.repeatOneMode
                                }
                            }
                        }

                        // Slider de Volumen con Icono Vectorial Dinámico y Mute al Clic
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 10
                            color: root.colSurface
                            border.width: 1
                            border.color: root.colBorderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                // Icono de volumen vectorial reactivo
                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 5
                                    color: volIconArea.containsMouse ? root.colSurfaceHover : "transparent"

                                    Canvas {
                                        id: volIconCanvas
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        property int vol: root.volumePercent
                                        property color col: vol > 0 ? root.colAccent : root.colTextDim
                                        onVolChanged: requestPaint()
                                        onColChanged: requestPaint()

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = col;
                                            ctx.fillStyle = col;
                                            ctx.lineWidth = 1.4;
                                            ctx.lineCap = "round";
                                            ctx.lineJoin = "round";

                                            // Base del altavoz
                                            ctx.beginPath();
                                            ctx.rect(1, 6, 3, 6);
                                            ctx.fill();

                                            // Cono del altavoz
                                            ctx.beginPath();
                                            ctx.moveTo(4, 6);
                                            ctx.lineTo(8, 2.5);
                                            ctx.lineTo(8, 15.5);
                                            ctx.lineTo(4, 12);
                                            ctx.closePath();
                                            ctx.fill();

                                            if (vol === 0) {
                                                // Mute: X limpia
                                                ctx.beginPath();
                                                ctx.moveTo(11, 6);
                                                ctx.lineTo(16, 12);
                                                ctx.moveTo(16, 6);
                                                ctx.lineTo(11, 12);
                                                ctx.stroke();
                                            } else {
                                                // Onda 1
                                                ctx.beginPath();
                                                ctx.arc(8, 9, 3.5, -Math.PI / 3, Math.PI / 3);
                                                ctx.stroke();

                                                // Onda 2
                                                if (vol > 35) {
                                                    ctx.beginPath();
                                                    ctx.arc(8, 9, 6.5, -Math.PI / 3, Math.PI / 3);
                                                    ctx.stroke();
                                                }

                                                // Onda 3
                                                if (vol > 70) {
                                                    ctx.beginPath();
                                                    ctx.arc(8, 9, 9.5, -Math.PI / 3, Math.PI / 3);
                                                    ctx.stroke();
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: volIconArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            if (root.volumePercent > 0) {
                                                root.setVolume(0);
                                            } else {
                                                root.setVolume(80);
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: "Volumen"
                                    color: root.colTextDim
                                    font.pixelSize: 11
                                }

                                Rectangle {
                                    id: volTrack
                                    Layout.fillWidth: true
                                    height: 6
                                    radius: 3
                                    color: root.colSurfaceHover

                                    Rectangle {
                                        height: parent.height
                                        width: (root.volumePercent / 100.0) * parent.width
                                        radius: 3
                                        color: root.colAccent
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onPositionChanged: (mouse) => {
                                            if (pressed) {
                                                var pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)));
                                                root.setVolume(pct);
                                            }
                                        }
                                        onClicked: (mouse) => {
                                            var pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)));
                                            root.setVolume(pct);
                                        }
                                    }
                                }

                                Text {
                                    text: root.volumePercent + "%"
                                    color: root.colText
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // COLUMNA DERECHA: LISTA EXPANDIDA DE CANCIONES
                // Sin cajita de teclado, con más canciones y espacio cómodo
                // ==========================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        // Cabecera interactiva con pestañas: Radio Mix vs Mis Favoritas
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // Pestaña 1: Radio Mix & Relacionadas
                            Rectangle {
                                height: 32
                                width: tabRadioRow.implicitWidth + 26
                                radius: 9
                                color: !root.showFavoritesTab ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.16) : "transparent"
                                border.width: 1
                                border.color: !root.showFavoritesTab ? root.colAccent : root.colBorderSubtle

                                Row {
                                    id: tabRadioRow
                                    anchors.centerIn: parent
                                    spacing: 7

                                    Canvas {
                                        id: tabRadioIcon
                                        width: 14
                                        height: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        property color iconColor: !root.showFavoritesTab ? root.colAccent : root.colTextDim
                                        onIconColorChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = iconColor;
                                            ctx.fillStyle = iconColor;
                                            ctx.lineWidth = 1.3;
                                            ctx.lineCap = "round";
                                            // Antena
                                            ctx.beginPath();
                                            ctx.moveTo(7, 4.5);
                                            ctx.lineTo(7, 13);
                                            ctx.stroke();
                                            // Base
                                            ctx.beginPath();
                                            ctx.moveTo(4, 13);
                                            ctx.lineTo(10, 13);
                                            ctx.stroke();
                                            // Emisor central
                                            ctx.beginPath();
                                            ctx.arc(7, 4.5, 1.6, 0, Math.PI * 2);
                                            ctx.fill();
                                            // Ondas
                                            ctx.beginPath();
                                            ctx.arc(7, 4.5, 4.5, Math.PI * 0.75, Math.PI * 1.25);
                                            ctx.stroke();
                                            ctx.beginPath();
                                            ctx.arc(7, 4.5, 4.5, -Math.PI * 0.25, Math.PI * 0.25);
                                            ctx.stroke();
                                        }
                                    }

                                    Text {
                                        text: "Radio Mix & Relacionadas"
                                        color: !root.showFavoritesTab ? root.colAccent : root.colTextDim
                                        font.pixelSize: 11
                                        font.bold: !root.showFavoritesTab
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showFavoritesTab = false
                                }
                            }

                            // Pestaña 2: Mis Favoritas
                            Rectangle {
                                height: 32
                                width: tabFavRow.implicitWidth + 26
                                radius: 9
                                color: root.showFavoritesTab ? Qt.rgba(root.colMedia.r, root.colMedia.g, root.colMedia.b, 0.20) : "transparent"
                                border.width: 1
                                border.color: root.showFavoritesTab ? root.colMedia : root.colBorderSubtle

                                Row {
                                    id: tabFavRow
                                    anchors.centerIn: parent
                                    spacing: 7

                                    Canvas {
                                        id: tabFavIcon
                                        width: 13
                                        height: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                        property color iconColor: root.showFavoritesTab ? root.colMedia : root.colTextDim
                                        onIconColorChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.fillStyle = iconColor;
                                            ctx.beginPath();
                                            ctx.moveTo(6.5, 3.8);
                                            ctx.bezierCurveTo(6.5, 2.2, 5.0, 1.0, 3.2, 1.0);
                                            ctx.bezierCurveTo(1.4, 1.0, 0.5, 2.3, 0.5, 4.2);
                                            ctx.bezierCurveTo(0.5, 6.8, 4.0, 9.5, 6.5, 12.0);
                                            ctx.bezierCurveTo(9.0, 9.5, 12.5, 6.8, 12.5, 4.2);
                                            ctx.bezierCurveTo(12.5, 2.3, 11.6, 1.0, 9.8, 1.0);
                                            ctx.bezierCurveTo(8.0, 1.0, 6.5, 2.2, 6.5, 3.8);
                                            ctx.fill();
                                        }
                                    }

                                    Text {
                                        text: "Mis Favoritas (" + root.favoritesList.length + ")"
                                        color: root.showFavoritesTab ? root.colMedia : root.colTextDim
                                        font.pixelSize: 11
                                        font.bold: root.showFavoritesTab
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.loadFavorites();
                                        root.showFavoritesTab = true;
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Botón "Reproducir Todo" cuando está en Favoritas
                            Rectangle {
                                visible: root.showFavoritesTab && root.favoritesList.length > 0
                                height: 32
                                width: playAllRow.implicitWidth + 24
                                radius: 9
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.colMedia }
                                    GradientStop { position: 1.0; color: root.colAccent }
                                }

                                Row {
                                    id: playAllRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "▶"
                                        color: "#0d1117"
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Reproducir Todo"
                                        color: "#0d1117"
                                        font.pixelSize: 11
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playAllFavorites()
                                }
                            }
                        }

                        // Vista cuando no hay canciones favoritas
                        Rectangle {
                            visible: root.showFavoritesTab && root.favoritesList.length === 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12

                                Canvas {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 44
                                    height: 44
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.strokeStyle = root.colTextDim;
                                        ctx.lineWidth = 2.0;
                                        ctx.beginPath();
                                        ctx.moveTo(22, 13);
                                        ctx.bezierCurveTo(22, 7, 16.5, 3.5, 11, 3.5);
                                        ctx.bezierCurveTo(5, 3.5, 2, 7.5, 2, 14);
                                        ctx.bezierCurveTo(2, 23, 13, 32, 22, 40);
                                        ctx.bezierCurveTo(31, 32, 42, 23, 42, 14);
                                        ctx.bezierCurveTo(42, 7.5, 39, 3.5, 33, 3.5);
                                        ctx.bezierCurveTo(27.5, 3.5, 22, 7, 22, 13);
                                        ctx.stroke();
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Aún no tienes canciones favoritas guardadas"
                                    color: root.colText
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Toca el corazón en cualquier canción para crear tu lista personal"
                                    color: root.colTextDim
                                    font.pixelSize: 12
                                }
                            }
                        }

                        // Contenedor con Desplazamiento Vertical Suave ("Escalera eléctrica" sin desborde)
                        Item {
                            visible: !root.showFavoritesTab || root.favoritesList.length > 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: songListView
                                anchors.fill: parent
                                anchors.rightMargin: customScrollBar.visible ? 10 : 0
                                clip: true
                                spacing: 8
                                model: root.showFavoritesTab ? root.favoritesList : root.radioResults
                                boundsBehavior: Flickable.StopAtBounds

                                delegate: Item {
                                    width: songListView.width
                                    height: 54

                                    Rectangle {
                                        id: songCard
                                        anchors.fill: parent
                                        radius: 12

                                        readonly property bool isThisPlaying: {
                                            var list = root.currentPlayingList;
                                            var currentSong = (list && list.length > root.currentSongIndex) ? list[root.currentSongIndex] : null;
                                            if (!currentSong) return false;
                                            return (currentSong.id === modelData.id || currentSong.url === modelData.url);
                                        }

                                        color: isThisPlaying
                                               ? Qt.rgba(root.colMedia.r, root.colMedia.g, root.colMedia.b, 0.16)
                                               : (cardMouse.containsMouse ? root.colSurfaceHover : root.colSurface)
                                        border.width: isThisPlaying ? 1.5 : 1
                                        border.color: isThisPlaying ? root.colMedia : (cardMouse.containsMouse ? root.colAccent : root.colBorderSubtle)

                                        MouseArea {
                                            id: cardMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var targetPlaylist = root.showFavoritesTab ? "favorites" : "radio";
                                                if (songCard.isThisPlaying && !root.isChangingSong) {
                                                    root.togglePlay();
                                                } else {
                                                    root.playSong(index, targetPlaylist);
                                                }
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 14
                                            spacing: 12

                                            // Miniatura de álbum
                                            Rectangle {
                                                width: 40
                                                height: 40
                                                radius: 8
                                                color: root.colSurface
                                                clip: true

                                                Image {
                                                    anchors.fill: parent
                                                    source: (root.isOpen && modelData.thumbnail) ? modelData.thumbnail : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    onStatusChanged: {
                                                        if (status === Image.Error) source = ""
                                                    }
                                                }
                                            }

                                            // Título y Artista
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: (songCard.isThisPlaying ? "▶ " : "") + modelData.title
                                                    color: songCard.isThisPlaying ? root.colMedia : root.colText
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.artist
                                                    color: root.colTextDim
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            // Duración
                                            Text {
                                                text: modelData.duration
                                                color: root.colTextDim
                                                font.pixelSize: 11
                                            }

                                            // Botón Me Encanta (Corazón Vectorial en cada tarjeta)
                                            Rectangle {
                                                width: 32
                                                height: 32
                                                radius: 9
                                                color: cardFavArea.containsMouse ? root.colSurfaceHover : "transparent"

                                                readonly property bool isFav: root.isSongFavorite(modelData.id || modelData.url)

                                                Canvas {
                                                    id: cardHeartCanvas
                                                    anchors.centerIn: parent
                                                    width: 14
                                                    height: 14
                                                    property bool fav: parent.isFav
                                                    property color favCol: root.colMedia
                                                    property color dimCol: root.colTextDim
                                                    onFavChanged: requestPaint()
                                                    onFavColChanged: requestPaint()
                                                    scale: cardFavArea.pressed ? 0.8 : (fav ? 1.15 : 1.0)
                                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                                    onPaint: {
                                                        var ctx = getContext("2d");
                                                        ctx.reset();
                                                        ctx.beginPath();
                                                        ctx.moveTo(7, 4.2);
                                                        ctx.bezierCurveTo(7, 2.4, 5.3, 1.2, 3.5, 1.2);
                                                        ctx.bezierCurveTo(1.6, 1.2, 0.6, 2.6, 0.6, 4.6);
                                                        ctx.bezierCurveTo(0.6, 7.4, 4.3, 10.4, 7, 13.0);
                                                        ctx.bezierCurveTo(9.7, 10.4, 13.4, 7.4, 13.4, 4.6);
                                                        ctx.bezierCurveTo(13.4, 2.6, 12.4, 1.2, 10.5, 1.2);
                                                        ctx.bezierCurveTo(8.7, 1.2, 7, 2.4, 7, 4.2);
                                                        if (fav) {
                                                            ctx.fillStyle = favCol;
                                                            ctx.fill();
                                                        } else {
                                                            ctx.strokeStyle = dimCol;
                                                            ctx.lineWidth = 1.3;
                                                            ctx.stroke();
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: cardFavArea
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    onClicked: root.toggleFavorite(modelData)
                                                }
                                            }

                                            // Botón Play en la tarjeta
                                            Rectangle {
                                                width: 32
                                                height: 32
                                                radius: 9
                                                color: songCard.isThisPlaying ? root.colMedia : root.colSurfaceHover

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: songCard.isThisPlaying && root.isPlaying ? "❚❚" : "▶"
                                                    color: songCard.isThisPlaying ? "#0d1117" : root.colText
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Barra de Desplazamiento Personalizada Cyberpunk
                            Rectangle {
                                id: customScrollBar
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 4
                                radius: 2
                                color: Qt.rgba(1, 1, 1, 0.05)
                                visible: songListView.visibleArea.heightRatio < 1.0

                                Rectangle {
                                    id: scrollThumb
                                    width: parent.width
                                    height: Math.max(26, songListView.visibleArea.heightRatio * parent.height)
                                    y: songListView.visibleArea.yPosition * parent.height
                                    radius: 2
                                    color: scrollArea.pressed ? root.colAccent : (scrollArea.containsMouse ? root.colMedia : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.40))
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: scrollArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    drag.target: scrollThumb
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: 0
                                    drag.maximumY: customScrollBar.height - scrollThumb.height
                                    onPositionChanged: {
                                        if (pressed) {
                                            var ratio = scrollThumb.y / Math.max(1, (customScrollBar.height - scrollThumb.height));
                                            songListView.contentY = ratio * (songListView.contentHeight - songListView.height);
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
    // 5. Atajos de Teclado y Cierre con Super + Q
    // ==========================================
    focus: root.isOpen

    Keys.onPressed: (event) => {
        // Super + R: detiene la reproducción de música por completo y cierra el reproductor
        if (event.key === Qt.Key_R && (event.modifiers & Qt.MetaModifier)) {
            root.stopAndClose();
            event.accepted = true;
            return;
        }
        if (((event.key === Qt.Key_Q) && (event.modifiers & Qt.MetaModifier)) || event.key === Qt.Key_Escape) {
            if (searchField.activeFocus && event.key === Qt.Key_Escape) {
                searchField.focus = false;
                root.forceActiveFocus();
            } else {
                root.closeRequested();
            }
            event.accepted = true;
            return;
        }
        // Si el usuario está escribiendo en el buscador, no interceptar Espacio, números ni flechas
        if (searchField.activeFocus) {
            return;
        }
        if (event.key === Qt.Key_Space) {
            root.togglePlay();
            event.accepted = true;
        } else if (event.key === Qt.Key_1) {
            root.playSong(0);
            event.accepted = true;
        } else if (event.key === Qt.Key_2) {
            root.playSong(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_3) {
            root.playSong(2);
            event.accepted = true;
        } else if (event.key === Qt.Key_4) {
            root.playSong(3);
            event.accepted = true;
        } else if (event.key === Qt.Key_5) {
            root.playSong(4);
            event.accepted = true;
        } else if (event.key === Qt.Key_6) {
            root.playSong(5);
            event.accepted = true;
        } else if (event.key === Qt.Key_9) {
            root.setVolume(root.volumePercent - 5);
            event.accepted = true;
        } else if (event.key === Qt.Key_0) {
            root.setVolume(root.volumePercent + 5);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.seekRelative(-5);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.seekRelative(5);
            event.accepted = true;
        }
    }
}
