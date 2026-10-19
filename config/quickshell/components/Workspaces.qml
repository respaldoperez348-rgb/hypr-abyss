import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * Workspaces.qml
 * Indicadores minimalistas estilo Pacman / Cyberpunk para Hyprland.
 * - Renderizado vectorial nítido de Pacman (ᗧ) inmune a fuentes faltantes y escalado 1.5x.
 * - Aparece Pacman 'ᗧ' únicamente en los espacios de trabajo que tienen aplicaciones abiertas.
 * - Los espacios vacíos muestran un punto '·' sutil y limpio.
 * - El espacio activo se ilumina con acento neón y resplandor.
 */
Item {
    id: root

    property var theme
    property string activeAppRaw: "Desktop"

    implicitHeight: 22
    implicitWidth: mainRow.implicitWidth

    readonly property var baseWorkspaces: [1, 2, 3, 4, 5]

    function formatAppName(raw) {
        if (!raw || raw.trim().length === 0) return "Desktop";
        var lower = raw.toLowerCase().trim();
        if (lower.indexOf("zen") !== -1) return "Zen Browser";
        if (lower.indexOf("firefox") !== -1) return "Firefox";
        if (lower.indexOf("brave") !== -1) return "Brave";
        if (lower.indexOf("chrom") !== -1) return "Chrome";
        if (lower.indexOf("kitty") !== -1) return "Kitty";
        if (lower.indexOf("alacritty") !== -1) return "Alacritty";
        if (lower.indexOf("wezterm") !== -1) return "WezTerm";
        if (lower.indexOf("code") !== -1 || lower.indexOf("vscodium") !== -1) return "VS Code";
        if (lower.indexOf("agy") !== -1 || lower.indexOf("antigravity") !== -1) return "Antigravity";
        if (lower.indexOf("discord") !== -1 || lower.indexOf("vesktop") !== -1) return "Discord";
        if (lower.indexOf("telegram") !== -1) return "Telegram";
        if (lower.indexOf("spotify") !== -1) return "Spotify";
        if (lower.indexOf("thunar") !== -1 || lower.indexOf("nautilus") !== -1 || lower.indexOf("dolphin") !== -1) return "Files";
        if (lower.indexOf("obs") !== -1) return "OBS Studio";
        if (lower.indexOf("mpv") !== -1) return "MPV Media";
        // Capitalizar primera letra
        var parts = raw.split(".");
        var last = parts[parts.length - 1];
        return last.charAt(0).toUpperCase() + last.slice(1);
    }

    readonly property string activeAppLabel: formatAppName(activeAppRaw)

    // Escucha eventos IPC en tiempo real de Hyprland (cambio de ventana en 0ms)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event) return;
            if (event.name === "activewindow") {
                var d = event.data || "";
                var commaIdx = d.indexOf(",");
                var cls = commaIdx !== -1 ? d.substring(0, commaIdx) : d;
                root.activeAppRaw = cls.length > 0 ? cls : "Desktop";
            } else if (event.name === "workspace" || event.name === "focusedmon") {
                if (!root.hasApp(Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)) {
                    root.activeAppRaw = "Desktop";
                }
            }
        }
    }

    function getWorkspace(wsId) {
        if (!Hyprland.workspaces || !Hyprland.workspaces.values) return null;
        var list = Hyprland.workspaces.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === wsId) {
                return list[i];
            }
        }
        return null;
    }

    function hasApp(wsId) {
        var ws = getWorkspace(wsId);
        if (!ws) return false;
        if (ws.windows !== undefined) {
            return ws.windows > 0;
        }
        return true;
    }

    function isFocused(wsId) {
        return Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId;
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onWheel: function(wheel) {
            if (wheel.angleDelta.y > 0) {
                Hyprland.dispatch("workspace e-1");
            } else if (wheel.angleDelta.y < 0) {
                Hyprland.dispatch("workspace e+1");
            }
        }
    }

    Row {
        id: mainRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Row {
            id: wsRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: root.baseWorkspaces

                delegate: Item {
                    id: wsItem
                    readonly property int wsId: modelData
                    readonly property bool focused: root.isFocused(wsId)
                    readonly property bool appOpen: root.hasApp(wsId)
                    readonly property bool hovered: dotMouse.containsMouse

                    width: appOpen ? 16 : (focused ? 10 : 6)
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter

                    onFocusedChanged: {
                        if (focused && appOpen) {
                            chompAnim.restart();
                        }
                    }

                    onHoveredChanged: {
                        if (hovered && appOpen && !chompAnim.running) {
                            chompAnim.restart();
                        }
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: root.theme ? root.theme.animDurationFast : 160
                            easing.type: Easing.OutQuad
                        }
                    }

                    // ==========================================
                    // Pacman Vectorial ᗧ Animado (App Abierta)
                    // ==========================================
                    Canvas {
                        id: pacman
                        anchors.centerIn: parent
                        visible: wsItem.appOpen
                        width: 14
                        height: 14
                        antialiasing: true

                        property real mouthAngle: 0.22
                        property color pacColor: {
                            if (wsItem.focused) {
                                return root.theme ? root.theme.accent : "#00ffcc";
                            }
                            if (wsItem.hovered) {
                                return root.theme ? root.theme.accentAlt : "#bd93f9";
                            }
                            return root.theme ? root.theme.text : "#f0f6fc";
                        }

                        onPacColorChanged: requestPaint()
                        onMouthAngleChanged: requestPaint()

                        SequentialAnimation on mouthAngle {
                            id: chompAnim
                            running: false
                            loops: 2
                            NumberAnimation { to: 0.03; duration: 85; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 0.24; duration: 85; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 0.22; duration: 50 }
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.fillStyle = pacColor;
                            ctx.beginPath();
                            // Dibuja el cuerpo de Pacman con ángulo de boca dinámico
                            ctx.arc(7, 7, 5.5, mouthAngle * Math.PI, (2.0 - mouthAngle) * Math.PI, false);
                            ctx.lineTo(7, 7);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }

                    // ==========================================
                    // Pac-Dot Minimalista '·' con Resplandor
                    // ==========================================
                    Rectangle {
                        anchors.centerIn: parent
                        visible: !wsItem.appOpen
                        width: wsItem.focused ? 6.5 : (wsItem.hovered ? 5 : 3.5)
                        height: width
                        radius: width / 2

                        color: {
                            if (wsItem.focused) {
                                return root.theme ? root.theme.accent : "#00ffcc";
                            }
                            if (wsItem.hovered) {
                                return root.theme ? root.theme.accentAlt : "#bd93f9";
                            }
                            return root.theme ? root.theme.textDim : "#6e7681";
                        }

                        opacity: wsItem.focused ? 1.0 : (wsItem.hovered ? 0.9 : 0.45)

                        Behavior on width {
                            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }
                    }

                    // Área de clic
                    MouseArea {
                        id: dotMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            Hyprland.dispatch("workspace " + wsItem.wsId);
                        }
                    }
                }
            }
        }

        // ==========================================
        // Chip de Ventana Activa (Ej. Zen Browser)
        // ==========================================
        Rectangle {
            id: activeAppPill
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            width: appRow.implicitWidth + 12
            radius: 10
            color: root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.08)

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }

            Row {
                id: appRow
                anchors.centerIn: parent
                spacing: 5

                // Punto indicador con gradiente/color de acento
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    radius: 2.5
                    color: root.activeAppLabel === "Desktop"
                           ? (root.theme ? root.theme.textDim : "#6e7681")
                           : (root.theme ? root.theme.accentAlt : "#bd93f9")
                }

                Text {
                    id: appText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.activeAppLabel
                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                    font.pixelSize: 9
                    font.bold: true
                    color: root.activeAppLabel === "Desktop"
                           ? (root.theme ? root.theme.textDim : "#8b949e")
                           : (root.theme ? root.theme.text : "#f0f6fc")
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 95)
                }
            }
        }
    }
}
