import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * DevDeckPod.qml - Pod Izquierdo del Hyper-Utility Glass Deck
 * Contiene:
 * 1. Indicadores de Workspaces Hyprland reactivos (1 a 6) con estado activo/ocupado.
 * 2. Separador translúcido neón.
 * 3. Herramientas Dev de 1 toque:
 *    - Terminal (Kitty)
 *    - Editor (Zed con App Móvil)
 *    - Keep-Awake (Cafeína / No suspender) con estado visual reactivo
 *    - Capturador de Pantalla (Región / Grim + Slurp)
 */
Item {
    id: root

    property var theme
    readonly property Item podCard: card

    implicitHeight: card.height
    implicitWidth: card.width

    // Workspaces 1 a 8 con iconografía Cyberpunk / Nerd Font
    readonly property var wsData: [
        { id: 1, icon: "" },  // Arch / Base
        { id: 2, icon: "󰖟" },  // Web
        { id: 3, icon: "" },  // Code / Zed
        { id: 4, icon: "󰭹" },  // Chat / Discord
        { id: 5, icon: "󰝚" },  // Music
        { id: 6, icon: "󰉋" },  // Files
        { id: 7, icon: "󰘚" },  // Labs
        { id: 8, icon: "󰒓" }   // Settings
    ]

    // Proceso para Keep-Awake
    property bool keepAwakeActive: false

    Process {
        id: keepAwakeProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/keep_awake.sh", "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.keepAwakeActive = !!data.active;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!keepAwakeProc.running) {
                keepAwakeProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/keep_awake.sh", "status"];
                keepAwakeProc.running = true;
            }
        }
    }

    Process {
        id: actionProc
        command: []
        running: false
    }

    function launchCommand(cmd) {
        actionProc.command = ["bash", "-c", cmd];
        actionProc.running = true;
    }

    // ==========================================
    // Cápsula Visual Frosted Glass
    // ==========================================
    Rectangle {
        id: card
        height: 32
        width: rowLayout.implicitWidth + 24
        radius: 16

        // Fondo de cristal esmerilado con profundidad
        color: root.theme ? root.theme.background : Qt.rgba(0.05, 0.07, 0.09, 0.75)
        border.width: 1.2
        border.color: podMouse.containsMouse
                      ? (root.theme ? root.theme.accent : "#00ffcc")
                      : (root.theme ? root.theme.border : Qt.rgba(0, 1, 0.8, 0.28))

        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }

        // Resplandor exterior neón suave
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.width: 1
            border.color: root.theme ? root.theme.accentGlow : Qt.rgba(0, 1, 0.8, 0.20)
            opacity: podMouse.containsMouse ? 1.0 : 0.4
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        MouseArea {
            id: podMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
        }

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 8

            // ----------------------------------------------------
            // 1. Workspaces Interactivos (1 a 8 con Iconos Nerd Font)
            // ----------------------------------------------------
            Row {
                id: wsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: root.wsData

                    delegate: Rectangle {
                        id: wsBtn
                        required property var modelData
                        property int wsId: modelData.id
                        property string wsIcon: modelData.icon

                        readonly property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
                        readonly property bool isOccupied: {
                            var wss = Hyprland.workspaces ? Hyprland.workspaces.values : [];
                            for (var i = 0; i < wss.length; i++) {
                                if (wss[i].id === wsId && (wss[i].toplevelCount > 0 || wss[i].windows > 0)) return true;
                            }
                            return false;
                        }

                        width: isFocused ? 24 : (wsBtnMouse.containsMouse ? 20 : (isOccupied ? 18 : 15))
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter

                        color: isFocused
                               ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.28) : Qt.rgba(0, 1, 0.8, 0.28))
                               : (wsBtnMouse.containsMouse ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.12)) : "transparent")

                        border.width: isFocused ? 1.2 : 0
                        border.color: root.theme ? root.theme.accent : "#00ffcc"

                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Text {
                            anchors.centerIn: parent
                            text: wsBtn.wsIcon
                            font.family: root.theme ? root.theme.fontMono : "monospace"
                            font.pixelSize: wsBtn.isFocused ? 13 : 11
                            color: wsBtn.isFocused
                                   ? (root.theme ? root.theme.accent : "#00ffcc")
                                   : (wsBtn.isOccupied
                                      ? (root.theme ? root.theme.text : "#f0f6fc")
                                      : (root.theme ? root.theme.textDim : "#8b949e"))
                            opacity: wsBtn.isFocused ? 1.0 : (wsBtn.isOccupied ? 0.95 : (wsBtnMouse.containsMouse ? 0.90 : 0.65))
                        }

                        // Pequeño punto neón debajo si está ocupado
                        Rectangle {
                            visible: wsBtn.isOccupied && !wsBtn.isFocused
                            width: 3
                            height: 3
                            radius: 1.5
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1.5
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: root.theme ? root.theme.accentAlt : "#bd93f9"
                        }

                        MouseArea {
                            id: wsBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch("workspace " + wsBtn.wsId)
                        }
                    }
                }
            }

            // Separador Neón Translúcido
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.15)
            }

            // ----------------------------------------------------
            // 2. Herramientas Dev de 1 Toque (Iconografía Vectorial Nerd Font)
            // ----------------------------------------------------
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                // [  ] Terminal Kitty
                Rectangle {
                    width: 22
                    height: 22
                    radius: 7
                    color: termMouse.containsMouse ? Qt.rgba(0, 1, 0.8, 0.22) : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05))
                    border.width: termMouse.containsMouse ? 1 : 0
                    border.color: root.theme ? root.theme.accent : "#00ffcc"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 11
                        color: termMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.text : "#f0f6fc")
                    }

                    MouseArea {
                        id: termMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchCommand("kitty &")
                    }
                }

                // [ 󰨞 ] Editor Zed (Proyecto App Móvil)
                Rectangle {
                    width: 22
                    height: 22
                    radius: 7
                    color: zedMouse.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.24) : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05))
                    border.width: zedMouse.containsMouse ? 1 : 0
                    border.color: root.theme ? root.theme.accentAlt : "#bd93f9"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰨞"
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 12
                        color: zedMouse.containsMouse ? (root.theme ? root.theme.accentAlt : "#bd93f9") : (root.theme ? root.theme.text : "#f0f6fc")
                    }

                    MouseArea {
                        id: zedMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchCommand("zeditor \"$HOME/Documentos/APP MOVIL\" || zeditor &")
                    }
                }

                // [ 󰅶 ] Keep-Awake (Cafeína)
                Rectangle {
                    width: 22
                    height: 22
                    radius: 7
                    color: root.keepAwakeActive
                           ? Qt.rgba(1.0, 0.72, 0.42, 0.30)
                           : (coffeeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05)))
                    border.width: root.keepAwakeActive ? 1.2 : (coffeeMouse.containsMouse ? 1 : 0)
                    border.color: root.keepAwakeActive
                                  ? (root.theme ? root.theme.warning : "#ffb86c")
                                  : Qt.rgba(1, 1, 1, 0.2)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: root.keepAwakeActive ? "󰅶" : "󰒲"
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 11
                        color: root.keepAwakeActive
                               ? (root.theme ? root.theme.warning : "#ffb86c")
                               : (coffeeMouse.containsMouse ? (root.theme ? root.theme.text : "#f0f6fc") : (root.theme ? root.theme.textDim : "#6e7681"))
                    }

                    MouseArea {
                        id: coffeeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.launchCommand(Quickshell.env("HOME") + "/.config/quickshell/scripts/keep_awake.sh toggle &");
                            root.keepAwakeActive = !root.keepAwakeActive;
                        }
                    }
                }

                // [ 󰄀 ] Capturador de Pantalla (Región)
                Rectangle {
                    width: 22
                    height: 22
                    radius: 7
                    color: shotMouse.containsMouse ? Qt.rgba(0.31, 0.98, 0.48, 0.24) : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05))
                    border.width: shotMouse.containsMouse ? 1 : 0
                    border.color: root.theme ? root.theme.cpuColor : "#50fa7b"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰄀"
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 11
                        color: shotMouse.containsMouse ? (root.theme ? root.theme.cpuColor : "#50fa7b") : (root.theme ? root.theme.text : "#f0f6fc")
                    }

                    MouseArea {
                        id: shotMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchCommand(Quickshell.env("HOME") + "/.config/quickshell/scripts/screenshot.sh region &")
                    }
                }
            }
        }
    }
}
