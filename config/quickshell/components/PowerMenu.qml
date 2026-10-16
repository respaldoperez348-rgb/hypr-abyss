import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * PowerMenu.qml
 * Menú de Energía y Apagado para el entorno Cyberpunk / Frosted Glass.
 * - Activado con Super + P vía Quickshell IPC.
 * - Acciones:
 *   1. Bloquear Pantalla (Lock) [1] [L]
 *   2. Cerrar Sesión (Logout) [2] [E]
 *   3. Reiniciar (Reboot) [3] [R]
 *   4. Apagar (Shutdown) [4] [P]
 *   5. Suspender (Suspend) [5] [S]
 * - Control completo por teclado (Esc, 1-5, Flechas, Enter).
 * - Clic exterior para cancelar y cerrar.
 * - Animaciones suaves de apertura/cierre y elevación física en hover.
 */
Item {
    id: root

    property var theme
    property bool isOpen: false
    signal closeRequested()
    property alias card: dialogCard

    // Estado del elemento enfocado por teclado (0 a 4)
    property int selectedIndex: 3 // Por defecto en Apagar o Bloquear
    // Acción pendiente de confirmación (-1 si ninguna)
    property int pendingConfirmIndex: -1

    // Proceso para ejecutar comandos del sistema
    Process {
        id: execProc
        command: []
        running: false
    }

    // Datos de las acciones del Power Menu
    readonly property var actions: [
        {
            id: "lock",
            title: "Lock Screen",
            subtitle: "Lock Screen",
            key: "1",
            altKey: "L",
            color: root.theme ? root.theme.accent : "#00ffcc",
            iconType: "lock",
            needsConfirm: false,
            command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/lock_screen.sh"]
        },
        {
            id: "logout",
            title: "Logout Session",
            subtitle: "Logout Session",
            key: "2",
            altKey: "E",
            color: root.theme ? root.theme.warning : "#ffb86c",
            iconType: "logout",
            needsConfirm: true,
            confirmText: "Log out of Hyprland?",
            command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/logout.sh"]
        },
        {
            id: "reboot",
            title: "Restart",
            subtitle: "Reboot System",
            key: "3",
            altKey: "R",
            color: root.theme ? root.theme.accentAlt : "#bd93f9",
            iconType: "reboot",
            needsConfirm: true,
            confirmText: "Reboot system now?",
            command: ["sh", "-c", "systemctl reboot 2>/dev/null || loginctl reboot 2>/dev/null || reboot"]
        },
        {
            id: "poweroff",
            title: "Shutdown",
            subtitle: "Power Off",
            key: "4",
            altKey: "P",
            color: root.theme ? root.theme.danger : "#ff5555",
            iconType: "power",
            needsConfirm: true,
            confirmText: "Shut down system?",
            command: ["sh", "-c", "systemctl poweroff 2>/dev/null || loginctl poweroff 2>/dev/null || poweroff"]
        },
        {
            id: "suspend",
            title: "Suspend",
            subtitle: "Suspend Mode",
            key: "5",
            altKey: "S",
            color: "#8be9fd",
            iconType: "suspend",
            needsConfirm: false,
            command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/suspend.sh"]
        }
    ]

    function executeAction(index) {
        if (index < 0 || index >= actions.length) return;
        var act = actions[index];

        if (act.needsConfirm && root.pendingConfirmIndex !== index) {
            // Requiere confirmación: mostrar advertencia visual
            root.pendingConfirmIndex = index;
            return;
        }

        // Ejecutar acción
        root.pendingConfirmIndex = -1;
        var cmd = act.command;
        root.closeRequested();

        execProc.command = cmd;
        execProc.running = true;
    }

    onIsOpenChanged: {
        if (isOpen) {
            root.pendingConfirmIndex = -1;
            keyFocusItem.forceActiveFocus();
        } else {
            root.pendingConfirmIndex = -1;
        }
    }

    // ==========================================
    // 1. Fondo Transparente (Capturador de clics exteriores)
    // ==========================================
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"

        // Clic en cualquier área vacía cierra el menú
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    // Capturador de foco de teclado para atajos inmediatos
    Item {
        id: keyFocusItem
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (root.pendingConfirmIndex !== -1) {
                root.pendingConfirmIndex = -1;
            } else {
                root.closeRequested();
            }
        }

        Keys.onLeftPressed: {
            root.pendingConfirmIndex = -1;
            root.selectedIndex = (root.selectedIndex - 1 + root.actions.length) % root.actions.length;
        }

        Keys.onRightPressed: {
            root.pendingConfirmIndex = -1;
            root.selectedIndex = (root.selectedIndex + 1) % root.actions.length;
        }

        Keys.onReturnPressed: {
            root.executeAction(root.selectedIndex);
        }

        Keys.onSpacePressed: {
            root.executeAction(root.selectedIndex);
        }

        // Atajos numéricos directos [1 - 5]
        Keys.onDigit1Pressed: { root.selectedIndex = 0; root.executeAction(0); }
        Keys.onDigit2Pressed: { root.selectedIndex = 1; root.executeAction(1); }
        Keys.onDigit3Pressed: { root.selectedIndex = 2; root.executeAction(2); }
        Keys.onDigit4Pressed: { root.selectedIndex = 3; root.executeAction(3); }
        Keys.onDigit5Pressed: { root.selectedIndex = 4; root.executeAction(4); }

        // Atajos alfabéticos directos [L, E, R, P, S]
        Keys.onPressed: (event) => {
            var k = event.text.toUpperCase();
            if (k === "L") { root.selectedIndex = 0; root.executeAction(0); event.accepted = true; }
            else if (k === "E") { root.selectedIndex = 1; root.executeAction(1); event.accepted = true; }
            else if (k === "R") { root.selectedIndex = 2; root.executeAction(2); event.accepted = true; }
            else if (k === "P" || k === "A") { root.selectedIndex = 3; root.executeAction(3); event.accepted = true; }
            else if (k === "S" || k === "U") { root.selectedIndex = 4; root.executeAction(4); event.accepted = true; }
        }
    }

    // ==========================================
    // 2. Tarjeta Central Cyberpunk (Modal Dialog)
    // ==========================================
    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        width: 760
        height: root.pendingConfirmIndex !== -1 ? 360 : 310
        radius: 20

        // Estética Frosted Glass
        color: root.theme ? root.theme.background : "#cc0d1117"
        border.width: 1.5
        border.color: root.pendingConfirmIndex !== -1 
                      ? root.actions[root.pendingConfirmIndex].color
                      : (root.theme ? root.theme.border : Qt.rgba(0, 1, 0.8, 0.35))

        // Animación de entrada y cambio de altura
        scale: root.isOpen ? 1.0 : 0.92
        opacity: root.isOpen ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.08 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
        }
        Behavior on height {
            NumberAnimation { duration: 240; easing.type: Easing.OutQuad }
        }
        Behavior on border.color {
            ColorAnimation { duration: 220 }
        }

        // Resplandor exterior estilo neón
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: parent.radius + 3
            color: "transparent"
            border.width: 1
            border.color: root.pendingConfirmIndex !== -1 
                          ? Qt.rgba(root.actions[root.pendingConfirmIndex].color.r, root.actions[root.pendingConfirmIndex].color.g, root.actions[root.pendingConfirmIndex].color.b, 0.35)
                          : (root.theme ? root.theme.accentGlow : Qt.rgba(0, 1, 0.8, 0.2))
            z: -1
        }

        // Evitar que clics dentro del diálogo lo cierren
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 22
            spacing: 18

            // ------------------------------------------
            // Cabecera: Identificador, Usuario y Cerrar
            // ------------------------------------------
            Item {
                width: parent.width
                height: 28

                // Badge del Sistema
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: root.theme ? root.theme.accent : "#00ffcc"
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            running: root.isOpen
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                        }
                    }

                    Text {
                        text: "SYSTEM // ENERGY CONTROL"
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.theme ? root.theme.accent : "#00ffcc"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Info Usuario / Host
                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: (Quickshell.env("USER") || "user") + "@archlinux"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 10
                        color: root.theme ? root.theme.textDim : "#8b949e"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Botón Cerrar (✕ Esc)
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: closeBtnMouse.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: closeBtnMouse.containsMouse ? "#ff5555" : Qt.rgba(1, 1, 1, 0.1)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 10
                        font.bold: true
                        color: closeBtnMouse.containsMouse ? "#ff5555" : (root.theme ? root.theme.textDim : "#8b949e")
                    }

                    MouseArea {
                        id: closeBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            // ------------------------------------------
            // Rejilla / Fila de Acciones Principales
            // ------------------------------------------
            Row {
                id: cardsRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Repeater {
                    model: root.actions

                    delegate: Rectangle {
                        id: cardItem
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: root.selectedIndex === index
                        readonly property bool isPending: root.pendingConfirmIndex === index
                        readonly property bool isHovered: cardMouse.containsMouse

                        width: 130
                        height: 155
                        radius: 14

                        // Elevación física en hover/focus
                        y: (isHovered || isSelected) ? -5 : 0
                        scale: (isHovered || isSelected) ? 1.03 : 1.0

                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                        // Fondo y Borde Neón
                        color: isPending 
                               ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.25)
                               : ((isHovered || isSelected) 
                                  ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.14)
                                  : Qt.rgba(1, 1, 1, 0.035))

                        border.width: (isPending || isSelected || isHovered) ? 1.8 : 1
                        border.color: (isPending || isSelected || isHovered)
                                      ? modelData.color
                                      : Qt.rgba(1, 1, 1, 0.08)

                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        // Resplandor de fondo en tarjeta seleccionada
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1
                            border.color: modelData.color
                            opacity: (isHovered || isSelected) ? 0.35 : 0.0
                            visible: opacity > 0

                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            // 1. Badge superior con Atajo de Teclado [ 1 ]
                            Item {
                                width: parent.width
                                height: 18

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22
                                    height: 18
                                    radius: 5
                                    color: (cardItem.isHovered || cardItem.isSelected)
                                           ? modelData.color
                                           : Qt.rgba(1, 1, 1, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.key
                                        font.family: root.theme ? root.theme.fontMono : "monospace"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: (cardItem.isHovered || cardItem.isSelected)
                                               ? "#0d1117"
                                               : (root.theme ? root.theme.textDim : "#8b949e")
                                    }
                                }

                                // Indicador de tecla alternativa
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "[" + modelData.altKey + "]"
                                    font.family: root.theme ? root.theme.fontMono : "monospace"
                                    font.pixelSize: 8
                                    color: (cardItem.isHovered || cardItem.isSelected)
                                           ? modelData.color
                                           : Qt.rgba(1, 1, 1, 0.25)
                                }
                            }

                            // 2. Icono Vectorial Centrado
                            Item {
                                width: parent.width
                                height: 50

                                Canvas {
                                    id: iconCanvas
                                    anchors.centerIn: parent
                                    width: 40
                                    height: 40

                                    property color iconCol: (cardItem.isHovered || cardItem.isSelected)
                                                            ? modelData.color
                                                            : (root.theme ? root.theme.text : "#f0f6fc")

                                    onIconColChanged: requestPaint()
                                    Component.onCompleted: requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.strokeStyle = iconCol;
                                        ctx.fillStyle = iconCol;
                                        ctx.lineWidth = 2.0;
                                        ctx.lineCap = "round";
                                        ctx.lineJoin = "round";

                                        var type = modelData.iconType;

                                        if (type === "lock") {
                                            // Candado: Arco superior
                                            ctx.beginPath();
                                            ctx.arc(20, 15, 8, Math.PI, 0, false);
                                            ctx.stroke();
                                            // Cuerpo rectangular
                                            ctx.beginPath();
                                            ctx.strokeRect(10, 15, 20, 18);
                                            // Cerrojo central
                                            ctx.beginPath();
                                            ctx.arc(20, 22, 2.5, 0, Math.PI * 2);
                                            ctx.fill();
                                            ctx.beginPath();
                                            ctx.moveTo(20, 24);
                                            ctx.lineTo(20, 28);
                                            ctx.stroke();
                                        } 
                                        else if (type === "logout") {
                                            // Salir: Marco de puerta
                                            ctx.beginPath();
                                            ctx.moveTo(18, 8);
                                            ctx.lineTo(9, 8);
                                            ctx.lineTo(9, 32);
                                            ctx.lineTo(18, 32);
                                            ctx.stroke();
                                            // Flecha hacia afuera
                                            ctx.beginPath();
                                            ctx.moveTo(14, 20);
                                            ctx.lineTo(31, 20);
                                            ctx.lineTo(25, 14);
                                            ctx.moveTo(31, 20);
                                            ctx.lineTo(25, 26);
                                            ctx.stroke();
                                        } 
                                        else if (type === "reboot") {
                                            // Reinicio: Flechas circulares
                                            ctx.beginPath();
                                            ctx.arc(20, 20, 12, -Math.PI * 0.8, Math.PI * 0.4, false);
                                            ctx.stroke();
                                            // Flecha 1
                                            ctx.beginPath();
                                            ctx.moveTo(28, 25);
                                            ctx.lineTo(31, 30);
                                            ctx.lineTo(24, 30);
                                            ctx.stroke();

                                            ctx.beginPath();
                                            ctx.arc(20, 20, 12, Math.PI * 0.2, -Math.PI * 0.6, false);
                                            ctx.stroke();
                                            // Flecha 2
                                            ctx.beginPath();
                                            ctx.moveTo(12, 15);
                                            ctx.lineTo(9, 10);
                                            ctx.lineTo(16, 10);
                                            ctx.stroke();
                                        } 
                                        else if (type === "power") {
                                            // Apagar: Símbolo estándar de energía
                                            ctx.beginPath();
                                            ctx.arc(20, 21, 12, -Math.PI * 0.35, Math.PI * 1.35, false);
                                            ctx.stroke();
                                            // Línea vertical superior
                                            ctx.beginPath();
                                            ctx.moveTo(20, 7);
                                            ctx.lineTo(20, 20);
                                            ctx.stroke();
                                        } 
                                        else if (type === "suspend") {
                                            // Luna creciente (Sleep)
                                            ctx.beginPath();
                                            ctx.arc(19, 20, 12, Math.PI * 0.2, Math.PI * 1.6, false);
                                            ctx.bezierCurveTo(15, 12, 23, 24, 28, 27);
                                            ctx.stroke();
                                            // Pequeña Z flotante
                                            ctx.lineWidth = 1.6;
                                            ctx.beginPath();
                                            ctx.moveTo(27, 10);
                                            ctx.lineTo(33, 10);
                                            ctx.lineTo(27, 16);
                                            ctx.lineTo(33, 16);
                                            ctx.stroke();
                                        }
                                    }
                                }
                            }

                            // 3. Título y Subtítulo
                            Column {
                                width: parent.width
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.title
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: (cardItem.isHovered || cardItem.isSelected)
                                           ? modelData.color
                                           : (root.theme ? root.theme.text : "#f0f6fc")
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.subtitle
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 9
                                    color: (cardItem.isHovered || cardItem.isSelected)
                                           ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.8)
                                           : (root.theme ? root.theme.textDim : "#8b949e")
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = index;
                                root.executeAction(index);
                            }
                        }
                    }
                }
            }

            // ------------------------------------------
            // Banner de Confirmación (Si se seleccionó Apagar / Reiniciar / Salir)
            // ------------------------------------------
            Rectangle {
                id: confirmBanner
                width: parent.width
                height: 38
                radius: 10
                visible: root.pendingConfirmIndex !== -1
                color: root.pendingConfirmIndex !== -1 
                       ? Qt.rgba(root.actions[root.pendingConfirmIndex].color.r, root.actions[root.pendingConfirmIndex].color.g, root.actions[root.pendingConfirmIndex].color.b, 0.15)
                       : "transparent"
                border.width: 1
                border.color: root.pendingConfirmIndex !== -1 
                              ? root.actions[root.pendingConfirmIndex].color
                              : "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⚠ " + (root.pendingConfirmIndex !== -1 ? root.actions[root.pendingConfirmIndex].confirmText : "")
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.pendingConfirmIndex !== -1 ? root.actions[root.pendingConfirmIndex].color : "#ffffff"
                    }

                    // Botón Confirmar
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 90
                        height: 24
                        radius: 6
                        color: root.pendingConfirmIndex !== -1 ? root.actions[root.pendingConfirmIndex].color : "#ffffff"

                        Text {
                            anchors.centerIn: parent
                            text: "Confirmar ↵"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#0d1117"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.pendingConfirmIndex !== -1) {
                                    var idx = root.pendingConfirmIndex;
                                    root.pendingConfirmIndex = -1;
                                    var cmd = root.actions[idx].command;
                                    root.closeRequested();
                                    execProc.command = cmd;
                                    execProc.running = true;
                                }
                            }
                        }
                    }

                    // Botón Cancelar
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 75
                        height: 24
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar (Esc)"
                            font.pixelSize: 9
                            color: "#f0f6fc"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pendingConfirmIndex = -1
                        }
                    }
                }
            }

            // ------------------------------------------
            // Pie de Página: Atajos de Navegación
            // ------------------------------------------
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: 28; height: 16; radius: 4; color: Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "1 - 5"; font.pixelSize: 8; font.bold: true; color: "#8b949e" }
                    }
                    Text { text: "Direct action"; font.pixelSize: 9; color: "#6e7681"; anchors.verticalCenter: parent.verticalCenter }
                }

                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: 24; height: 16; radius: 4; color: Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "← →"; font.pixelSize: 8; font.bold: true; color: "#8b949e" }
                    }
                    Text { text: "Browse"; font.pixelSize: 9; color: "#6e7681"; anchors.verticalCenter: parent.verticalCenter }
                }

                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: 28; height: 16; radius: 4; color: Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "ENTER"; font.pixelSize: 8; font.bold: true; color: "#8b949e" }
                    }
                    Text { text: "Execute"; font.pixelSize: 9; color: "#6e7681"; anchors.verticalCenter: parent.verticalCenter }
                }

                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: 24; height: 16; radius: 4; color: Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "ESC"; font.pixelSize: 8; font.bold: true; color: "#8b949e" }
                    }
                    Text { text: "Cancel"; font.pixelSize: 9; color: "#6e7681"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
