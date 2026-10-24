import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * DevScratchpad.qml
 * Bloc de Notas Rápido / Scratchpad Frosted Glass (Super + S)
 * - Persistencia automática a disco en ~/.config/quickshell/scratchpad.txt.
 * - Copia instantánea de todo el contenido al portapapeles con 1 clic.
 * - Contador dinámico de caracteres, palabras y líneas.
 * - Tipografía monoespaciada para código y notas técnicas.
 */
Item {
    id: root

    property var theme
    property bool isOpen: false
    signal closeRequested()

    property alias card: padCard
    property string textContent: ""
    readonly property string filePath: Quickshell.env("HOME") + "/.config/quickshell/scratchpad.txt"

    // Proceso para guardar a disco
    Process {
        id: saveProc
        command: []
        running: false
    }

    // Proceso para copiar al portapapeles del sistema
    Process {
        id: copyProc
        command: []
        running: false
    }

    // Proceso para cargar contenido inicial
    Process {
        id: loadProc
        command: ["cat", root.filePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text !== undefined && this.text !== null) {
                    textArea.text = this.text;
                    root.textContent = this.text;
                }
            }
        }
    }

    Timer {
        id: saveDebounce
        interval: 500
        repeat: false
        onTriggered: {
            // Guarda el contenido actual en el archivo
            saveProc.command = ["bash", "-c", "cat << 'EOF' > \"" + root.filePath + "\"\n" + textArea.text + "\nEOF"];
            saveProc.running = true;
        }
    }

    function copyAll() {
        copyProc.command = ["wl-copy", textArea.text];
        copyProc.running = true;
    }

    function clearText() {
        textArea.text = "";
        root.textContent = "";
        saveDebounce.restart();
    }

    onIsOpenChanged: {
        if (isOpen) {
            loadProc.command = ["cat", root.filePath];
            loadProc.running = true;
            textArea.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        loadProc.command = ["cat", root.filePath];
        loadProc.running = true;
    }

    // Clic afuera cierra el scratchpad
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    // ==========================================
    // Tarjeta Flotante Glassmorphism
    // ==========================================
    Rectangle {
        id: padCard
        width: 520
        height: 420
        anchors.centerIn: parent

        radius: 18
        color: root.theme ? root.theme.backgroundSolid : "#0d1117"
        opacity: root.isOpen ? 0.96 : 0.0
        border.width: 1.2
        border.color: root.theme ? root.theme.warning : "#ffb86c"
        clip: true

        Behavior on opacity { NumberAnimation { duration: 180 } }
        transform: Scale {
            origin.x: padCard.width / 2
            origin.y: padCard.height / 2
            xScale: root.isOpen ? 1.0 : 0.95
            yScale: root.isOpen ? 1.0 : 0.95
            Behavior on xScale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on yScale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        // Resplandor superior ámbar neón
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            height: 1.5
            color: root.theme ? root.theme.warning : "#ffb86c"
            opacity: 0.8
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
            // 1. Cabecera (Icono, Título, Estadísticas, Acciones)
            // ----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: Qt.rgba(1.0, 0.72, 0.42, 0.22)
                    border.width: 1
                    border.color: root.theme ? root.theme.warning : "#ffb86c"

                    Text {
                        anchors.centerIn: parent
                        text: "󰠮"
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 14
                        color: root.theme ? root.theme.warning : "#ffb86c"
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Dev Scratchpad"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#ffffff"
                    }

                    Text {
                        text: {
                            var chars = textArea.text.length;
                            var lines = textArea.text.split("\n").length;
                            var words = textArea.text.trim().length > 0 ? textArea.text.trim().split(/\s+/).length : 0;
                            return lines + " líneas • " + words + " palabras • " + chars + " caracteres";
                        }
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 8
                        color: root.theme ? root.theme.textDim : "#8b949e"
                    }
                }

                // Botón Copiar Todo
                Rectangle {
                    height: 24
                    width: copyLabel.implicitWidth + 14
                    radius: 6
                    color: copyMouse.containsMouse ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.25) : Qt.rgba(0, 1, 0.8, 0.25)) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: copyMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.10)

                    Row {
                        id: copyLabel
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰆏"
                            font.family: root.theme ? root.theme.fontMono : "monospace"
                            font.pixelSize: 9
                            color: copyMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : "#f0f6fc"
                        }
                        Text {
                            text: "Copiar"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 8
                            font.bold: true
                            color: copyMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : "#f0f6fc"
                        }
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyAll()
                    }
                }

                // Botón Limpiar
                Rectangle {
                    height: 24
                    width: clearLabel.implicitWidth + 14
                    radius: 6
                    color: clearMouse.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: clearMouse.containsMouse ? (root.theme ? root.theme.danger : "#ff5555") : Qt.rgba(1, 1, 1, 0.10)

                    Row {
                        id: clearLabel
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰃢"
                            font.family: root.theme ? root.theme.fontMono : "monospace"
                            font.pixelSize: 9
                            color: clearMouse.containsMouse ? "#ff5555" : "#8b949e"
                        }
                        Text {
                            text: "Limpiar"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 8
                            font.bold: true
                            color: clearMouse.containsMouse ? "#ff5555" : "#8b949e"
                        }
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearText()
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
            // 2. Área de Edición Multilínea (TextArea con Scroll)
            // ----------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.45)
                border.width: 1
                border.color: textArea.activeFocus ? (root.theme ? root.theme.warning : "#ffb86c") : Qt.rgba(1, 1, 1, 0.08)

                Behavior on border.color { ColorAnimation { duration: 160 } }

                Flickable {
                    id: flickArea
                    anchors.fill: parent
                    anchors.margins: 10
                    contentWidth: width
                    contentHeight: textArea.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    TextArea.flickable: TextArea {
                        id: textArea
                        wrapMode: TextEdit.Wrap
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 10
                        color: "#f0f6fc"
                        selectByMouse: true
                        selectionColor: root.theme ? root.theme.accent : "#00ffcc"
                        selectedTextColor: "#0d1117"
                        placeholderText: "# Apuntes rápidos, snippets de código o comandos temporales...\n- Se guarda automáticamente al escribir."
                        placeholderTextColor: "#6e7681"
                        background: null

                        onTextChanged: {
                            root.textContent = text;
                            saveDebounce.restart();
                        }
                    }
                }
            }
        }
    }
}
