import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * ClipboardManager.qml
 * Gestor de Portapapeles Flotante Frosted Glass (Cyberpunk / Native Wayland)
 * - Historial instantáneo potenciado por cliphist y wl-clipboard.
 * - Clasificación inteligente de contenido (Código, URLs, Imágenes, Rutas, Texto).
 * - Búsqueda en tiempo real con filtrado instantáneo.
 * - Copia en un clic o eliminación de elementos individuales.
 * - Limpieza total con un toque.
 */
Item {
    id: root

    property var theme
    property bool isOpen: false
    signal closeRequested()

    property alias card: clipCard
    property var clipList: []
    property string searchQuery: ""

    // Proceso para listar elementos del portapapeles
    Process {
        id: listProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard_manager.py", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.clipList = data.items || [];
                } catch (e) {}
            }
        }
    }

    // Proceso para acciones (copiar, borrar, limpiar)
    Process {
        id: actionProc
        command: []
        running: false
        onExited: {
            listProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard_manager.py", "list"];
            listProc.running = true;
        }
    }

    function refresh() {
        if (!listProc.running) {
            listProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard_manager.py", "list"];
            listProc.running = true;
        }
    }

    function copyItem(rawLine) {
        actionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard_manager.py", "copy", rawLine];
        actionProc.running = true;
        root.closeRequested();
    }

    function deleteItem(rawLine) {
        actionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard_manager.py", "delete", rawLine];
        actionProc.running = true;
    }

    function wipeHistory() {
        actionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard_manager.py", "wipe"];
        actionProc.running = true;
    }

    onIsOpenChanged: {
        if (isOpen) {
            root.searchQuery = "";
            if (searchInput) searchInput.text = "";
            refresh();
            if (searchInput) searchInput.forceActiveFocus();
        }
    }

    Component.onCompleted: refresh()

    // Fondo para cerrar al dar clic afuera
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    // ==========================================
    // Tarjeta Flotante Glassmorphism
    // ==========================================
    Rectangle {
        id: clipCard
        width: 390
        height: 500
        anchors.centerIn: parent

        radius: 18
        color: root.theme ? root.theme.backgroundSolid : "#0d1117"
        opacity: root.isOpen ? 0.96 : 0.0
        border.width: 1.2
        border.color: root.theme ? root.theme.accent : "#00ffcc"
        clip: true

        Behavior on opacity { NumberAnimation { duration: 180 } }
        transform: Scale {
            origin.x: clipCard.width / 2
            origin.y: clipCard.height / 2
            xScale: root.isOpen ? 1.0 : 0.95
            yScale: root.isOpen ? 1.0 : 0.95
            Behavior on xScale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on yScale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        // Resplandor superior neón sutil
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            height: 1.5
            color: root.theme ? root.theme.accent : "#00ffcc"
            opacity: 0.75
        }

        // Prevenir cierre al hacer clic adentro
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ----------------------------------------------------
            // 1. Cabecera (Icono, Título, Contador, Limpiar y Cerrar)
            // ----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.20) : Qt.rgba(0, 1, 0.8, 0.20)
                    border.width: 1
                    border.color: root.theme ? root.theme.accent : "#00ffcc"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅍"
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 14
                        color: root.theme ? root.theme.accent : "#00ffcc"
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Clipboard Glass"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#ffffff"
                    }

                    Text {
                        text: root.clipList.length + " elementos guardados"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 8
                        color: root.theme ? root.theme.textDim : "#8b949e"
                    }
                }

                // Botón Limpiar Todo
                Rectangle {
                    visible: root.clipList.length > 0
                    height: 24
                    width: wipeLabel.implicitWidth + 14
                    radius: 6
                    color: wipeMouse.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: wipeMouse.containsMouse ? (root.theme ? root.theme.danger : "#ff5555") : Qt.rgba(1, 1, 1, 0.10)

                    Row {
                        id: wipeLabel
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰃢"
                            font.family: root.theme ? root.theme.fontMono : "monospace"
                            font.pixelSize: 9
                            color: wipeMouse.containsMouse ? "#ff5555" : "#8b949e"
                        }
                        Text {
                            text: "Limpiar"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 8
                            font.bold: true
                            color: wipeMouse.containsMouse ? "#ff5555" : "#8b949e"
                        }
                    }

                    MouseArea {
                        id: wipeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.wipeHistory()
                    }
                }

                // Botón Cerrar (✕)
                Rectangle {
                    width: 26
                    height: 26
                    radius: 7
                    color: closeBtnMouse.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.25) : Qt.rgba(1, 1, 1, 0.05)

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 10
                        color: closeBtnMouse.containsMouse ? "#ff5555" : "#8b949e"
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

            // ----------------------------------------------------
            // 2. Buscador en Tiempo Real
            // ----------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.40)
                border.width: 1
                border.color: searchInput.activeFocus ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.10)

                Behavior on border.color { ColorAnimation { duration: 160 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: ""
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 10
                        color: searchInput.activeFocus ? (root.theme ? root.theme.accent : "#00ffcc") : "#6e7681"
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 10
                        color: "#ffffff"
                        selectByMouse: true
                        clip: true
                        onTextChanged: root.searchQuery = text.toLowerCase().trim()

                        Text {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.activeFocus
                            text: "Buscar en portapapeles..."
                            font: searchInput.font
                            color: "#6e7681"
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // 3. Lista de Elementos con Scroll
            // ----------------------------------------------------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Estado Vacío
                Column {
                    visible: root.clipList.length === 0
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰅎"
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 32
                        color: "#484f58"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "El portapapeles está vacío"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 10
                        color: "#6e7681"
                    }
                }

                Flickable {
                    id: flick
                    visible: root.clipList.length > 0
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: clipColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: clipColumn
                        width: parent.width
                        spacing: 5

                        Repeater {
                            model: {
                                if (!root.searchQuery) return root.clipList;
                                return root.clipList.filter(function(item) {
                                    return item.preview.toLowerCase().indexOf(root.searchQuery) !== -1 ||
                                           item.type.toLowerCase().indexOf(root.searchQuery) !== -1;
                                });
                            }

                            delegate: Rectangle {
                                id: itemCard
                                required property var modelData
                                Layout.fillWidth: true
                                height: 44
                                radius: 10
                                color: itemMouse.containsMouse
                                       ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.10))
                                       : Qt.rgba(1, 1, 1, 0.04)
                                border.width: itemMouse.containsMouse ? 1 : 0
                                border.color: root.theme ? root.theme.accent : "#00ffcc"

                                Behavior on color { ColorAnimation { duration: 140 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    // Icono del Tipo de Contenido
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 7
                                        color: {
                                            if (modelData.type === "code") return Qt.rgba(0.74, 0.58, 0.98, 0.20);
                                            if (modelData.type === "url") return Qt.rgba(0, 1, 0.8, 0.20);
                                            if (modelData.type === "image") return Qt.rgba(1.0, 0.72, 0.42, 0.20);
                                            if (modelData.type === "path") return Qt.rgba(0.31, 0.98, 0.48, 0.20);
                                            return Qt.rgba(1, 1, 1, 0.08);
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.icon || "󰦨"
                                            font.family: root.theme ? root.theme.fontMono : "monospace"
                                            font.pixelSize: 13
                                            color: {
                                                if (modelData.type === "code") return "#bd93f9";
                                                if (modelData.type === "url") return "#00ffcc";
                                                if (modelData.type === "image") return "#ffb86c";
                                                if (modelData.type === "path") return "#50fa7b";
                                                return "#f0f6fc";
                                            }
                                        }
                                    }

                                    // Vista Previa del Texto
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: modelData.preview
                                            font.family: (modelData.type === "code" || modelData.type === "path")
                                                         ? (root.theme ? root.theme.fontMono : "monospace")
                                                         : (root.theme ? root.theme.fontFamily : "sans-serif")
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: "#ffffff"
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Text {
                                            text: modelData.type.toUpperCase()
                                            font.family: root.theme ? root.theme.fontMono : "monospace"
                                            font.pixelSize: 7
                                            color: root.theme ? root.theme.textDim : "#8b949e"
                                        }
                                    }

                                    // Botón Borrar Item Individual (Hover)
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 6
                                        color: delBtnMouse.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.25) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            font.pixelSize: 8
                                            color: delBtnMouse.containsMouse ? "#ff5555" : "#6e7681"
                                        }

                                        MouseArea {
                                            id: delBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.deleteItem(modelData.raw)
                                        }
                                    }
                                }

                                // Clic en el elemento lo copia al portapapeles y cierra
                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.copyItem(modelData.raw)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
