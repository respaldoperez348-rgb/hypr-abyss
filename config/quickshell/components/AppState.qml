import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Global state
    property var currentTrack: null
    property bool isPlaying: false
    property real position: 0.0
    property real duration: 0.0
    property int volume: 80
    property var queue: []
    property var favorites: []
    property var searchResults: []
    property bool isSearching: false
    property bool isCurrentFavorite: false
    property bool shuffle: false
    property string repeatMode: "none" // "none", "one", "all"
    property string activeTab: "favorites" // "favorites", "queue", "search"

    // Reference to Quickshell process running python daemon
    property Process backendProc: Process {
        id: proc
        command: [
            "python3", "-u", "-c",
            "import os, sys; p1 = os.path.expanduser('~/Proyectos/AURA-MUSIC/core/service.py'); p2 = os.path.expanduser('~/.config/quickshell/core/service.py'); p = p1 if os.path.exists(p1) else p2; os.execv(sys.executable, [sys.executable, p])"
        ]
        stdinEnabled: true
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var msg = JSON.parse(data);
                    root.handleEvent(msg);
                } catch(e) {
                    console.log("[AppState] Parse error:", e, "raw:", data);
                }
            }
        }

        onExited: (code, status) => {
            console.log("[AppState] Backend daemon exited with code:", code);
        }
    }

    function sendCommand(cmdObj) {
        if (!proc.running) return;
        try {
            proc.write(JSON.stringify(cmdObj) + "\n");
        } catch(e) {
            console.log("[AppState] Send error:", e);
        }
    }

    function handleEvent(msg) {
        if (!msg || !msg.type) return;
        switch(msg.type) {
            case "init":
                if (msg.favorites) root.favorites = msg.favorites;
                if (msg.queue) root.queue = msg.queue;
                if (msg.currentTrack) root.currentTrack = msg.currentTrack;
                if (msg.volume !== undefined) root.volume = msg.volume;
                if (msg.shuffle !== undefined) root.shuffle = msg.shuffle;
                if (msg.repeat) root.repeatMode = msg.repeat;
                break;
            case "progress":
                root.position = msg.pos || 0.0;
                if (msg.duration) root.duration = msg.duration;
                break;
            case "duration":
                root.duration = msg.duration || 0.0;
                break;
            case "state":
                root.isPlaying = !!msg.playing;
                break;
            case "track":
                root.currentTrack = msg.track;
                root.position = 0.0;
                if (msg.track && msg.track.durationSec) root.duration = msg.track.durationSec;
                break;
            case "current_favorite_status":
                root.isCurrentFavorite = !!msg.isFavorite;
                break;
            case "queue":
                root.queue = msg.queue || [];
                break;
            case "favorites":
                root.favorites = msg.favorites || [];
                if (root.currentTrack) {
                    var tid = root.currentTrack.id || root.currentTrack.url;
                    root.isCurrentFavorite = root.favorites.some(function(t) {
                        return (t.id === tid || t.url === tid);
                    });
                }
                break;
            case "searching":
                root.isSearching = !!msg.isSearching;
                break;
            case "search_results":
                root.searchResults = msg.results || [];
                root.isSearching = false;
                root.activeTab = "search";
                break;
            case "volume":
                root.volume = msg.volume;
                break;
            case "shuffle":
                root.shuffle = msg.shuffle;
                break;
            case "repeat":
                root.repeatMode = msg.repeat;
                break;
        }
    }

    // Actions
    function playTrack(track) {
        sendCommand({ "cmd": "play_track", "track": track });
    }

    function playQueueIndex(idx) {
        sendCommand({ "cmd": "play_queue_index", "index": idx });
    }

    function togglePlay() {
        sendCommand({ "cmd": "toggle" });
    }

    function nextTrack() {
        sendCommand({ "cmd": "next" });
    }

    function prevTrack() {
        sendCommand({ "cmd": "prev" });
    }

    function seek(sec) {
        sendCommand({ "cmd": "seek", "pos": sec });
    }

    function setVolume(vol) {
        root.volume = vol;
        sendCommand({ "cmd": "set_volume", "volume": vol });
    }

    function toggleFavorite(track) {
        sendCommand({ "cmd": "toggle_favorite", "track": track || root.currentTrack });
    }

    function playAllFavorites() {
        sendCommand({ "cmd": "play_all_favorites" });
    }

    function toggleShuffle() {
        sendCommand({ "cmd": "set_shuffle", "shuffle": !root.shuffle });
    }

    function cycleRepeat() {
        var nextMode = "none";
        if (root.repeatMode === "none") nextMode = "all";
        else if (root.repeatMode === "all") nextMode = "one";
        sendCommand({ "cmd": "set_repeat", "repeat": nextMode });
    }

    function search(query) {
        if (!query || query.trim().length === 0) return;
        sendCommand({ "cmd": "search", "query": query.trim() });
    }

    function quit() {
        sendCommand({ "cmd": "quit" });
    }

    function formatTime(seconds) {
        if (!seconds || isNaN(seconds) || seconds < 0) return "00:00";
        var totalSec = Math.floor(seconds);
        var mins = Math.floor(totalSec / 60);
        var secs = totalSec % 60;
        return (mins < 10 ? "0" + mins : mins) + ":" + (secs < 10 ? "0" + secs : secs);
    }
}
