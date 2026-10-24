import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * HyperUtilityDeck.qml
 * Barra Superior Modular "Hyper-Utility Glass Deck"
 * Distribución:
 * - Pod Izquierdo: Workspaces 1..6 + Herramientas Dev de 1 toque (Terminal, Zed, Cafeína, Captura)
 * - Pod Central: Aura Music Island + Sub-cápsula OSD de Volumen/Brillo
 * - Pod Derecho: Tacómetros Circulares HUD (CPU, RAM, Batería) + Reloj/Fecha + Red/Audio
 */
Item {
    id: root

    property var theme
    signal toggleControlCenterRequested()
    signal toggleMusicPlayerRequested()

    // Control de OSD
    property bool osdActive: false
    property string osdMode: "volume"
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
        root.osdActive = true;
        subLeftIcon.requestPaint();
        osdHideTimer.restart();
    }

    // Exposición de elementos para Máscara de Clic y Blur en Wayland
    readonly property Item leftPodCard: devPod.podCard
    readonly property Item centerPodCard: mediaPod.podCard
    readonly property Item rightPodCard: telemPod.podCard
    readonly property Item subCapsuleCard: subCapsule

    implicitHeight: 76
    anchors.fill: parent

    // ==========================================
    // 1. Pod Izquierdo (Workspaces & Dev Tools)
    // ==========================================
    DevDeckPod {
        id: devPod
        theme: root.theme
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 4
    }

    // ==========================================
    // 2. Pod Central (Aura Media & Dynamic Pill)
    // ==========================================
    MediaPod {
        id: mediaPod
        theme: root.theme
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 4
        onToggleMusicPlayerRequested: root.toggleMusicPlayerRequested()
    }

    // ==========================================
    // 3. Pod Derecho (Telemetry & Mission Control)
    // ==========================================
    TelemetryPod {
        id: telemPod
        theme: root.theme
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 4
        onOpenControlCenterRequested: root.toggleControlCenterRequested()
    }

    // ==========================================
    // 4. Sub-Cápsula Flotante OSD (Volumen / Brillo)
    // Aparece debajo del Pod Central
    // ==========================================
    Rectangle {
        id: subCapsule
        anchors.horizontalCenter: mediaPod.horizontalCenter
        anchors.top: mediaPod.bottom
        anchors.topMargin: root.subIslandOpen ? 6 : -height

        width: root.subIslandOpen ? 286 : 140
        height: root.subIslandOpen ? 32 : 0
        radius: 16
        opacity: root.subIslandOpen ? 1.0 : 0.0
        visible: height > 0
        clip: true

        color: root.theme ? root.theme.backgroundSolid : "#ee0d1117"
        border.width: 1.2
        border.color: root.osdMode === "brightness"
                      ? (root.theme ? root.theme.accentAlt : "#bd93f9")
                      : (root.theme ? root.theme.accent : "#00ffcc")

        Behavior on anchors.topMargin { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

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
            onClicked: root.osdActive = false
            onWheel: (wheel) => {
                var step = wheel.angleDelta.y > 0 ? 5 : -5;
                var nextVal = Math.max(0, Math.min(100, root.osdValue + step));
                root.showOsd("volume", nextVal, false);
                subVolProc.running = false;
                subVolProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_sliders.sh", "set_volume", nextVal.toString()];
                subVolProc.running = true;
            }
        }

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
                    }
                }
            }

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

                        Behavior on height { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.osdActive
                      ? (root.osdMuted ? "MUTE" : (root.osdValue + "%"))
                      : "65%"
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
