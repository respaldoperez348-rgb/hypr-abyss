import QtQuick

Item {
    id: root

    property var theme
    property var appState

    implicitWidth: 320
    implicitHeight: 32

    readonly property real position: appState ? appState.position : 0.0
    readonly property real duration: appState ? appState.duration : 1.0

    property bool isDragging: false
    property real dragValue: 0.0

    readonly property real progressRatio: {
        if (duration <= 0) return 0.0;
        var cur = isDragging ? dragValue : position;
        return Math.max(0.0, Math.min(1.0, cur / duration));
    }

    Row {
        id: layout
        anchors.fill: parent
        spacing: 10

        // Current Time Label
        Text {
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            text: root.appState ? root.appState.formatTime(root.isDragging ? root.dragValue : root.position) : "00:00"
            font.family: root.theme ? root.theme.fontMono : "monospace"
            font.pixelSize: 11
            color: root.theme ? root.theme.textDim : "#8b949e"
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }

        // Track & Scrubber Area
        Item {
            id: trackArea
            width: layout.width - 108
            height: parent.height

            // Background Groove
            Rectangle {
                id: bgGroove
                anchors.centerIn: parent
                width: parent.width
                height: 4
                radius: 2
                color: root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.08)

                // Fill Progress
                Rectangle {
                    id: fillBar
                    height: parent.height
                    width: Math.max(0, parent.width * root.progressRatio)
                    radius: parent.radius

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.theme ? root.theme.accent : "#00ffcc" }
                        GradientStop { position: 1.0; color: root.theme ? root.theme.mediaColor : "#ff79c6" }
                    }
                }

                // Scrubber Thumb
                Rectangle {
                    id: thumb
                    width: root.isDragging || mouseArea.containsMouse ? 12 : 8
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(bgGroove.width - width, fillBar.width - width / 2))
                    color: "#ffffff"
                    border.color: root.theme ? root.theme.accent : "#00ffcc"
                    border.width: 2

                    Behavior on width {
                        NumberAnimation { duration: 120 }
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function updateDrag(mouseX) {
                    var r = Math.max(0.0, Math.min(1.0, mouseX / trackArea.width));
                    root.dragValue = r * root.duration;
                }

                onPressed: function(mouse) {
                    root.isDragging = true;
                    updateDrag(mouse.x);
                }

                onPositionChanged: function(mouse) {
                    if (root.isDragging) {
                        updateDrag(mouse.x);
                    }
                }

                onReleased: function(mouse) {
                    if (root.isDragging) {
                        updateDrag(mouse.x);
                        if (root.appState) {
                            root.appState.seek(root.dragValue);
                        }
                        root.isDragging = false;
                    }
                }
            }
        }

        // Duration Label
        Text {
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            text: root.appState ? root.appState.formatTime(root.duration) : "00:00"
            font.family: root.theme ? root.theme.fontMono : "monospace"
            font.pixelSize: 11
            color: root.theme ? root.theme.textDim : "#8b949e"
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }
    }
}
