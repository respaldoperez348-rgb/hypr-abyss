import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * WallpaperSelector.qml
 * Selector de Fondos de Pantalla flotante inferior (estilo Hacker / Cyberpunk Frosted Glass)
 * - Iconos vectoriales nativos de alta precisión (sin depender de fuentes rotas ni emojis feos).
 * - Barra de filtros unificada e interactiva (Static, Animated, Random, Refresh).
 * - Carrusel dinámico con elevación física, escala fluida y chip interactivo de aplicar.
 * - Buscador integrado con vector lupa y borrado rápido.
 * - Navegación fluida por ratón y teclado (Enter / Escape / Flechas).
 */
Item {
    id: root

    property var theme
    property bool isOpen: false
    property string barStyle: "deck"
    signal closeRequested()
    property alias card: panelCard
    readonly property bool isAnimating: slideYAnim.running

    implicitWidth: 880
    implicitHeight: (root.barStyle === "deck") ? 310 : 240

    // Estados de filtrado y búsqueda
    property string activeFilter: "all" // "all", "static", "animated"
    property string searchQuery: ""
    property var allWallpapers: []
    property string selectedPath: ""
    property string justAppliedPath: ""

    // Proceso para escanear fondos de pantalla
    Process {
        id: scanProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/get_wallpapers.py"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.allWallpapers = JSON.parse(this.text);
                } catch (e) {
                    console.log("[WallpaperSelector] Error parsing JSON:", e);
                }
            }
        }
    }

    // Proceso para aplicar el fondo seleccionado y sincronizar el ecosistema
    Process {
        id: applyProc
        command: []
        running: false
        onExited: {
            appliedTimer.restart();
        }
    }

    Process {
        id: recordProfileWpProc
        command: []
        running: false
    }

    Timer {
        id: appliedTimer
        interval: 1800
        repeat: false
        onTriggered: {
            root.justAppliedPath = "";
        }
    }

    function applyWallpaper(path) {
        if (!path || path.length === 0) return;
        root.selectedPath = path;
        root.justAppliedPath = path;
        applyProc.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/wallchange.sh", path];
        applyProc.running = true;
        recordProfileWpProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/setup_manager.py", "set-wp", path];
        recordProfileWpProc.running = false;
        recordProfileWpProc.running = true;
    }

    function applyRandom() {
        var list = root.filteredWallpapers;
        if (list.length > 0) {
            var idx = Math.floor(Math.random() * list.length);
            root.applyWallpaper(list[idx].path);
        } else {
            applyProc.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/wallchange.sh"];
            applyProc.running = true;
        }
    }

    function refresh() {
        if (!scanProc.running) {
            refreshRotation.restart();
            scanProc.running = true;
        }
    }

    // Lista filtrada reactiva
    readonly property var filteredWallpapers: {
        var list = root.allWallpapers;
        var query = root.searchQuery.toLowerCase().trim();
        var filter = root.activeFilter;

        return list.filter(function(item) {
            if (filter !== "all" && item.type !== filter) {
                return false;
            }
            if (query.length > 0 && !item.name.toLowerCase().includes(query)) {
                return false;
            }
            return true;
        });
    }

    Component.onCompleted: {
        refresh();
    }

    onIsOpenChanged: {
        if (isOpen) {
            refresh();
            searchInput.forceActiveFocus();
        }
    }

    // ==========================================
    // Contenedor Visual Frosted Glass
    // ==========================================
    Rectangle {
        id: panelCard
        anchors.fill: parent

        // Curvatura superior amplia como en la imagen
        topLeftRadius: 22
        topRightRadius: 22
        bottomLeftRadius: 0
        bottomRightRadius: 0

        // Fondo frosted glass cyberpunk
        color: root.theme ? root.theme.backgroundSolid : "#0d1117"
        opacity: 0.92

        border.width: 1
        border.color: root.theme ? root.theme.borderHover : "#00ffcc"

        // Desplazamiento animado de subida / bajada con aceleración suave
        y: root.isOpen ? 0 : root.height
        Behavior on y {
            NumberAnimation {
                id: slideYAnim
                duration: 280
                easing.type: Easing.OutCubic
            }
        }

        // Resplandor neón superior sutil
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1.5
            color: root.theme ? root.theme.accent : "#00ffcc"
            opacity: 0.7
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ==========================================
            // Barra Superior de Controles y Filtros (Centrada como en la imagen)
            // ==========================================
            Item {
                Layout.fillWidth: true
                height: 28

                // Píldora Segmentada Central (Static, Animated, Random, Refresh)
                Rectangle {
                    anchors.centerIn: parent
                    height: 28
                    width: filterTabsRow.implicitWidth + 8
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Row {
                        id: filterTabsRow
                        anchors.centerIn: parent
                        spacing: 3

                        // 1. Píldora: Estáticos (Static)
                        Rectangle {
                            height: 22
                            width: staticRow.implicitWidth + 16
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.activeFilter === "static" 
                                   ? (root.theme ? root.theme.accent : "#00ffcc") 
                                   : (staticMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                id: staticRow
                                anchors.centerIn: parent
                                spacing: 5

                                // Icono Vectorial Foto / Paisaje
                                Canvas {
                                    id: staticIconCanvas
                                    width: 13
                                    height: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    property color strokeCol: root.activeFilter === "static" ? "#0d1117" : (root.theme ? root.theme.text : "#f0f6fc")
                                    onStrokeColChanged: requestPaint()
                                    Component.onCompleted: requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.strokeStyle = strokeCol;
                                        ctx.fillStyle = strokeCol;
                                        ctx.lineWidth = 1.2;
                                        ctx.lineJoin = "round";
                                        ctx.lineCap = "round";
                                        // Marco
                                        ctx.strokeRect(0.8, 0.8, 11.4, 9.4);
                                        // Sol / Punto
                                        ctx.beginPath();
                                        ctx.arc(3.6, 3.6, 1.1, 0, Math.PI * 2);
                                        ctx.fill();
                                        // Montañas
                                        ctx.beginPath();
                                        ctx.moveTo(1.8, 8.5);
                                        ctx.lineTo(4.8, 4.8);
                                        ctx.lineTo(7.2, 7.2);
                                        ctx.lineTo(9.2, 5.2);
                                        ctx.lineTo(11.2, 7.8);
                                        ctx.stroke();
                                    }
                                }

                                Text {
                                    text: "Static"
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.activeFilter === "static" ? "#0d1117" : (root.theme ? root.theme.text : "#f0f6fc")
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: staticMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeFilter = (root.activeFilter === "static") ? "all" : "static";
                                }
                            }
                        }

                        // 2. Píldora: Animados (Animated / Clapperboard)
                        Rectangle {
                            height: 22
                            width: animRow.implicitWidth + 16
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.activeFilter === "animated" 
                                   ? (root.theme ? root.theme.accentAlt : "#bd93f9") 
                                   : (animMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                id: animRow
                                anchors.centerIn: parent
                                spacing: 5

                                // Icono Vectorial Claqueta de Cine
                                Canvas {
                                    id: animIconCanvas
                                    width: 13
                                    height: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    property color strokeCol: root.activeFilter === "animated" ? "#0d1117" : (root.theme ? root.theme.text : "#f0f6fc")
                                    onStrokeColChanged: requestPaint()
                                    Component.onCompleted: requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.strokeStyle = strokeCol;
                                        ctx.fillStyle = strokeCol;
                                        ctx.lineWidth = 1.1;
                                        ctx.lineJoin = "round";
                                        ctx.lineCap = "round";
                                        // Barra superior
                                        ctx.strokeRect(0.8, 0.8, 11.4, 3.2);
                                        // Base claqueta
                                        ctx.strokeRect(0.8, 4.6, 11.4, 5.6);
                                        // Rayas diagonales superiores
                                        ctx.beginPath();
                                        ctx.moveTo(3.6, 0.8); ctx.lineTo(2.4, 4.0);
                                        ctx.moveTo(6.8, 0.8); ctx.lineTo(5.6, 4.0);
                                        ctx.moveTo(10.0, 0.8); ctx.lineTo(8.8, 4.0);
                                        ctx.stroke();
                                    }
                                }

                                Text {
                                    text: "Animated"
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.activeFilter === "animated" ? "#0d1117" : (root.theme ? root.theme.text : "#f0f6fc")
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: animMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeFilter = (root.activeFilter === "animated") ? "all" : "animated";
                                }
                            }
                        }

                        // 3. Píldora: Aleatorio (Random Shuffle)
                        Rectangle {
                            height: 22
                            width: randRow.implicitWidth + 14
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: randMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                id: randRow
                                anchors.centerIn: parent
                                spacing: 4

                                Canvas {
                                    id: randCanvas
                                    width: 12
                                    height: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    property color strokeCol: randMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#6e7681")
                                    onStrokeColChanged: requestPaint()
                                    Component.onCompleted: requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.strokeStyle = strokeCol;
                                        ctx.fillStyle = strokeCol;
                                        ctx.lineWidth = 1.2;
                                        ctx.lineCap = "round";
                                        ctx.lineJoin = "round";
                                        // Flechas cruzadas
                                        ctx.beginPath();
                                        ctx.moveTo(1.5, 3.5); ctx.lineTo(4.5, 3.5); ctx.lineTo(7.5, 8.5); ctx.lineTo(10.5, 8.5);
                                        ctx.moveTo(1.5, 8.5); ctx.lineTo(4.5, 8.5); ctx.lineTo(7.5, 3.5); ctx.lineTo(10.5, 3.5);
                                        ctx.stroke();
                                        // Puntas
                                        ctx.beginPath();
                                        ctx.moveTo(8.5, 2.0); ctx.lineTo(10.8, 3.5); ctx.lineTo(8.5, 5.0);
                                        ctx.moveTo(8.5, 7.0); ctx.lineTo(10.8, 8.5); ctx.lineTo(8.5, 10.0);
                                        ctx.stroke();
                                    }
                                }

                                Text {
                                    text: "Random"
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: randMouse.containsMouse ? (root.theme ? root.theme.text : "#ffffff") : (root.theme ? root.theme.textDim : "#6e7681")
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: randMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyRandom()
                            }
                        }

                        // 4. Píldora: Actualizar (Refresh)
                        Rectangle {
                            height: 22
                            width: refreshRow.implicitWidth + 14
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: refreshMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                id: refreshRow
                                anchors.centerIn: parent
                                spacing: 4

                                Item {
                                    id: refreshIconContainer
                                    width: 12
                                    height: 12
                                    anchors.verticalCenter: parent.verticalCenter

                                    Canvas {
                                        id: refreshCanvas
                                        anchors.fill: parent
                                        property color strokeCol: refreshMouse.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#6e7681")
                                        onStrokeColChanged: requestPaint()
                                        Component.onCompleted: requestPaint()

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = strokeCol;
                                            ctx.fillStyle = strokeCol;
                                            ctx.lineWidth = 1.3;
                                            ctx.lineCap = "round";
                                            // Arco circular
                                            ctx.beginPath();
                                            ctx.arc(6, 6, 4.2, -Math.PI * 0.7, Math.PI * 0.85);
                                            ctx.stroke();
                                            // Flecha
                                            ctx.beginPath();
                                            ctx.moveTo(5.2, 0.6);
                                            ctx.lineTo(8.5, 2.0);
                                            ctx.lineTo(5.8, 3.8);
                                            ctx.fill();
                                        }
                                    }

                                    RotationAnimation on rotation {
                                        id: refreshRotation
                                        running: false
                                        loops: 1
                                        from: 0
                                        to: 360
                                        duration: 600
                                        easing.type: Easing.OutBack
                                    }
                                }

                                Text {
                                    text: "Refresh"
                                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: refreshMouse.containsMouse ? (root.theme ? root.theme.text : "#ffffff") : (root.theme ? root.theme.textDim : "#6e7681")
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: refreshMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.refresh()
                            }
                        }
                    }
                }

                // Botón Cerrar (X Minimalista Vectorial a la derecha)
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: closeMouse.containsMouse ? (root.theme ? root.theme.danger : "#ff5555") : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: closeMouse.containsMouse ? "transparent" : Qt.rgba(1, 1, 1, 0.08)

                    scale: closeMouse.containsMouse ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 140 } }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Canvas {
                        id: closeCanvas
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        rotation: closeMouse.containsMouse ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                        property color strokeCol: closeMouse.containsMouse ? "#ffffff" : (root.theme ? root.theme.textDim : "#6e7681")
                        onStrokeColChanged: requestPaint()
                        Component.onCompleted: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.strokeStyle = strokeCol;
                            ctx.lineWidth = 1.4;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.moveTo(1.5, 1.5); ctx.lineTo(8.5, 8.5);
                            ctx.moveTo(8.5, 1.5); ctx.lineTo(1.5, 8.5);
                            ctx.stroke();
                        }
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            // ==========================================
            // Carrusel CoverFlow 3D Neón (Modo Dev / Programación - Imagen 2)
            // ==========================================
            Item {
                id: coverFlowContainer
                Layout.fillWidth: true
                Layout.preferredHeight: (root.barStyle === "deck") ? 190 : 0
                visible: root.barStyle === "deck"
                clip: true

                PathView {
                    id: coverFlowView
                    anchors.fill: parent
                    model: root.filteredWallpapers
                    pathItemCount: Math.min(7, Math.max(1, root.filteredWallpapers.length))
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    interactive: true
                    clip: false

                    // Desplazamiento por rueda de ratón en Coverflow
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y < 0) {
                                coverFlowView.incrementCurrentIndex();
                            } else if (wheel.angleDelta.y > 0) {
                                coverFlowView.decrementCurrentIndex();
                            }
                        }
                    }

                    path: Path {
                        startX: 70
                        startY: coverFlowContainer.height / 2 - 12

                        PathAttribute { name: "itemZ"; value: 10 }
                        PathAttribute { name: "itemScale"; value: 0.78 }
                        PathAttribute { name: "itemAngle"; value: 34 }
                        PathAttribute { name: "itemOpacity"; value: 0.55 }

                        PathLine {
                            x: coverFlowContainer.width / 2
                            y: coverFlowContainer.height / 2 - 12
                        }

                        PathAttribute { name: "itemZ"; value: 100 }
                        PathAttribute { name: "itemScale"; value: 1.25 }
                        PathAttribute { name: "itemAngle"; value: 0 }
                        PathAttribute { name: "itemOpacity"; value: 1.0 }

                        PathLine {
                            x: coverFlowContainer.width - 70
                            y: coverFlowContainer.height / 2 - 12
                        }

                        PathAttribute { name: "itemZ"; value: 10 }
                        PathAttribute { name: "itemScale"; value: 0.78 }
                        PathAttribute { name: "itemAngle"; value: -34 }
                        PathAttribute { name: "itemOpacity"; value: 0.55 }
                    }

                    delegate: Item {
                        id: flowCard
                        width: 200
                        height: 115
                        z: PathView.itemZ !== undefined ? PathView.itemZ : 0
                        scale: PathView.itemScale !== undefined ? PathView.itemScale : 1.0
                        opacity: PathView.itemOpacity !== undefined ? PathView.itemOpacity : 1.0

                        readonly property bool isCurrent: PathView.isCurrentItem
                        readonly property var itemData: modelData
                        readonly property bool isSelected: root.selectedPath === itemData.path
                        readonly property bool isJustApplied: root.justAppliedPath === itemData.path

                        transform: Rotation {
                            origin.x: flowCard.width / 2
                            origin.y: flowCard.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: PathView.itemAngle !== undefined ? PathView.itemAngle : 0
                        }

                        // Anillo Exterior Resplandeciente Neón (Magenta / Naranja Neón como en la Ref 2)
                        Rectangle {
                            visible: flowCard.isCurrent
                            anchors.fill: parent
                            anchors.margins: -7
                            radius: 17
                            color: "transparent"
                            border.width: 2
                            border.color: flowCard.isSelected ? "#00ffcc" : "#ff5577"
                            opacity: 0.85

                            SequentialAnimation on opacity {
                                running: flowCard.isCurrent
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.50; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.95; duration: 900; easing.type: Easing.InOutSine }
                            }
                        }

                        // Anillo Interior Neón Cian Concéntrico
                        Rectangle {
                            visible: flowCard.isCurrent
                            anchors.fill: parent
                            anchors.margins: -3.5
                            radius: 14
                            color: "transparent"
                            border.width: 1.5
                            border.color: flowCard.isSelected ? "#50fa7b" : "#00ffcc"
                        }

                        // Tarjeta Principal con la Miniatura
                        Rectangle {
                            id: flowPreviewBox
                            anchors.fill: parent
                            radius: 11
                            clip: true
                            color: "#161b22"
                            border.width: flowCard.isCurrent ? 2 : 1
                            border.color: flowCard.isCurrent ? "#00ffcc" : Qt.rgba(1, 1, 1, 0.15)

                            Image {
                                anchors.fill: parent
                                source: itemData.thumb
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                            }

                            // Sombreado en tarjetas laterales
                            Rectangle {
                                anchors.fill: parent
                                color: "#000000"
                                opacity: flowCard.isCurrent ? 0.0 : 0.40
                            }

                            // Badge de Formato en esquina superior derecha
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 5
                                height: 14
                                width: flowBadgeRow.implicitWidth + 8
                                radius: 4
                                color: Qt.rgba(0, 0, 0, 0.75)
                                border.width: 0.5
                                border.color: Qt.rgba(255, 255, 255, 0.2)

                                Row {
                                    id: flowBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        text: itemData.ext.toUpperCase()
                                        font.family: "JetBrains Mono Nerd Font, monospace"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: itemData.type === "animated" ? "#bd93f9" : "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Badge de Aplicado / Activo
                            Rectangle {
                                visible: flowCard.isSelected
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 5
                                height: 16
                                width: flowActiveRow.implicitWidth + 8
                                radius: 8
                                color: flowCard.isJustApplied ? "#50fa7b" : "#00ffcc"

                                Row {
                                    id: flowActiveRow
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        text: flowCard.isJustApplied ? "APPLIED" : "ACTIVE"
                                        font.family: "JetBrains Mono Nerd Font, monospace"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#0d1117"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // ==========================================
                        // Píldora de Etiqueta Flotante Inferior (Imagen 2: "pastel-window")
                        // ==========================================
                        Item {
                            visible: flowCard.isCurrent
                            anchors.top: flowCard.bottom
                            anchors.topMargin: 11
                            anchors.horizontalCenter: flowCard.horizontalCenter
                            width: labelCapsule.width
                            height: labelCapsule.height
                            z: 250

                            Rectangle {
                                id: labelCapsule
                                width: labelRow.implicitWidth + 24
                                height: 25
                                radius: 12.5
                                color: "#f00d1117"
                                border.width: 1
                                border.color: flowCard.isSelected ? "#00ffcc" : Qt.rgba(255, 85, 119, 0.5)

                                Row {
                                    id: labelRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    // Indicador LED de foco
                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: flowCard.isSelected ? "#50fa7b" : (flowCard.itemData.type === "animated" ? "#bd93f9" : "#00ffcc")
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Nombre del fondo sin extensión
                                    Text {
                                        text: flowCard.itemData.name.replace(/\.[^/.]+$/, "")
                                        font.family: "JetBrains Mono Nerd Font, monospace"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#f0f6fc"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Clic interactivo: centrar o aplicar
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (flowCard.isCurrent) {
                                    root.applyWallpaper(flowCard.itemData.path);
                                } else {
                                    coverFlowView.currentIndex = index;
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // Carrusel Horizontal Plano (Modo Diario / Zen - Lista)
            // ==========================================
            ListView {
                id: wallpaperList
                Layout.fillWidth: true
                Layout.preferredHeight: (root.barStyle === "island") ? 132 : 0
                visible: root.barStyle === "island"
                orientation: ListView.Horizontal
                spacing: 14
                clip: true
                model: root.filteredWallpapers

                // Desplazamiento horizontal fluido con la rueda del ratón
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        if (wheel.angleDelta.y < 0) {
                            wallpaperList.flick(-750, 0);
                        } else if (wheel.angleDelta.y > 0) {
                            wallpaperList.flick(750, 0);
                        }
                    }
                }

                delegate: Item {
                    id: cardItem
                    width: 172
                    height: 128
                    readonly property var itemData: modelData
                    readonly property bool isSelected: root.selectedPath === itemData.path
                    readonly property bool isJustApplied: root.justAppliedPath === itemData.path
                    readonly property bool isHovered: cardMouse.containsMouse
                    readonly property bool isCurrent: wallpaperList.currentIndex === index

                    // Elevación dinámica suave al posar el ratón o navegar con teclado
                    y: (cardItem.isHovered || cardItem.isCurrent) ? -5 : 0
                    Behavior on y {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Column {
                        anchors.fill: parent
                        spacing: 4

                        // Tarjeta de Vista Previa Frosted
                        Rectangle {
                            id: previewBox
                            width: 172
                            height: 104
                            radius: 12
                            clip: true
                            color: "#161b22"

                            // Borde neón activo cuando está seleccionado, enfocado o con hover
                            border.width: (cardItem.isSelected || cardItem.isHovered || cardItem.isCurrent) ? 2 : 1
                            border.color: cardItem.isSelected 
                                          ? (root.theme ? root.theme.accent : "#00ffcc")
                                          : ((cardItem.isHovered || cardItem.isCurrent) 
                                             ? (root.theme ? root.theme.accentAlt : "#bd93f9") 
                                             : Qt.rgba(1, 1, 1, 0.12))

                            scale: (cardItem.isHovered || cardItem.isCurrent) ? 1.04 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }

                            // Imagen de miniatura generada en caché
                            Image {
                                anchors.fill: parent
                                source: itemData.thumb
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                            }

                            // Capa de oscurecimiento suave para resaltar detalles
                            Rectangle {
                                anchors.fill: parent
                                color: "#000000"
                                opacity: cardItem.isHovered ? 0.15 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            // Etiqueta Superior de Formato / Tipo Vectorial
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                height: 16
                                width: badgeRow.implicitWidth + 8
                                radius: 4
                                color: Qt.rgba(0, 0, 0, 0.70)
                                border.width: 0.5
                                border.color: Qt.rgba(255, 255, 255, 0.18)

                                Row {
                                    id: badgeRow
                                    anchors.centerIn: parent
                                    spacing: 3

                                    // Triángulo vectorial de vídeo para archivos animados
                                    Canvas {
                                        visible: itemData.type === "animated"
                                        width: 7
                                        height: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.fillStyle = root.theme ? root.theme.accentAlt : "#bd93f9";
                                            ctx.beginPath();
                                            ctx.moveTo(1.0, 0.8);
                                            ctx.lineTo(6.5, 3.5);
                                            ctx.lineTo(1.0, 6.2);
                                            ctx.fill();
                                        }
                                    }

                                    Text {
                                        text: itemData.ext
                                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: itemData.type === "animated" 
                                               ? (root.theme ? root.theme.accentAlt : "#bd93f9") 
                                               : "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Chip Dinámico "APPLY" que aparece al pasar el ratón
                            Rectangle {
                                anchors.centerIn: parent
                                width: 62
                                height: 22
                                radius: 11
                                color: Qt.rgba(0, 0, 0, 0.75)
                                border.width: 1
                                border.color: root.theme ? root.theme.accent : "#00ffcc"
                                opacity: (cardItem.isHovered && !cardItem.isSelected) ? 1.0 : 0.0
                                scale: opacity > 0 ? 1.0 : 0.8
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "APPLY"
                                    font.family: root.theme ? root.theme.fontFamily : "monospace"
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: root.theme ? root.theme.accent : "#00ffcc"
                                }
                            }

                            // Indicador de Wallpaper Activo (Píldora Neón con Checkmark)
                            Rectangle {
                                visible: cardItem.isSelected
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 6
                                height: 18
                                width: activeBadgeRow.implicitWidth + 10
                                radius: 9
                                color: cardItem.isJustApplied ? (root.theme ? root.theme.cpuColor : "#50fa7b") : (root.theme ? root.theme.accent : "#00ffcc")

                                Behavior on color { ColorAnimation { duration: 250 } }

                                Row {
                                    id: activeBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 3

                                    // Vector Checkmark nítido
                                    Canvas {
                                        width: 8
                                        height: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = "#0d1117";
                                            ctx.lineWidth = 1.4;
                                            ctx.lineCap = "round";
                                            ctx.lineJoin = "round";
                                            ctx.beginPath();
                                            ctx.moveTo(1.2, 4.2);
                                            ctx.lineTo(3.2, 6.5);
                                            ctx.lineTo(6.8, 1.5);
                                            ctx.stroke();
                                        }
                                    }

                                    Text {
                                        text: cardItem.isJustApplied ? "APPLIED" : "ACTIVE"
                                        font.family: root.theme ? root.theme.fontFamily : "monospace"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#0d1117"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.applyWallpaper(itemData.path);
                                }
                            }
                        }

                        // Título del Wallpaper elidido con color dinámico
                        Text {
                            width: parent.width
                            text: itemData.name
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: cardItem.isSelected
                            color: cardItem.isSelected 
                                   ? (root.theme ? root.theme.accent : "#00ffcc") 
                                   : (cardItem.isHovered ? "#ffffff" : (root.theme ? root.theme.textDim : "#8b949e"))
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // ==========================================
            // Barra de Búsqueda Inferior con Vector Lupa y Clear
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.45)
                    border.width: 1
                    border.color: searchInput.activeFocus ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(1, 1, 1, 0.08)

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        // Icono Vectorial Lupa
                        Canvas {
                            id: searchLensCanvas
                            width: 13
                            height: 13
                            Layout.alignment: Qt.AlignVCenter
                            property color strokeCol: searchInput.activeFocus 
                                                      ? (root.theme ? root.theme.accent : "#00ffcc") 
                                                      : (root.theme ? root.theme.textDim : "#6e7681")
                            onStrokeColChanged: requestPaint()
                            Component.onCompleted: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.strokeStyle = strokeCol;
                                ctx.lineWidth = 1.3;
                                ctx.lineCap = "round";
                                // Lente circular
                                ctx.beginPath();
                                ctx.arc(5.0, 5.0, 3.4, 0, Math.PI * 2);
                                ctx.stroke();
                                // Mango diagonal
                                ctx.beginPath();
                                ctx.moveTo(7.6, 7.6);
                                ctx.lineTo(11.4, 11.4);
                                ctx.stroke();
                            }
                        }

                        // Prefijo Prompt estilo Hacker
                        Text {
                            text: ">wallpaper"
                            font.family: root.theme ? root.theme.fontFamily : "monospace"
                            font.pixelSize: 10
                            font.bold: true
                            color: root.theme ? root.theme.accent : "#00ffcc"
                            opacity: 0.85
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Campo de texto interactivo
                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 10
                            color: "#ffffff"
                            selectByMouse: true
                            text: root.searchQuery
                            onTextChanged: root.searchQuery = text

                            Keys.onEscapePressed: {
                                if (text.length > 0) {
                                    text = "";
                                } else {
                                    root.closeRequested();
                                }
                            }

                            Keys.onRightPressed: {
                                if (root.barStyle === "deck") {
                                    if (coverFlowView.count > 0) coverFlowView.incrementCurrentIndex();
                                } else {
                                    if (wallpaperList.count > 0) {
                                        wallpaperList.currentIndex = (wallpaperList.currentIndex + 1) % wallpaperList.count;
                                        wallpaperList.positionViewAtIndex(wallpaperList.currentIndex, ListView.Contain);
                                    }
                                }
                            }

                            Keys.onLeftPressed: {
                                if (root.barStyle === "deck") {
                                    if (coverFlowView.count > 0) coverFlowView.decrementCurrentIndex();
                                } else {
                                    if (wallpaperList.count > 0) {
                                        wallpaperList.currentIndex = (wallpaperList.currentIndex - 1 + wallpaperList.count) % wallpaperList.count;
                                        wallpaperList.positionViewAtIndex(wallpaperList.currentIndex, ListView.Contain);
                                    }
                                }
                            }

                            Keys.onReturnPressed: {
                                if (root.barStyle === "deck") {
                                    if (coverFlowView.count > 0 && coverFlowView.currentIndex >= 0 && coverFlowView.currentIndex < coverFlowView.count) {
                                        root.applyWallpaper(root.filteredWallpapers[coverFlowView.currentIndex].path);
                                    }
                                } else {
                                    if (wallpaperList.count > 0 && wallpaperList.currentIndex >= 0 && wallpaperList.currentIndex < wallpaperList.count) {
                                        root.applyWallpaper(root.filteredWallpapers[wallpaperList.currentIndex].path);
                                    } else if (root.filteredWallpapers.length > 0) {
                                        root.applyWallpaper(root.filteredWallpapers[0].path);
                                    }
                                }
                            }

                            Text {
                                text: "buscar por nombre..."
                                font.family: parent.font.family
                                font.pixelSize: parent.font.pixelSize
                                color: Qt.rgba(1, 1, 1, 0.30)
                                visible: parent.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Botón de Borrado Rápido (Clear X)
                        Rectangle {
                            visible: searchInput.text.length > 0
                            width: 16
                            height: 16
                            radius: 8
                            color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 8
                                font.bold: true
                                color: root.theme ? root.theme.textDim : "#8b949e"
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchInput.text = ""
                            }
                        }

                        // Contador dinámico de resultados
                        Text {
                            text: root.filteredWallpapers.length + " encontrados"
                            font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            color: root.theme ? root.theme.textDim : "#6e7681"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
