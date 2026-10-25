import QtQuick

Rectangle {
    id: root

    property var theme
    property real iconSize: 36

    width: iconSize
    height: iconSize
    radius: 9
    color: root.theme ? Qt.rgba(1, 1, 1, 0.06) : "#161b22"
    border.color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.12)
    border.width: 1

    Row {
        anchors.centerIn: parent
        spacing: 2

        readonly property var heights: [6, 11, 16, 21, 28, 21, 16, 11, 6]

        Repeater {
            model: 9

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 2.5
                height: parent.heights[index] * (root.iconSize / 36.0)
                radius: 1.25

                readonly property real t: index / 8.0
                color: {
                    var c1 = root.theme ? root.theme.mediaColor : "#ff79c6";
                    var c2 = root.theme ? root.theme.accent : "#00ffcc";
                    return Qt.rgba(
                        c1.r * (1 - t) + c2.r * t,
                        c1.g * (1 - t) + c2.g * t,
                        c1.b * (1 - t) + c2.b * t,
                        1.0
                    );
                }
            }
        }
    }
}
