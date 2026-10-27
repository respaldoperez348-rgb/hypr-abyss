//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "components"

/**
 * shell.qml
 * Punto de entrada principal para Quickshell.
 * - Dynamic Island centrada en la parte superior (se oculta automáticamente en pantalla completa Super + F).
 * - Selector de Fondos de Pantalla flotante inferior (Super + V).
 * - Centro de Control y Notificaciones Lateral Derecho (Super + N / Clic en Reloj).
 * - Soporte multi-monitor independiente mediante Variants dedicados.
 */
ShellRoot {
    id: root

    // Gestor global de tema sincronizado con Pywal
    Theme {
        id: globalTheme
    }

    // Control de apertura del selector de fondos (Super + V)
    property bool wallpaperOpen: false

    // Control de apertura del Centro de Control y Notificaciones (Super + N)
    property bool controlCenterOpen: false

    // Control de apertura del Menú de Energía y Apagado (Super + P)
    property bool powerMenuOpen: false

    // Control Notch (Barra 3: Pocket Island)
    property bool notchExpanded: false
    property string notchActiveTab: "media"

    // Gestor de Exclusividad Mutua: Solo un popup / panel puede estar abierto a la vez
    function closeAllPopupsExcept(keep: string): void {
        if (keep !== "wallpaper") root.wallpaperOpen = false;
        if (keep !== "controlcenter") root.controlCenterOpen = false;
        if (keep !== "powermenu") root.powerMenuOpen = false;
        if (keep !== "notch") root.notchExpanded = false;
        if (keep !== "projects") root.projectHubOpen = false;
        if (keep !== "clipboard") root.clipboardOpen = false;
        if (keep !== "musicplayer") root.musicPlayerOpen = false;
        if (keep !== "scratchpad") root.scratchpadOpen = false;
    }

    onWallpaperOpenChanged: {
        if (root.wallpaperOpen) root.closeAllPopupsExcept("wallpaper");
    }

    onControlCenterOpenChanged: {
        if (root.controlCenterOpen) {
            root.closeAllPopupsExcept("controlcenter");
        } else {
            root.edgeCooldown = true;
            edgeCooldownTimer.restart();
        }
    }

    onPowerMenuOpenChanged: {
        if (root.powerMenuOpen) root.closeAllPopupsExcept("powermenu");
    }

    onNotchExpandedChanged: {
        if (root.notchExpanded) root.closeAllPopupsExcept("notch");
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            if (root.wallpaperOpen) {
                root.wallpaperOpen = false;
            } else {
                root.closeAllPopupsExcept("wallpaper");
                root.wallpaperOpen = true;
            }
        }
        function open(): void {
            root.closeAllPopupsExcept("wallpaper");
            root.wallpaperOpen = true;
        }
        function close(): void {
            root.wallpaperOpen = false;
        }
    }

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            if (root.controlCenterOpen) {
                root.controlCenterOpen = false;
            } else {
                root.closeAllPopupsExcept("controlcenter");
                root.controlCenterOpen = true;
            }
        }
        function open(): void {
            root.closeAllPopupsExcept("controlcenter");
            root.controlCenterOpen = true;
        }
        function close(): void {
            root.controlCenterOpen = false;
        }
        function calendar(): void {
            root.closeAllPopupsExcept("controlcenter");
            root.controlCenterOpen = true;
            root.openControlCenterSection("calendar");
        }
        function section(sec: string): void {
            root.closeAllPopupsExcept("controlcenter");
            root.controlCenterOpen = true;
            root.openControlCenterSection(sec);
        }
    }

    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            if (root.powerMenuOpen) {
                root.powerMenuOpen = false;
            } else {
                root.closeAllPopupsExcept("powermenu");
                root.powerMenuOpen = true;
            }
        }
        function open(): void {
            root.closeAllPopupsExcept("powermenu");
            root.powerMenuOpen = true;
        }
        function close(): void {
            root.powerMenuOpen = false;
        }
    }

    IpcHandler {
        target: "notch"

        function toggle(): void {
            if (root.powerMenuOpen || root.wallpaperOpen || root.controlCenterOpen || root.projectHubOpen || root.clipboardOpen) {
                root.closeAllPopupsExcept("notch");
                root.notchExpanded = true;
            } else {
                root.notchExpanded = !root.notchExpanded;
                if (root.notchExpanded) root.closeAllPopupsExcept("notch");
            }
        }
        function expand(): void {
            root.closeAllPopupsExcept("notch");
            root.notchExpanded = true;
        }
        function collapse(): void {
            root.notchExpanded = false;
        }
        function setTab(tab: string): void {
            root.closeAllPopupsExcept("notch");
            root.notchActiveTab = tab;
            root.notchExpanded = true;
        }
    }

    // Control de apertura del Selector de Proyectos (Super + O)
    property bool projectHubOpen: false
    signal openProjectHubConfigs()

    IpcHandler {
        target: "projects"

        function toggle(): void {
            root.projectHubOpen = !root.projectHubOpen;
        }
        function open(): void {
            root.projectHubOpen = true;
        }
        function close(): void {
            root.projectHubOpen = false;
        }
        function configs(): void {
            root.projectHubOpen = true;
            root.openProjectHubConfigs();
        }
    }

    // Control de apertura del Historial de Portapapeles (Super + H)
    property bool clipboardOpen: false

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.clipboardOpen = !root.clipboardOpen;
        }
        function open(): void {
            root.clipboardOpen = true;
        }
        function close(): void {
            root.clipboardOpen = false;
        }
    }

    // Control de apertura del Scratchpad / Bloc de Notas (Super + S)
    property bool scratchpadOpen: false

    IpcHandler {
        target: "scratchpad"

        function toggle(): void {
            root.scratchpadOpen = !root.scratchpadOpen;
        }
        function open(): void {
            root.scratchpadOpen = true;
        }
        function close(): void {
            root.scratchpadOpen = false;
        }
    }

    // Control de apertura del Reproductor de Música Aura Music (Super + Y)
    property bool musicPlayerOpen: false

    IpcHandler {
        target: "musicplayer"

        function toggle(): void {
            root.musicPlayerOpen = !root.musicPlayerOpen;
        }
        function open(): void {
            root.musicPlayerOpen = true;
        }
        function close(): void {
            root.musicPlayerOpen = false;
        }
        function autoNext(): void {
            if (musicPlayerContainer) musicPlayerContainer.autoNext();
        }
        function next(): void {
            if (musicPlayerContainer) musicPlayerContainer.playNextSong(true);
        }
        function prev(): void {
            if (musicPlayerContainer) musicPlayerContainer.playPreviousSong(true);
        }
        function togglePlay(): void {
            if (musicPlayerContainer) musicPlayerContainer.togglePlay();
        }
    }

    // Control de visibilidad del Reloj de Escritorio (Desktop Clock)
    property bool desktopClockVisible: true

    IpcHandler {
        target: "clock"

        function toggle(): void {
            root.desktopClockVisible = !root.desktopClockVisible;
        }
        function open(): void {
            root.desktopClockVisible = true;
        }
        function close(): void {
            root.desktopClockVisible = false;
        }
    }

    // Control de Setup Global: "deck" (Programación / Dev) o "island" (Diario / Casual)
    property string barStyle: "deck"

    function toggleBarStyle(): void {
        var styles = ["deck", "island", "notch"];
        var idx = styles.indexOf(root.barStyle);
        if (idx === -1) idx = 0;
        var nextStyle = styles[(idx + 1) % styles.length];
        root.setBarStyle(nextStyle);
    }

    function setBarStyle(style: string): void {
        if (root.barStyle === style) return;
        root.barStyle = style;
        var modeMap = {
            "deck": "dev",
            "island": "daily",
            "notch": "pocket"
        };
        var mode = modeMap[style] || "dev";
        root.setSetupMode(mode);
    }

    function setSetupMode(mode: string): void {
        var styleMap = {
            "dev": "deck",
            "daily": "island",
            "pocket": "notch"
        };
        var targetStyle = styleMap[mode] || "deck";
        root.barStyle = targetStyle;
        saveBarProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/setup_manager.py", "switch", mode, "--from-quickshell"];
        saveBarProc.running = false;
        saveBarProc.running = true;
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.toggleBarStyle();
        }
        function set(style: string): void {
            if (root.barStyle !== style) {
                root.setBarStyle(style);
            }
        }
    }

    IpcHandler {
        target: "setup"

        function toggle(): void {
            var modes = ["dev", "daily", "pocket"];
            var styleToMode = { "deck": "dev", "island": "daily", "notch": "pocket" };
            var curr = styleToMode[root.barStyle] || "dev";
            var idx = modes.indexOf(curr);
            var nextMode = modes[(idx + 1) % modes.length];
            root.setSetupMode(nextMode);
        }
        function set(mode: string): void {
            root.setSetupMode(mode);
        }
    }

    Process {
        id: loadBarConfigProc
        command: ["cat", Quickshell.env("HOME") + "/.config/quickshell/bar_config.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    if (data.style === "deck" || data.style === "island" || data.style === "notch") {
                        root.barStyle = data.style;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: saveBarProc
        command: []
        running: false
    }

    Process {
        id: rofiLauncherProc
        command: ["bash", "-c", "pkill rofi || rofi -show drun -show-icons"]
        running: false
    }

    IpcHandler {
        target: "appmenu"

        function toggle(): void {
            rofiLauncherProc.running = false;
            rofiLauncherProc.running = true;
        }
    }

    // Señal e IPC para disparar el OSD de Volumen/Brillo en la Dynamic Island al instante
    signal osdRequested(string mode, int val, bool muted)
    signal openControlCenterSection(string section)

    IpcHandler {
        target: "osd"

        function trigger(mode: string, val: string, muted: string): void {
            var numVal = parseInt(val);
            if (isNaN(numVal)) numVal = 0;
            root.osdRequested(mode, numVal, muted === "true");
        }
    }

    // ==========================================
    // 1. Barra Flotante Superior (Dynamic Island 2.0 + Sub-Cápsula OSD)
    // ==========================================
    Variants {
        id: topBarVariants
        model: Quickshell.screens

        PanelWindow {
            id: topPanel
            property var modelData
            screen: modelData

            // Detección reactiva de ventana en pantalla completa en el workspace enfocado
            readonly property bool isFullscreen: {
                if (!Hyprland.focusedWorkspace) return false;
                return Hyprland.focusedWorkspace.hasFullscreen;
            }

            // Anclaje al borde superior de la pantalla
            anchors {
                top: true
                left: true
                right: true
            }

            // Se oculta automáticamente y libera el espacio exclusivo en pantalla completa
            // implicitHeight de 76px permite mostrar la sub-cápsula OSD con fondo 100% transparente alrededor
            visible: !isFullscreen
            implicitHeight: isFullscreen ? 0 : 250
            exclusiveZone: isFullscreen ? 0 : (root.barStyle === "notch" ? 44 : 34)

            // Capa superior en Wayland
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Fondo 100% transparente para lograr el efecto flotante
            color: "transparent"

            // MÁSCARA DE CLIC DINÁMICA (Deck Modular, Dynamic Island o Notch)
            mask: Region {
                // Modo Deck
                Region { item: (topPanel.isFullscreen || root.barStyle !== "deck") ? null : deck.leftPodCard }
                Region { item: (topPanel.isFullscreen || root.barStyle !== "deck") ? null : deck.centerPodCard }
                Region { item: (topPanel.isFullscreen || root.barStyle !== "deck") ? null : deck.rightPodCard }
                Region { item: (topPanel.isFullscreen || root.barStyle !== "deck" || !deck.subIslandOpen) ? null : deck.subCapsuleCard }

                // Modo Island
                Region { item: (topPanel.isFullscreen || root.barStyle !== "island") ? null : island.mainCapsule }
                Region { item: (topPanel.isFullscreen || root.barStyle !== "island" || !island.subIslandOpen) ? null : island.subCapsuleItem }

                // Modo Notch (Pocket)
                Region { item: (topPanel.isFullscreen || root.barStyle !== "notch") ? null : notch.notchCard }
            }

            // Efecto de desenfoque de fondo Wayland nativo
            BackgroundEffect.blurRegion: Region {
                // Modo Deck
                Region { item: (topPanel.isFullscreen || root.barStyle !== "deck") ? null : deck.leftPodCard }
                Region { item: (topPanel.isFullscreen || root.barStyle !== "deck") ? null : deck.centerPodCard }
                Region { item: (topPanel.isFullscreen || root.barStyle !== "deck") ? null : deck.rightPodCard }
                Region { item: (topPanel.isFullscreen || root.barStyle !== "deck" || !deck.subIslandOpen) ? null : deck.subCapsuleCard }

                // Modo Island
                Region { item: (topPanel.isFullscreen || root.barStyle !== "island") ? null : island.mainCapsule }
                Region { item: (topPanel.isFullscreen || root.barStyle !== "island" || !island.subIslandOpen) ? null : island.subCapsuleItem }

                // Modo Notch (Pocket)
                Region { item: (topPanel.isFullscreen || root.barStyle !== "notch") ? null : notch.notchCard }
            }

            Connections {
                target: root
                function onOsdRequested(mode, val, muted) {
                    if (root.barStyle === "deck") {
                        deck.showOsd(mode, val, muted);
                    } else if (root.barStyle === "island") {
                        island.showOsd(mode, val, muted);
                    } else if (root.barStyle === "notch") {
                        notch.showOsd(mode, val, muted);
                    }
                }
            }

            // Barra Estilo 1: Deck Superior Modular Tri-Pod
            HyperUtilityDeck {
                id: deck
                theme: globalTheme
                visible: root.barStyle === "deck"
                anchors.fill: parent

                onToggleControlCenterRequested: root.controlCenterOpen = !root.controlCenterOpen
                onOpenControlCenterSectionRequested: (sec) => {
                    root.controlCenterOpen = true;
                    root.openControlCenterSection(sec);
                }
                onToggleMusicPlayerRequested: root.musicPlayerOpen = !root.musicPlayerOpen
                onOpenProjectHubRequested: root.projectHubOpen = !root.projectHubOpen
            }

            // Barra Estilo 2: Cápsula Dynamic Island Flotante y Centrada
            DynamicIsland {
                id: island
                theme: globalTheme
                visible: root.barStyle === "island"

                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter

                onToggleControlCenterRequested: root.controlCenterOpen = !root.controlCenterOpen
                onToggleMusicPlayerRequested: root.musicPlayerOpen = !root.musicPlayerOpen
            }

            // Barra Estilo 3: Dynamic Island Notch estilo Pocket
            NotchIsland {
                id: notch
                theme: globalTheme
                visible: root.barStyle === "notch"

                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter

                expanded: root.notchExpanded
                activeTab: root.notchActiveTab
                onToggleExpandRequested: {
                    if (root.powerMenuOpen || root.wallpaperOpen || root.controlCenterOpen || root.projectHubOpen) {
                        root.closeAllPopupsExcept("notch");
                        root.notchExpanded = true;
                    } else {
                        root.notchExpanded = !root.notchExpanded;
                        if (root.notchExpanded) root.closeAllPopupsExcept("notch");
                    }
                }
                onCollapseRequested: root.notchExpanded = false
                onExpandRequested: {
                    root.closeAllPopupsExcept("notch");
                    root.notchExpanded = true;
                }
                onSetTabRequested: (tab) => {
                    root.notchActiveTab = tab;
                    root.notchExpanded = true;
                }
                onActiveTabChanged: {
                    if (root.notchActiveTab !== activeTab) root.notchActiveTab = activeTab;
                }

                onToggleControlCenterRequested: {
                    if (root.controlCenterOpen) {
                        root.controlCenterOpen = false;
                    } else {
                        root.closeAllPopupsExcept("controlcenter");
                        root.controlCenterOpen = true;
                    }
                }
                onToggleMusicPlayerRequested: {
                    if (root.musicPlayerOpen) {
                        root.musicPlayerOpen = false;
                    } else {
                        root.closeAllPopupsExcept("musicplayer");
                        root.musicPlayerOpen = true;
                    }
                }
                onOpenWallpaperSelectorRequested: {
                    root.closeAllPopupsExcept("wallpaper");
                    root.wallpaperOpen = true;
                }
                onOpenPowerMenuRequested: {
                    root.closeAllPopupsExcept("powermenu");
                    root.powerMenuOpen = true;
                }
                onOpenAppMenuRequested: {
                    root.closeAllPopupsExcept("");
                    rofiLauncherProc.running = false;
                    rofiLauncherProc.running = true;
                }
            }
        }
    }

    // ==========================================
    // 2. Selector de Fondos de Pantalla Flotante Inferior (Super + V)
    // ==========================================
    Variants {
        id: wallpaperVariants
        model: Quickshell.screens

        PanelWindow {
            id: wallpaperPanel
            property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            visible: root.wallpaperOpen

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.wallpaperOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            WallpaperSelector {
                id: selectorContainer
                theme: globalTheme
                isOpen: root.wallpaperOpen
                barStyle: root.barStyle
                anchors.fill: parent
                onCloseRequested: root.wallpaperOpen = false
            }
        }
    }

    // ==========================================
    // 3. Centro de Control & Notificaciones Lateral (Super + N / Clic Der en Reloj)
    // ==========================================
    Variants {
        id: controlCenterVariants
        model: Quickshell.screens

        PanelWindow {
            id: controlCenterPanel
            property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                right: true
            }

            implicitWidth: root.controlCenterOpen ? 300 : 0
            visible: implicitWidth > 0

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.controlCenterOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            color: "transparent"

            mask: Region {
                item: ccContainer
            }

            BackgroundEffect.blurRegion: Region {
                item: ccContainer
            }

            ControlCenter {
                id: ccContainer
                theme: globalTheme
                isOpen: root.controlCenterOpen
                barStyle: root.barStyle
                anchors.fill: parent
                onCloseRequested: root.controlCenterOpen = false
                onSetBarStyleRequested: (style) => root.setBarStyle(style)

                Connections {
                    target: root
                    function onOpenControlCenterSection(sec) {
                        ccContainer.focusSection(sec);
                    }
                }
            }
        }
    }

    // Cooldown para evitar que el trigger del borde reabra el panel inmediatamente al cerrarse
    property bool edgeCooldown: false

    Timer {
        id: edgeCooldownTimer
        interval: 900
        repeat: false
        onTriggered: root.edgeCooldown = false
    }

    // ==========================================
    // 4. Activador por Borde Derecho (Auto-reveal al pasar el ratón)
    // ==========================================
    Variants {
        id: edgeTriggerVariants
        model: Quickshell.screens

        PanelWindow {
            id: edgeTriggerPanel
            property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                right: true
            }

            implicitWidth: 3
            visible: !root.controlCenterOpen && !root.edgeCooldown

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            color: "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    if (!root.edgeCooldown) {
                        root.controlCenterOpen = true;
                    }
                }
            }
        }
    }

    // ==========================================
    // 5. Menú de Energía y Apagado Flotante (Super + P)
    // ==========================================
    Variants {
        id: powerMenuVariants
        model: Quickshell.screens

        PanelWindow {
            id: powerMenuPanel
            property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: root.powerMenuOpen

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.powerMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            color: "transparent"

            BackgroundEffect.blurRegion: Region {
                item: powerMenuContainer.card
            }

            PowerMenu {
                id: powerMenuContainer
                theme: globalTheme
                isOpen: root.powerMenuOpen
                barStyle: root.barStyle
                anchors.fill: parent
                onCloseRequested: root.powerMenuOpen = false
            }
        }
    }

    // ==========================================
    // 6. Reloj de Escritorio Retro Arrastrable (Desktop Clock Widget)
    // ==========================================
    Variants {
        id: desktopClockVariants
        model: Quickshell.screens

        PanelWindow {
            id: clockPanel
            property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: root.desktopClockVisible
            WlrLayershell.layer: desktopClock.layerOnTop ? WlrLayer.Top : WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: 0
            color: "transparent"

            mask: Region {
                item: desktopClock.hitboxItem
            }

            DesktopClock {
                id: desktopClock
                theme: globalTheme
                anchors.fill: parent
                screenWidth: clockPanel.width
                screenHeight: clockPanel.height
            }
        }
    }

    // ==========================================
    // 7. Reproductor de Música Aura Music Flotante (Super + Y)
    // ==========================================
    PanelWindow {
        id: musicPlayerPanel
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        visible: root.musicPlayerOpen

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.musicPlayerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        color: "transparent"

        mask: Region {
            item: musicPlayerContainer.card
        }

        BackgroundEffect.blurRegion: Region {
            item: musicPlayerContainer.card
        }

        MusicPlayer {
            id: musicPlayerContainer
            theme: globalTheme
            isOpen: root.musicPlayerOpen
            anchors.fill: parent
            onCloseRequested: root.musicPlayerOpen = false
        }
    }

    // ==========================================
    // 8. Selector y Gestor de Proyectos (Project Hub - Super + O)
    // ==========================================
    Variants {
        id: projectHubVariants
        model: Quickshell.screens

        PanelWindow {
            id: projectHubPanel
            property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: root.projectHubOpen

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.projectHubOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            color: "transparent"

            mask: Region {
                item: projectHubContainer.card
            }

            BackgroundEffect.blurRegion: Region {
                item: projectHubContainer.card
            }

            ProjectHub {
                id: projectHubContainer
                theme: globalTheme
                isOpen: root.projectHubOpen
                anchors.fill: parent
                onCloseRequested: root.projectHubOpen = false

                Connections {
                    target: root
                    function onOpenProjectHubConfigs() {
                        projectHubContainer.activeTab = "configs";
                    }
                }
            }
        }
    }

    // ==========================================
    // 9. Gestor de Portapapeles (Clipboard Glass - Super + H)
    // ==========================================
    Variants {
        id: clipboardVariants
        model: Quickshell.screens

        PanelWindow {
            id: clipboardPanel
            property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: root.clipboardOpen

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.clipboardOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            color: "transparent"

            mask: Region {
                item: clipboardContainer.card
            }

            BackgroundEffect.blurRegion: Region {
                item: clipboardContainer.card
            }

            ClipboardManager {
                id: clipboardContainer
                theme: globalTheme
                isOpen: root.clipboardOpen
                anchors.fill: parent
                onCloseRequested: root.clipboardOpen = false
            }
        }
    }

    // ==========================================
    // 10. Dev Scratchpad (Bloc de Notas Flotante - Super + S)
    // ==========================================
    Variants {
        id: scratchpadVariants
        model: Quickshell.screens

        PanelWindow {
            id: scratchpadPanel
            property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: root.scratchpadOpen

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.scratchpadOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            color: "transparent"

            mask: Region {
                item: scratchpadContainer.card
            }

            BackgroundEffect.blurRegion: Region {
                item: scratchpadContainer.card
            }

            DevScratchpad {
                id: scratchpadContainer
                theme: globalTheme
                isOpen: root.scratchpadOpen
                anchors.fill: parent
                onCloseRequested: root.scratchpadOpen = false
            }
        }
    }
}
