import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * DesktopClock.qml
 * Reloj de escritorio estético estilo Retro Vintage / Material You
 * con diseño idéntico al widget de referencia:
 * - Color de fondo verde bosque profundo (#1D3D37)
 * - Dígitos en tono melocotón cálido (#F9B49E) en tipografía redondeada gruesa (Outfit)
 * - Dos puntos del segundero en crema pastel suave (#B7CEC4)
 * - Separador vertical dorado suave (#D8BC9D)
 * - Bloque de fecha con Mes (AUGUST), Día (31) y Día de la semana (Monday)
 * - ARRASTRABLE libremente por la pantalla con el ratón
 * - Persistencia de posición y preferencias en ~/.config/quickshell/clock_config.json
 * - Menú interactivo de opciones (bloqueo, idioma, formato 12/24h, temas, escala)
 */
Item {
    id: root

    property var theme
    property real screenWidth: 1920
    property real screenHeight: 1080

    // Posición y estado editable
    property real clockX: 100
    property real clockY: 140
    property bool isLocked: false
    property string clockTheme: "retro"      // "retro", "pywal", "cyberpunk", "cream"
    property string clockLang: "en"         // "en" (como la foto) o "es"
    property bool is24h: true
    property bool layerOnTop: false
    property real scaleFactor: 1.0
    property bool settingsOpen: false

    // Referencia de la región interactiva para el PanelWindow
    readonly property Item hitboxItem: cardWrapper

    // Tipografía pesada estática de alta calidad
    FontLoader {
        id: heavyFont
        source: Qt.resolvedUrl("../fonts/OpenSans-ExtraBold.ttf")
    }

    readonly property string mainFont: heavyFont.name ? heavyFont.name : "Open Sans, sans-serif"

    // Reloj del sistema reactivo
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

    // Traducciones de Mes y Día
    readonly property var monthsEN: [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
    ]
    readonly property var monthsES: [
        "ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO",
        "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"
    ]
    readonly property var daysEN: [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]
    readonly property var daysES: [
        "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"
    ]

    // Formateo de Horas y Minutos
    readonly property string hoursStr: {
        var d = sysClock.date;
        var h = d.getHours();
        if (!root.is24h) {
            h = h % 12;
            if (h === 0) h = 12;
            return (h < 10 ? "0" : "") + h;
        }
        return (h < 10 ? "0" : "") + h;
    }

    readonly property string minutesStr: {
        var m = sysClock.date.getMinutes();
        return (m < 10 ? "0" : "") + m;
    }

    readonly property string monthStr: {
        var m = sysClock.date.getMonth();
        return root.clockLang === "es" ? monthsES[m] : monthsEN[m];
    }

    readonly property string dayNumberStr: {
        return "" + sysClock.date.getDate();
    }

    readonly property string dayOfWeekStr: {
        var d = sysClock.date.getDay();
        return root.clockLang === "es" ? daysES[d] : daysEN[d];
    }
    
    readonly property string secondsStr: {
       return String(sysClock.date.getSeconds()).padStart(2, '0');
    }

    // Paletas de Color
    readonly property color bgColor: {
        if (root.clockTheme === "pywal" && root.theme && root.theme.pywalLoaded) return root.theme.backgroundSolid;
        if (root.clockTheme === "cyberpunk") return "#0d1117";
        if (root.clockTheme === "cream") return "#f5ebe0";
        return "#1D3D37"; // Retro Forest exacto a la imagen
    }

    readonly property color bgBorderColor: {
        if (root.clockTheme === "pywal" && root.theme) return root.theme.borderSubtle;
        if (root.clockTheme === "cyberpunk") return Qt.rgba(0, 1, 0.8, 0.4);
        if (root.clockTheme === "cream") return "#e3d5ca";
        return "#142C27"; // Borde musgo sutil
    }

    readonly property color digitsColor: {
        if (root.clockTheme === "pywal" && root.theme && root.theme.pywalLoaded) return root.theme.accent;
        if (root.clockTheme === "cyberpunk") return "#00ffcc";
        if (root.clockTheme === "cream") return "#4a4036";
        return "#F9B49E"; // Melocotón cálido exacto a la imagen
    }
    readonly property color secondsColor: {
        if (root.clockTheme === "pywal" && root.theme && root.theme.pywalLoaded) return root.theme.accent;
        if (root.clockTheme === "cyberpunk") return "#ff0000";
        if (root.clockTheme === "cream") return "#4a4036";
        return "#F9B49E"; // Melocotón cálido exacto a la imagen
    }

    readonly property color colonColor: {
        if (root.clockTheme === "pywal" && root.theme && root.theme.pywalLoaded) return root.theme.accentAlt;
        if (root.clockTheme === "cyberpunk") return "#bd93f9";
        if (root.clockTheme === "cream") return "#9c8974";
        return "#B7CEC4"; // Crema salvia pastel exacto a la imagen
    }

    readonly property color dividerColor: {
        if (root.clockTheme === "pywal" && root.theme) return root.theme.borderSubtle;
        if (root.clockTheme === "cyberpunk") return Qt.rgba(0, 1, 0.8, 0.3);
        if (root.clockTheme === "cream") return "#d5bdaf";
        return "#D8BC9D"; // Dorado arena suave exacto a la imagen
    }

    readonly property color dayOfWeekColor: {
        if (root.clockTheme === "pywal" && root.theme && root.theme.pywalLoaded) return root.theme.textDim;
        if (root.clockTheme === "cyberpunk") return "#8be9fd";
        if (root.clockTheme === "cream") return "#7f6a55";
        return "#9FBDB2"; // Salvia apagado exacto a la imagen
    }

    // Proceso de carga inicial de configuración
    Process {
        id: loadConfigProc
        command: ["cat", Quickshell.env("HOME") + "/.config/quickshell/clock_config.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    if (data.x !== undefined) root.clockX = Math.max(10, Math.min(root.screenWidth - 340, data.x));
                    if (data.y !== undefined) root.clockY = Math.max(10, Math.min(root.screenHeight - 140, data.y));
                    if (data.locked !== undefined) root.isLocked = !!data.locked;
                    if (data.theme) root.clockTheme = data.theme;
                    if (data.language) root.clockLang = data.language;
                    if (data.is24h !== undefined) root.is24h = !!data.is24h;
                    if (data.layerTop !== undefined) root.layerOnTop = !!data.layerTop;
                    if (data.scale !== undefined) root.scaleFactor = Math.max(0.7, Math.min(1.5, data.scale));
                } catch (e) {}
            }
        }
    }

    // Proceso de guardado
    Process {
        id: saveConfigProc
        command: []
        running: false
    }

    function saveSettings() {
        var cfg = {
            "x": Math.round(root.clockX),
            "y": Math.round(root.clockY),
            "locked": root.isLocked,
            "theme": root.clockTheme,
            "language": root.clockLang,
            "is24h": root.is24h,
            "layerTop": root.layerOnTop,
            "scale": root.scaleFactor
        };
        saveConfigProc.command = [
            Quickshell.env("HOME") + "/.config/quickshell/scripts/save_clock_config.py",
            JSON.stringify(cfg)
        ];
        saveConfigProc.running = true;
    }

    // ==========================================
    // Contenedor del Widget y Región Interactiva
    // ==========================================
    Item {
        id: cardWrapper
        x: root.clockX
        y: root.clockY
        width: clockCard.width
        height: root.settingsOpen ? (clockCard.height + settingsCard.height + 12) : clockCard.height

        // Sombra de elevación suave estilo vintage
        Rectangle {
            anchors.fill: clockCard
            anchors.margins: -4
            radius: clockCard.radius + 4
            color: "transparent"
            border.width: 1
            border.color: dragArea.drag.active ? (root.theme ? root.theme.accent : "#00ffcc") : "transparent"
            opacity: dragArea.drag.active ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        // ==========================================
        // Tarjeta Principal del Reloj
        // ==========================================
        Rectangle {
            id: clockCard
            width: 318 * root.scaleFactor
            height: 106 * root.scaleFactor
            radius: 20 * root.scaleFactor
            color: root.bgColor
            border.width: 1.5
            border.color: root.bgBorderColor

            // Sombra interna sutil
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)
            }

            // Contenido interior
            Row {
                anchors.centerIn: parent
                spacing: 0

                // 1. Horas y Minutos con Colon central
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7 * root.scaleFactor

                    // Horas (Tipografía ExtraBold pesada)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.hoursStr
                        font.family: root.mainFont
                        font.pixelSize: Math.round(56 * root.scaleFactor)
                        font.bold: true
                        font.weight: Font.ExtraBold
                        color: root.digitsColor
                    }

                    // Colon estilizado en crema salvia (2 cuadrados redondeados idénticos a la foto)
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12 * root.scaleFactor

                        Rectangle {
                            width: 7 * root.scaleFactor
                            height: 7 * root.scaleFactor
                            radius: 2 * root.scaleFactor
                            color: root.colonColor
                        }

                        Rectangle {
                            width: 7 * root.scaleFactor
                            height: 7 * root.scaleFactor
                            radius: 2 * root.scaleFactor
                            color: root.colonColor
                        }
                    }

                    // Minutos (Tipografía ExtraBold pesada)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.minutesStr
                        font.family: root.mainFont
                        font.pixelSize: Math.round(56 * root.scaleFactor)
                        font.bold: true
                        font.weight: Font.ExtraBold
                        color: root.digitsColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.secondsStr
                        font.family: root.mainFont
                        font.pixelSize: Math.round(22 * root.scaleFactor)
                        font.bold: true
                        font.weight: Font.ExtraBold
                        color: root.secondsColor
                    }
                }

                // Espaciador antes del divisor
                Item {
                    width: 18 * root.scaleFactor
                    height: 1
                }

                // 2. Línea Divisoria Vertical
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2 * root.scaleFactor
                    height: 54 * root.scaleFactor
                    radius: 1
                    color: root.dividerColor
                }

                // Espaciador después del divisor
                Item {
                    width: 16 * root.scaleFactor
                    height: 1
                }

                // 3. Bloque de Fecha (Mes, Día, Día de la semana)
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.scaleFactor

                    // Mes (ej. OCTOBER)
                    Text {
                        text: root.monthStr
                        font.family: root.mainFont
                        font.pixelSize: Math.round(11 * root.scaleFactor)
                        font.bold: true
                        font.weight: Font.Bold
                        font.letterSpacing: 2.2 * root.scaleFactor
                        color: root.digitsColor
                    }

                    // Día numérico (ej. 8)
                    Text {
                        text: root.dayNumberStr
                        font.family: root.mainFont
                        font.pixelSize: Math.round(28 * root.scaleFactor)
                        font.bold: true
                        font.weight: Font.ExtraBold
                        color: root.digitsColor
                    }

                    // Día de la semana (ej. Thursday)
                    Text {
                        text: root.dayOfWeekStr
                        font.family: root.mainFont
                        font.pixelSize: Math.round(11 * root.scaleFactor)
                        font.weight: Font.DemiBold
                        color: root.dayOfWeekColor
                    }
                }
            }

            // ==========================================
            // Mini Barra de Herramientas flotante al pasar el ratón
            // ==========================================
            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 6
                anchors.rightMargin: 8
                spacing: 4
                opacity: (dragArea.containsMouse || root.settingsOpen) ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 160 }
                }

                // Botón Bloquear / Desbloquear movimiento
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: root.isLocked ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 255, 204, 0.25)
                    border.width: 1
                    border.color: root.isLocked ? Qt.rgba(1, 1, 1, 0.15) : (root.theme ? root.theme.accent : "#00ffcc")

                    Text {
                        anchors.centerIn: parent
                        text: root.isLocked ? "🔒" : "🔓"
                        font.pixelSize: 9
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isLocked = !root.isLocked;
                            root.saveSettings();
                        }
                    }
                }

                // Botón Ajustes / Configuración
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: root.settingsOpen ? (root.theme ? root.theme.accent : "#00ffcc") : Qt.rgba(0, 0, 0, 0.45)
                    border.width: 1
                    border.color: root.settingsOpen ? "#ffffff" : Qt.rgba(1, 1, 1, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        font.pixelSize: 10
                        color: root.settingsOpen ? "#0d1117" : "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.settingsOpen = !root.settingsOpen;
                        }
                    }
                }
            }

            // ==========================================
            // Área de Arrastre Interactivo (Drag & Drop)
            // ==========================================
            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: root.isLocked 
                             ? Qt.ArrowCursor 
                             : (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor)

                drag.target: root.isLocked ? null : cardWrapper
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 10
                drag.maximumX: Math.max(10, root.screenWidth - clockCard.width - 10)
                drag.minimumY: 10
                drag.maximumY: Math.max(10, root.screenHeight - clockCard.height - 10)

                onReleased: {
                    if (!root.isLocked) {
                        root.clockX = cardWrapper.x;
                        root.clockY = cardWrapper.y;
                        root.saveSettings();
                    }
                }

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        root.settingsOpen = !root.settingsOpen;
                    }
                }
            }
        }

        // ==========================================
        // Tarjeta Desplegable de Ajustes (Settings)
        // ==========================================
        Rectangle {
            id: settingsCard
            visible: root.settingsOpen
            anchors.top: clockCard.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: clockCard.horizontalCenter
            width: Math.max(290, clockCard.width)
            height: 168
            radius: 14
            color: "#162D27"
            border.width: 1.2
            border.color: root.dividerColor
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                // Cabecera del menú
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Desktop Clock Settings"
                        font.family: root.mainFont
                        font.pixelSize: 10
                        font.bold: true
                        color: root.digitsColor
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "✕"
                        font.pixelSize: 10
                        font.bold: true
                        color: root.dayOfWeekColor
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.settingsOpen = false
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                // 1. Fila: Tema de Color
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "Theme:"
                        font.pixelSize: 9
                        color: root.dayOfWeekColor
                        Layout.preferredWidth: 46
                    }

                    Repeater {
                        model: [
                            { id: "retro", label: "Forest" },
                            { id: "pywal", label: "Pywal" },
                            { id: "cyberpunk", label: "Cyber" },
                            { id: "cream", label: "Sand" }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 18
                            radius: 4
                            color: root.clockTheme === modelData.id ? root.digitsColor : Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1
                            border.color: root.clockTheme === modelData.id ? "#ffffff" : Qt.rgba(1, 1, 1, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 8
                                font.bold: root.clockTheme === modelData.id
                                color: root.clockTheme === modelData.id ? "#162D27" : "#f0f6fc"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.clockTheme = modelData.id;
                                    root.saveSettings();
                                }
                            }
                        }
                    }
                }

                // 2. Fila: Idioma y Formato Horario
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Idioma
                    RowLayout {
                        spacing: 3
                        Text {
                            text: "Language:"
                            font.pixelSize: 9
                            color: root.dayOfWeekColor
                        }
                        Rectangle {
                            width: 32; height: 18; radius: 4
                            color: root.clockLang === "en" ? root.digitsColor : Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                            Text {
                                anchors.centerIn: parent; text: "EN"; font.pixelSize: 8; font.bold: true
                                color: root.clockLang === "en" ? "#162D27" : "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.clockLang = "en"; root.saveSettings(); }
                            }
                        }
                        Rectangle {
                            width: 32; height: 18; radius: 4
                            color: root.clockLang === "es" ? root.digitsColor : Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                            Text {
                                anchors.centerIn: parent; text: "ES"; font.pixelSize: 8; font.bold: true
                                color: root.clockLang === "es" ? "#162D27" : "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.clockLang = "es"; root.saveSettings(); }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Formato 24h / 12h
                    RowLayout {
                        spacing: 3
                        Text {
                            text: "Modo:"
                            font.pixelSize: 9
                            color: root.dayOfWeekColor
                        }
                        Rectangle {
                            width: 32; height: 18; radius: 4
                            color: root.is24h ? root.digitsColor : Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                            Text {
                                anchors.centerIn: parent; text: "24h"; font.pixelSize: 8; font.bold: true
                                color: root.is24h ? "#162D27" : "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.is24h = true; root.saveSettings(); }
                            }
                        }
                        Rectangle {
                            width: 32; height: 18; radius: 4
                            color: !root.is24h ? root.digitsColor : Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                            Text {
                                anchors.centerIn: parent; text: "12h"; font.pixelSize: 8; font.bold: true
                                color: !root.is24h ? "#162D27" : "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.is24h = false; root.saveSettings(); }
                            }
                        }
                    }
                }

                // 3. Fila: Capa (Desktop fondo vs Siempre encima) y Escala
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Capa
                    RowLayout {
                        spacing: 3
                        Text {
                            text: "Capa:"
                            font.pixelSize: 9
                            color: root.dayOfWeekColor
                        }
                        Rectangle {
                            width: 58; height: 18; radius: 4
                            color: !root.layerOnTop ? root.digitsColor : Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                            Text {
                                anchors.centerIn: parent; text: "Fondo"; font.pixelSize: 8; font.bold: true
                                color: !root.layerOnTop ? "#162D27" : "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.layerOnTop = false; root.saveSettings(); }
                            }
                        }
                        Rectangle {
                            width: 58; height: 18; radius: 4
                            color: root.layerOnTop ? root.digitsColor : Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                            Text {
                                anchors.centerIn: parent; text: "Encima"; font.pixelSize: 8; font.bold: true
                                color: root.layerOnTop ? "#162D27" : "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.layerOnTop = true; root.saveSettings(); }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Botón Centrar Posición
                    Rectangle {
                        width: 60; height: 18; radius: 4
                        color: Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.15)
                        Text {
                            anchors.centerIn: parent; text: "Centrar"; font.pixelSize: 8; color: root.digitsColor
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                cardWrapper.x = Math.round((root.screenWidth - clockCard.width) / 2);
                                cardWrapper.y = Math.round((root.screenHeight - clockCard.height) / 2);
                                root.clockX = cardWrapper.x;
                                root.clockY = cardWrapper.y;
                                root.saveSettings();
                            }
                        }
                    }
                }
            }
        }
    }
}
