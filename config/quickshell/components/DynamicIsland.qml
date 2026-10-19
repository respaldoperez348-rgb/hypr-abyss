import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * DynamicIsland.qml
 * Cápsula flotante superior con estética Cyberpunk / Frosted Glass.
 * - Fondo semitransparente con desenfoque y esquinas redondeadas.
 * - Animación fluida de expansión y contracción horizontal (NumberAnimation, Easing.OutQuad).
 * - Módulos:
 *   1. Workspaces (Hyprland con ᗧ)
 *   2. Reproductor de Música MPRIS (expansible, con controles y ecualizador)
 *   3. Reloj Monospace
 *   4. System Tray (Apps en segundo plano como Zoom, Discord, Telegram)
 *   5. Hacker Stats (CPU, WiFi, Bluetooth, Batería)
 */
Item {
    id: root

    property var theme
    signal toggleControlCenterRequested()
    signal toggleMusicPlayerRequested()

    // Estado de la Sub-Cápsula OSD (Volumen / Brillo)
    property bool osdActive: false
    property string osdMode: "volume" // "volume" o "brightness"
    property int osdValue: 65
    property bool osdMuted: false

    readonly property bool subIslandOpen: osdActive

    Timer {
        id: osdHideTimer
        interval: 1800
        repeat: false
        onTriggered: root.osdActive = false
    }

    function showOsd(mode, val, muted) {
        root.osdMode = mode;
        root.osdValue = val;
        root.osdMuted = !!muted;
        if (mode === "volume") {
            statsModule.volume = val;
            statsModule.volMuted = !!muted;
        } else if (mode === "brightness") {
            statsModule.brightness = val;
        }
        root.osdActive = true;
        subLeftIcon.requestPaint();
        osdHideTimer.restart();
    }

    // Ancho y alto de la cápsula principal (sin caja extra alrededor)
    implicitHeight: capsule.height
    implicitWidth: capsule.width

    readonly property Item mainCapsule: capsule
    readonly property Item subCapsuleItem: subCapsule

    // ==========================================
    // 1. Cápsula Visual Principal (Superior)
    // ==========================================
    Rectangle {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        // Altura compacta (30px)
        height: root.theme ? root.theme.capsuleHeightCompact : 30
        width: contentLayout.implicitWidth + ((root.theme ? root.theme.capsulePaddingH : 10) * 2)
        radius: root.theme ? root.theme.capsuleRadius : 15

        // Fondo frosted glass semitransparente
        color: root.theme ? root.theme.background : "#cc0d1117"

        // Borde neón que brilla al pasar el ratón o reproducir música
        border.width: 1.2
        border.color: islandMouse.containsMouse 
                      ? (root.theme ? root.theme.borderHover : "#00ffcc")
                      : (mediaModule.isPlaying 
                         ? (root.theme ? root.theme.accentAlt : "#bd93f9")
                         : (root.theme ? root.theme.border : Qt.rgba(0, 1, 0.8, 0.35)))

        // Animación fluida de anchura al expandir/contraer módulos
        Behavior on width {
            NumberAnimation {
                duration: root.theme ? root.theme.animDurationNormal : 300
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }

        // Halo / Resplandor exterior estilo cyberpunk (Cian -> Púrpura)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1.5
            radius: parent.radius + 1.5
            color: "transparent"
            border.width: 1
            border.color: mediaModule.isPlaying
                          ? Qt.rgba(0.74, 0.58, 0.98, 0.32)
                          : (root.theme ? root.theme.accentGlow : Qt.rgba(0, 1, 0.8, 0.22))
            opacity: (islandMouse.containsMouse || mediaModule.isPlaying) ? 1.0 : 0.45

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        // Área interactiva de fondo de la cápsula
        MouseArea {
            id: islandMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
        }

        // ==========================================
        // Contenido Modular de la Isla
        // ==========================================
        Row {
            id: contentLayout
            anchors.centerIn: parent
            spacing: 8

            // 1. Módulo Workspaces (Hyprland con Pac-Man animado + Chip App Activa)
            Workspaces {
                id: wsModule
                theme: root.theme
                anchors.verticalCenter: parent.verticalCenter
            }

            // Separador 1 (Workspaces -> Siguiente)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 10
                color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.12)
            }

            // 2. Módulo de Música / Audio (Se expande si hay música y se oculta automáticamente)
            MediaIsland {
                id: mediaModule
                theme: root.theme
                anchors.verticalCenter: parent.verticalCenter
                onToggleMusicPlayerRequested: root.toggleMusicPlayerRequested()
            }

            // 3. Módulo Reloj y Fecha (Clic Izq: Fecha | Clic Der: Control Center)
            ClockWidget {
                id: clockModule
                theme: root.theme
                anchors.verticalCenter: parent.verticalCenter
                onToggleControlCenterRequested: root.toggleControlCenterRequested()
            }

            // 4. Módulo de Bandeja del Sistema (Apps en segundo plano: Zoom, Telegram, Discord, etc.)
            Row {
                id: trayRow
                visible: trayModule.hasItems
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    implicitWidth: 1
                    height: 10
                    color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.12)
                }

                TrayIsland {
                    id: trayModule
                    theme: root.theme
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Separador previo a HackerStats
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 10
                color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.12)
            }

            // 5. Módulo Hacker Stats (CPU, WiFi, Bluetooth, Batería)
            HackerStats {
                id: statsModule
                theme: root.theme
                anchors.verticalCenter: parent.verticalCenter
                onActiveAppChanged: {
                    if (wsModule.activeAppRaw === "Desktop" && statsModule.activeApp !== "Desktop") {
                        wsModule.activeAppRaw = statsModule.activeApp;
                    }
                }
                onOsdTriggered: (osdType, osdValue, osdMuted) => {
                    root.showOsd(osdType, osdValue, osdMuted);
                }
                onOpenControlCenterRequested: root.toggleControlCenterRequested()
            }
        }
    }

    // ==========================================
    // 2. Sub-Cápsula Flotante OSD & Espectro de Ondas
    // (Se despliega debajo de la isla principal como en el prototipo)
    // ==========================================
    Rectangle {
        id: subCapsule
        anchors.horizontalCenter: capsule.horizontalCenter
        anchors.top: capsule.bottom
        anchors.topMargin: root.subIslandOpen ? 5 : -height

        width: root.subIslandOpen ? 286 : 140
        height: root.subIslandOpen ? 32 : 0
        radius: 16
        opacity: root.subIslandOpen ? 1.0 : 0.0
        visible: height > 0
        clip: true

        color: "#ee0d1117"
        border.width: 1.2
        border.color: root.osdMode === "brightness"
                      ? (root.theme ? root.theme.accentAlt : "#bd93f9")
                      : (root.theme ? root.theme.accent : "#00ffcc")

        Behavior on anchors.topMargin {
            NumberAnimation { duration: 240; easing.type: Easing.OutBack }
        }
        Behavior on width {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
        }

        // Proceso rápido para ajustar volumen con rueda sobre la sub-cápsula
        Process {
            id: subVolProc
            command: []
            running: false
        }

        MouseArea {
            id: subMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.osdActive = false;
            }
            onWheel: (wheel) => {
                var step = wheel.angleDelta.y > 0 ? 5 : -5;
                var nextVal = Math.max(0, Math.min(100, (statsModule.volume >= 0 ? statsModule.volume : 65) + step));
                statsModule.volume = nextVal;
                root.showOsd("volume", nextVal, false);
                subVolProc.running = false;
                subVolProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_sliders.sh", "set_volume", nextVal.toString()];
                subVolProc.running = true;
            }
        }

        // Animador de fase para las barras de onda
        Timer {
            id: waveTimer
            interval: 120
            running: root.subIslandOpen
            repeat: true
            property int tick: 0
            onTriggered: tick = (tick + 1) % 100
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            // Icono izquierdo (Volumen / Brillo)
            Canvas {
                id: subLeftIcon
                width: 14
                height: 14
                Layout.alignment: Qt.AlignVCenter
                property string mode: root.osdMode
                property bool muted: root.osdMuted
                property color col: root.theme ? root.theme.accent : "#00ffcc"
                onModeChanged: requestPaint()
                onMutedChanged: requestPaint()
                onColChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = muted ? "#ff5555" : col;
                    ctx.fillStyle = muted ? "#ff5555" : col;
                    ctx.lineWidth = 1.4;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";

                    if (mode === "brightness") {
                        // Sol vectorial
                        ctx.beginPath();
                        ctx.arc(7, 7, 3, 0, Math.PI * 2);
                        ctx.stroke();
                        for (var a = 0; a < 8; a++) {
                            var ang = a * Math.PI / 4;
                            ctx.beginPath();
                            ctx.moveTo(7 + Math.cos(ang) * 4.6, 7 + Math.sin(ang) * 4.6);
                            ctx.lineTo(7 + Math.cos(ang) * 6.2, 7 + Math.sin(ang) * 6.2);
                            ctx.stroke();
                        }
                    } else if (mode === "volume") {
                        // Altavoz vectorial
                        ctx.beginPath();
                        ctx.moveTo(2, 5.2);
                        ctx.lineTo(4.8, 5.2);
                        ctx.lineTo(8, 2.5);
                        ctx.lineTo(8, 11.5);
                        ctx.lineTo(4.8, 8.8);
                        ctx.lineTo(2, 8.8);
                        ctx.closePath();
                        ctx.fill();
                        if (!muted) {
                            ctx.beginPath();
                            ctx.arc(8.5, 7, 2.5, -Math.PI * 0.35, Math.PI * 0.35);
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.arc(8.5, 7, 4.5, -Math.PI * 0.35, Math.PI * 0.35);
                            ctx.stroke();
                        } else {
                            ctx.beginPath();
                            ctx.moveTo(10, 5); ctx.lineTo(13, 9);
                            ctx.moveTo(13, 5); ctx.lineTo(10, 9);
                            ctx.stroke();
                        }
                    } else {
                        // Triángulo Play
                        ctx.beginPath();
                        ctx.moveTo(3, 2.5);
                        ctx.lineTo(11.5, 7);
                        ctx.lineTo(3, 11.5);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }

            // Onda / Espectro Central (22 barras con degradado Cian -> Púrpura)
            Row {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Repeater {
                    model: 22

                    delegate: Rectangle {
                        required property int index
                        readonly property real ratio: index / 21.0
                        readonly property int activeBars: root.osdActive
                            ? Math.round((root.osdMuted ? 0 : root.osdValue) / 100.0 * 22)
                            : 22
                        readonly property bool isLit: index < activeBars

                        // Perfil de onda senoidal simétrica como en el prototipo
                        readonly property real env: Math.sin(ratio * Math.PI)
                        readonly property real wave: Math.abs(Math.sin((index * 0.7) + (waveTimer.tick * 0.45)))

                        width: 2.5
                        height: root.osdActive
                                ? (isLit ? Math.max(4, Math.round(4 + env * 12)) : 3)
                                : Math.max(3, Math.round(3 + env * wave * 14))
                        radius: 1.25
                        anchors.verticalCenter: parent.verticalCenter

                        color: !isLit
                               ? Qt.rgba(1, 1, 1, 0.14)
                               : Qt.rgba(
                                   (1.0 - ratio) * (root.theme ? root.theme.accent.r : 0.0) + ratio * (root.theme ? root.theme.accentAlt.r : 0.74),
                                   (1.0 - ratio) * (root.theme ? root.theme.accent.g : 1.0) + ratio * (root.theme ? root.theme.accentAlt.g : 0.58),
                                   (1.0 - ratio) * (root.theme ? root.theme.accent.b : 0.8) + ratio * (root.theme ? root.theme.accentAlt.b : 0.98),
                                   0.95
                                 )

                        Behavior on height {
                            NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }

            // Etiqueta Derecha (Porcentaje OSD o Iconos de Audio/Brillo)
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.osdActive
                      ? (root.osdMuted ? "MUTE" : (root.osdValue + "%"))
                      : ((statsModule.volume >= 0 ? statsModule.volume : 65) + "%")
                font.family: root.theme ? root.theme.fontMono : "monospace"
                font.pixelSize: 10
                font.bold: true
                color: (root.osdActive && root.osdMuted)
                       ? "#ff5555"
                       : (root.theme ? root.theme.accentAlt : "#bd93f9")
            }
        }
    }
}
