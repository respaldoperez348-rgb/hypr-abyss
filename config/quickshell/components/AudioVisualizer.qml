import QtQuick

Item {
    id: root

    property var theme
    property bool isPlaying: false

    implicitWidth: 280
    implicitHeight: 28

    Row {
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: 24

            Rectangle {
                id: bar
                width: 4
                radius: 2

                // Gradient color oscillating between theme.accent (cyan) and theme.mediaColor (magenta)
                readonly property real ratio: index / 23.0
                color: {
                    if (!root.theme) return "#00ffcc";
                    return Qt.rgba(
                        root.theme.accent.r * (1 - ratio) + root.theme.mediaColor.r * ratio,
                        root.theme.accent.g * (1 - ratio) + root.theme.mediaColor.g * ratio,
                        root.theme.accent.b * (1 - ratio) + root.theme.mediaColor.b * ratio,
                        0.85
                    );
                }

                // Random or oscillating height when playing, resting line when paused
                property real targetHeight: 4
                height: targetHeight

                Behavior on height {
                    NumberAnimation {
                        duration: 120 + (index % 5) * 25
                        easing.type: Easing.InOutQuad
                    }
                }

                Timer {
                    interval: 110 + (index % 4) * 30
                    running: root.isPlaying
                    repeat: true
                    onTriggered: {
                        if (root.isPlaying) {
                            var base = Math.sin(index * 0.4 + Date.now() * 0.005) * 0.5 + 0.5;
                            bar.targetHeight = Math.max(4, Math.min(26, base * 22 + Math.random() * 6));
                        } else {
                            bar.targetHeight = 4;
                        }
                    }
                }
            }
        }
    }
}
