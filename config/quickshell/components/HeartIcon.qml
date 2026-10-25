import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property bool isFavorite: false
    property color activeColor: "#ff2a6d"  // Glowing Neon Red / Rose
    property color inactiveColor: "#8b949e"
    property real iconSize: 20

    implicitWidth: iconSize
    implicitHeight: iconSize

    scale: isFavorite ? 1.1 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 180; easing.type: Easing.OutBack }
    }

    Shape {
        id: heartShape
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: root.iconSize / 24.0

        ShapePath {
            strokeWidth: 2.0
            strokeColor: root.isFavorite ? root.activeColor : root.inactiveColor
            fillColor: root.isFavorite ? root.activeColor : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: "M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"
            }
        }
    }
}
