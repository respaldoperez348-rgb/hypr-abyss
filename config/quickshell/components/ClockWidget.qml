import QtQuick
import Quickshell

/**
 * ClockWidget.qml
 * Reloj estilizado y nítido para la Dynamic Island.
 * - Sin iconos rotos de fuentes: micro-indicador de pulso neón y tipografía limpia.
 * - Dos tonos (horas en acento neón, minutos en blanco puro).
 * - Clic para expandir fecha con animación suave (slide/fade).
 * - Segundo clic para contraer y regresar al estado normal compacto.
 */
Item {
    id: root

    property var theme
    property bool showDate: false
    signal toggleControlCenterRequested()

    implicitHeight: 20
    implicitWidth: clockPill.width

    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

    // Pulso neón suave de 1 segundo
    Timer {
        id: pulseTimer
        interval: 1000
        repeat: true
        running: true
        property bool active: true
        onTriggered: active = !active
    }

    Rectangle {
        id: clockPill
        anchors.verticalCenter: parent.verticalCenter
        height: 20
        width: clockRow.implicitWidth + 12
        radius: 10

        color: clockMouse.containsMouse 
               ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.08)) 
               : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.04))

        border.width: 1
        border.color: clockMouse.containsMouse 
                      ? (root.theme ? root.theme.borderHover : "#00ffcc") 
                      : (root.showDate 
                         ? (root.theme ? root.theme.accentAlt : "#bd93f9") 
                         : (root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.1)))

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        MouseArea {
            id: clockMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    root.toggleControlCenterRequested();
                } else {
                    root.showDate = !root.showDate;
                }
            }
        }

        Row {
            id: clockRow
            anchors.centerIn: parent
            spacing: 5

            // Micro-indicador de pulso neón
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 4.5
                height: 4.5
                radius: 2.25
                color: root.theme ? root.theme.accent : "#00ffcc"
                opacity: pulseTimer.active ? 1.0 : 0.35

                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }
            }

            // Horas (Color de acento neón)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(sysClock.date, "hh")
                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                font.pixelSize: 11
                font.bold: true
                color: root.theme ? root.theme.accent : "#00ffcc"
            }

            // Dos puntos parpadeantes
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                font.pixelSize: 11
                font.bold: true
                color: root.theme ? root.theme.text : "#f0f6fc"
                opacity: pulseTimer.active ? 1.0 : 0.3

                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }
            }

            // Minutos (Color blanco puro)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(sysClock.date, "mm")
                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                font.pixelSize: 11
                font.bold: true
                color: root.theme ? root.theme.text : "#f0f6fc"
            }

            // Contenedor animado de fecha: se expande al dar clic y se contrae al dar clic de nuevo
            Item {
                id: dateContainer
                visible: width > 0
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                height: 14
                implicitWidth: dateRow.implicitWidth
                width: root.showDate ? implicitWidth : 0
                opacity: root.showDate ? 1.0 : 0.0

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                Row {
                    id: dateRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 9
                        color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.15)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(sysClock.date, "ddd d MMM").toUpperCase()
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 10
                        font.bold: true
                        color: root.theme ? root.theme.accentAlt : "#bd93f9"
                    }
                }
            }
        }
    }
}
