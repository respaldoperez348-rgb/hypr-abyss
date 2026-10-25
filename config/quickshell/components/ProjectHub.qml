import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * ProjectHub.qml
 * Menú Flotante Frosted Glass para gestión y lanzamiento de:
 * 1. Proyectos de desarrollo en ~/Proyectos
 * 2. Configuraciones del sistema en ~/.config y dotfiles
 * - Detección inteligente de tipo (Mobile, Node, Python, Quickshell, Dotfiles).
 * - Filtro de búsqueda en tiempo real.
 * - Acceso rápido para abrir en Editor (Antigravity/Zed), Terminal (Kitty) o Archivos (Thunar).
 * - Creador instantáneo de nuevos proyectos con git init automático.
 */
Item {
    id: root

    property var theme
    property bool isOpen: false
    signal closeRequested()

    property alias card: hubCard
    property var projectList: []
    property var configList: []
    property string activeTab: "projects" // "projects" o "configs"
    property string searchQuery: ""

    // Proceso para listar proyectos y configuraciones
    Process {
        id: listProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/projects_manager.py", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.projectList = data.projects || [];
                    root.configList = data.configs || [];
                } catch (e) {}
            }
        }
    }

    // Proceso para acciones (crear, abrir)
    Process {
        id: actionProc
        command: []
        running: false
        onExited: {
            // Recargar lista después de crear
            listProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/projects_manager.py", "list"];
            listProc.running = true;
        }
    }

    function refresh() {
        if (!listProc.running) {
            listProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/projects_manager.py", "list"];
            listProc.running = true;
        }
    }

    function openProject(path, editor) {
        actionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/projects_manager.py", "open", path, editor || "antigravity"];
        actionProc.running = true;
        root.closeRequested();
    }

    function createProject(name) {
        if (!name || name.trim().length === 0) return;
        actionProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/projects_manager.py", "create", name.trim()];
        actionProc.running = true;
        createInput.text = "";
        root.closeRequested();
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

    // Fondo transparente que captura clic afuera para cerrar
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    // ==========================================
    // Tarjeta Flotante Glassmorphism
    // ==========================================
    Rectangle {
        id: hubCard
        width: 390
        height: 520
        anchors.top: parent.top
        anchors.topMargin: 46
        anchors.left: parent.left
        anchors.leftMargin: 120

        radius: 18
        color: root.theme ? root.theme.backgroundSolid : "#0d1117"
        opacity: root.isOpen ? 0.96 : 0.0
        border.width: 1.2
        border.color: root.activeTab === "projects"
                      ? (root.theme ? root.theme.accent : "#00ffcc")
                      : (root.theme ? root.theme.accentAlt : "#bd93f9")
        clip: true

        Behavior on border.color { ColorAnimation { duration: 180 } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        transform: Translate {
            y: root.isOpen ? 0 : -16
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        // Resplandor superior neón sutil
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            height: 1.5
            color: root.activeTab === "projects"
                   ? (root.theme ? root.theme.accent : "#00ffcc")
                   : (root.theme ? root.theme.accentAlt : "#bd93f9")
            opacity: 0.8
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        // Prevenir que clics dentro de la tarjeta cierren el menú
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ----------------------------------------------------
            // 1. Cabecera (Título, Contador y Acceso Rápido a Carpeta)
            // ----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: root.activeTab === "projects"
                           ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.20) : Qt.rgba(0, 1, 0.8, 0.20))
                           : (root.theme ? Qt.rgba(root.theme.accentAlt.r, root.theme.accentAlt.g, root.theme.accentAlt.b, 0.20) : Qt.rgba(0.74, 0.58, 0.98, 0.20))
                    border.width: 1
                    border.color: root.activeTab === "projects"
                                  ? (root.theme ? root.theme.accent : "#00ffcc")
                                  : (root.theme ? root.theme.accentAlt : "#bd93f9")

                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.activeTab === "projects" ? "󰨞" : "󰒓"
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 14
                        color: root.activeTab === "projects"
                               ? (root.theme ? root.theme.accent : "#00ffcc")
                               : (root.theme ? root.theme.accentAlt : "#bd93f9")
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: root.activeTab === "projects" ? "Project Hub" : "Config Hub"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#ffffff"
                    }

                    Text {
                        text: root.activeTab === "projects"
                              ? (root.projectList.length + " proyectos en ~/Proyectos")
                              : (root.configList.length + " configuraciones en ~/.config")
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 8
                        color: root.theme ? root.theme.textDim : "#8b949e"
                    }
                }

                // Botón abrir carpeta en explorador de archivos
                Rectangle {
                    width: 26
                    height: 26
                    radius: 7
                    color: folderBtnMouse.containsMouse ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.12)) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: folderBtnMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.10)

                    Text {
                        anchors.centerIn: parent
                        text: "󰉋"
                        font.family: root.theme ? root.theme.fontMono : "monospace"
                        font.pixelSize: 12
                        color: folderBtnMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : "#f0f6fc"
                    }

                    MouseArea {
                        id: folderBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var targetPath = root.activeTab === "projects"
                                             ? (Quickshell.env("HOME") + "/Proyectos")
                                             : (Quickshell.env("HOME") + "/.config");
                            root.openProject(targetPath, "files");
                        }
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
            // 2. Selector de Pestañas: [ 󰨞 Proyectos ] [ 󰒓 Configs (.config) ]
            // ----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Pestaña Proyectos
                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: 8
                    color: root.activeTab === "projects"
                           ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.22) : Qt.rgba(0, 1, 0.8, 0.22))
                           : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: root.activeTab === "projects"
                                  ? (root.theme ? root.theme.accent : "#00ffcc")
                                  : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "󰨞"
                            font.family: root.theme ? root.theme.fontMono : "monospace"
                            font.pixelSize: 11
                            color: root.activeTab === "projects" ? (root.theme ? root.theme.accent : "#00ffcc") : "#8b949e"
                        }
                        Text {
                            text: "Proyectos (" + root.projectList.length + ")"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: root.activeTab === "projects"
                            color: root.activeTab === "projects" ? "#ffffff" : "#8b949e"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeTab = "projects";
                            searchInput.forceActiveFocus();
                        }
                    }
                }

                // Pestaña Configs (~/.config)
                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: 8
                    color: root.activeTab === "configs"
                           ? (root.theme ? Qt.rgba(root.theme.accentAlt.r, root.theme.accentAlt.g, root.theme.accentAlt.b, 0.22) : Qt.rgba(0.74, 0.58, 0.98, 0.22))
                           : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: root.activeTab === "configs"
                                  ? (root.theme ? root.theme.accentAlt : "#bd93f9")
                                  : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "󰒓"
                            font.family: root.theme ? root.theme.fontMono : "monospace"
                            font.pixelSize: 11
                            color: root.activeTab === "configs" ? (root.theme ? root.theme.accentAlt : "#bd93f9") : "#8b949e"
                        }
                        Text {
                            text: "Configs (.config)"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: root.activeTab === "configs"
                            color: root.activeTab === "configs" ? "#ffffff" : "#8b949e"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeTab = "configs";
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // 3. Buscador en Tiempo Real
            // ----------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.40)
                border.width: 1
                border.color: searchInput.activeFocus
                              ? (root.activeTab === "projects" ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.accentAlt : "#bd93f9"))
                              : Qt.rgba(1, 1, 1, 0.10)

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
                        color: searchInput.activeFocus
                               ? (root.activeTab === "projects" ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.accentAlt : "#bd93f9"))
                               : "#6e7681"
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
                            text: root.activeTab === "projects" ? "Filtrar proyecto..." : "Filtrar configuración (.config, hypr, quickshell...)"
                            font: searchInput.font
                            color: "#6e7681"
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // 4. Lista Dinámica (Proyectos o Configuraciones)
            // ----------------------------------------------------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: flick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: projectColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: projectColumn
                        width: parent.width
                        spacing: 5

                        Repeater {
                            model: {
                                var currentList = (root.activeTab === "projects") ? root.projectList : root.configList;
                                if (!root.searchQuery) return currentList;
                                return currentList.filter(function(item) {
                                    var nameMatch = item.name && item.name.toLowerCase().indexOf(root.searchQuery) !== -1;
                                    var typeMatch = item.type && item.type.toLowerCase().indexOf(root.searchQuery) !== -1;
                                    var descMatch = item.desc && item.desc.toLowerCase().indexOf(root.searchQuery) !== -1;
                                    return nameMatch || typeMatch || descMatch;
                                });
                            }

                            delegate: Rectangle {
                                id: projCard
                                required property var modelData
                                Layout.fillWidth: true
                                height: 46
                                radius: 10
                                color: rowMouse.containsMouse
                                       ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.10))
                                       : Qt.rgba(1, 1, 1, 0.04)
                                border.width: rowMouse.containsMouse ? 1 : 0
                                border.color: root.activeTab === "projects"
                                              ? (root.theme ? root.theme.accent : "#00ffcc")
                                              : (root.theme ? root.theme.accentAlt : "#bd93f9")

                                Behavior on color { ColorAnimation { duration: 140 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    // Icono del Tipo
                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: 7
                                        color: {
                                            if (modelData.name.indexOf(".config") !== -1) return Qt.rgba(0, 1, 0.8, 0.22);
                                            if (modelData.type && modelData.type.indexOf("Mobile") !== -1) return Qt.rgba(0.74, 0.58, 0.98, 0.20);
                                            if (modelData.type && modelData.type.indexOf("Node") !== -1) return Qt.rgba(0.31, 0.98, 0.48, 0.20);
                                            if (modelData.type && modelData.type.indexOf("Python") !== -1) return Qt.rgba(1.0, 0.72, 0.42, 0.20);
                                            if (modelData.type && modelData.type.indexOf("Quickshell") !== -1) return Qt.rgba(0, 1, 0.8, 0.20);
                                            if (modelData.type && modelData.type.indexOf("Window Manager") !== -1) return Qt.rgba(0, 0.75, 1, 0.20);
                                            return Qt.rgba(1, 1, 1, 0.08);
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.icon || "󰉋"
                                            font.family: root.theme ? root.theme.fontMono : "monospace"
                                            font.pixelSize: 13
                                            color: {
                                                if (modelData.name.indexOf(".config") !== -1) return "#00ffcc";
                                                if (modelData.type && modelData.type.indexOf("Mobile") !== -1) return "#bd93f9";
                                                if (modelData.type && modelData.type.indexOf("Node") !== -1) return "#50fa7b";
                                                if (modelData.type && modelData.type.indexOf("Python") !== -1) return "#ffb86c";
                                                if (modelData.type && modelData.type.indexOf("Quickshell") !== -1) return "#00ffcc";
                                                if (modelData.type && modelData.type.indexOf("Window Manager") !== -1) return "#57c7ff";
                                                return "#f0f6fc";
                                            }
                                        }
                                    }

                                    // Info: Nombre, Tipo / Descripción y Rama
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: modelData.name
                                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#ffffff"
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Row {
                                            spacing: 5
                                            Text {
                                                text: modelData.desc ? modelData.desc : (modelData.type || "Proyecto")
                                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                                font.pixelSize: 8
                                                color: root.theme ? root.theme.textDim : "#8b949e"
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: !!modelData.branch
                                                text: "•"
                                                font.pixelSize: 8
                                                color: "#484f58"
                                            }

                                            Row {
                                                visible: !!modelData.branch
                                                spacing: 2
                                                Text {
                                                    text: ""
                                                    font.family: root.theme ? root.theme.fontMono : "monospace"
                                                    font.pixelSize: 8
                                                    color: root.theme ? root.theme.accent : "#00ffcc"
                                                }
                                                Text {
                                                    text: modelData.branch
                                                    font.family: root.theme ? root.theme.fontMono : "monospace"
                                                    font.pixelSize: 8
                                                    color: root.theme ? root.theme.accent : "#00ffcc"
                                                }
                                            }

                                            // Indicador de cambios sin commitear
                                            Rectangle {
                                                visible: !!modelData.dirty
                                                width: 4
                                                height: 4
                                                radius: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: "#ffb86c"
                                            }
                                        }
                                    }

                                    // Botones de Acción Rápida (Aparecen en Hover)
                                    Row {
                                        spacing: 4
                                        visible: rowMouse.containsMouse

                                        // Abrir en Zed
                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 6
                                            color: zedBtnM.containsMouse ? (root.theme ? root.theme.accentAlt : "#bd93f9") : Qt.rgba(1, 1, 1, 0.10)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰨞"
                                                font.family: root.theme ? root.theme.fontMono : "monospace"
                                                font.pixelSize: 10
                                                color: zedBtnM.containsMouse ? "#0d1117" : "#f0f6fc"
                                            }

                                            MouseArea {
                                                id: zedBtnM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.openProject(modelData.path, "zed")
                                            }
                                        }

                                        // Terminal en el directorio
                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 6
                                            color: termBtnM.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.10)

                                            Text {
                                                anchors.centerIn: parent
                                                text: ""
                                                font.family: root.theme ? root.theme.fontMono : "monospace"
                                                font.pixelSize: 9
                                                color: termBtnM.containsMouse ? "#0d1117" : "#f0f6fc"
                                            }

                                            MouseArea {
                                                id: termBtnM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.openProject(modelData.path, "terminal")
                                            }
                                        }

                                        // Abrir en explorador Thunar
                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 6
                                            color: fileBtnM.containsMouse ? (root.theme ? root.theme.accentAlt : "#bd93f9") : Qt.rgba(1, 1, 1, 0.10)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰉋"
                                                font.family: root.theme ? root.theme.fontMono : "monospace"
                                                font.pixelSize: 9
                                                color: fileBtnM.containsMouse ? "#0d1117" : "#f0f6fc"
                                            }

                                            MouseArea {
                                                id: fileBtnM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.openProject(modelData.path, "files")
                                            }
                                        }
                                    }
                                }

                                // Clic general abre en Antigravity
                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openProject(modelData.path, "antigravity")
                                }
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // 5. Pie Dinámico:
            // - Pestaña Proyectos: Creador Rápido de Nuevo Proyecto
            // - Pestaña Configs: Acceso Rápido a ~/.config completo y dotfiles
            // ----------------------------------------------------
            Item {
                Layout.fillWidth: true
                height: 38

                // Pie de Proyectos
                Rectangle {
                    visible: root.activeTab === "projects"
                    anchors.fill: parent
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.50)
                    border.width: 1
                    border.color: createInput.activeFocus ? (root.theme ? root.theme.accentAlt : "#bd93f9") : Qt.rgba(1, 1, 1, 0.08)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Text {
                            text: "󰐕"
                            font.family: root.theme ? root.theme.fontMono : "monospace"
                            font.pixelSize: 12
                            color: root.theme ? root.theme.accentAlt : "#bd93f9"
                            Layout.leftMargin: 4
                        }

                        TextInput {
                            id: createInput
                            Layout.fillWidth: true
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 10
                            color: "#ffffff"
                            selectByMouse: true
                            clip: true
                            onAccepted: root.createProject(text)

                            Text {
                                anchors.fill: parent
                                visible: !createInput.text && !createInput.activeFocus
                                text: "Nuevo proyecto o carpeta..."
                                font: createInput.font
                                color: "#6e7681"
                            }
                        }

                        Rectangle {
                            height: 28
                            width: createBtnLabel.implicitWidth + 14
                            radius: 6
                            color: createBtnMouse.containsMouse ? (root.theme ? root.theme.accentAlt : "#bd93f9") : Qt.rgba(0.74, 0.58, 0.98, 0.20)
                            border.width: 1
                            border.color: root.theme ? root.theme.accentAlt : "#bd93f9"

                            Text {
                                id: createBtnLabel
                                anchors.centerIn: parent
                                text: "+ Crear"
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 9
                                font.bold: true
                                color: createBtnMouse.containsMouse ? "#0d1117" : "#ffffff"
                            }

                            MouseArea {
                                id: createBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.createProject(createInput.text)
                            }
                        }
                    }
                }

                // Pie de Configuraciones
                RowLayout {
                    visible: root.activeTab === "configs"
                    anchors.fill: parent
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: 8
                        color: openConfigAllM.containsMouse ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.25) : Qt.rgba(0, 1, 0.8, 0.25)) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: root.theme ? root.theme.accent : "#00ffcc"

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰒓"
                                font.family: root.theme ? root.theme.fontMono : "monospace"
                                font.pixelSize: 11
                                color: root.theme ? root.theme.accent : "#00ffcc"
                            }
                            Text {
                                text: "Abrir ~/.config completo"
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 9
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: openConfigAllM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openProject(Quickshell.env("HOME") + "/.config", "antigravity")
                        }
                    }

                    Rectangle {
                        width: dotfilesBtnRow.implicitWidth + 14
                        height: 34
                        radius: 8
                        color: openDotfilesM.containsMouse ? (root.theme ? Qt.rgba(root.theme.accentAlt.r, root.theme.accentAlt.g, root.theme.accentAlt.b, 0.25) : Qt.rgba(0.74, 0.58, 0.98, 0.25)) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: root.theme ? root.theme.accentAlt : "#bd93f9"

                        Row {
                            id: dotfilesBtnRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: ""
                                font.family: root.theme ? root.theme.fontMono : "monospace"
                                font.pixelSize: 11
                                color: root.theme ? root.theme.accentAlt : "#bd93f9"
                            }
                            Text {
                                text: "dotfiles"
                                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                font.pixelSize: 9
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: openDotfilesM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openProject(Quickshell.env("HOME") + "/dotfiles", "antigravity")
                        }
                    }
                }
            }
        }
    }
}
