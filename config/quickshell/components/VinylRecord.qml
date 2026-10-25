import QtQuick

Item {
    id: root

    property var theme
    property var appState

    implicitWidth: 340
    implicitHeight: 210

    readonly property string coverUrl: (appState && appState.currentTrack && appState.currentTrack.thumbnail) 
        ? appState.currentTrack.thumbnail 
        : ""

    readonly property bool isPlaying: appState ? appState.isPlaying : false

    // Inner container centered in root
    Item {
        id: container
        anchors.centerIn: parent
        width: 300
        height: 190

        // Vinyl Record (positioned behind sleeve, sliding out to the right)
        Rectangle {
            id: vinylDisc
            width: 180
            height: 180
            radius: 90
            anchors.verticalCenter: parent.verticalCenter
            x: sleeve.x + 85
            color: "#0a0c10"
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1.5
            z: 1

            // Concentric vinyl grooves
            Repeater {
                model: 5
                Rectangle {
                    anchors.centerIn: parent
                    width: vinylDisc.width - (index * 22 + 18)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.04 + index * 0.015)
                    border.width: 1
                }
            }

            // Vinyl Center Label with album art
            Rectangle {
                id: vinylCenter
                anchors.centerIn: parent
                width: 64
                height: 64
                radius: 32
                color: "#161b22"
                clip: true
                layer.enabled: true
                border.color: root.theme ? root.theme.accent : "#00ffcc"
                border.width: 1.5

                Image {
                    anchors.fill: parent
                    source: root.coverUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                // Center spindle hole
                Rectangle {
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: "#000000"
                }
            }

            // Spinning animation when playing
            RotationAnimation on rotation {
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 7000
                running: root.isPlaying
            }
        }

        // Album Sleeve Jacket (Front - clipped with rounded corners)
        Rectangle {
            id: sleeve
            width: 190
            height: 190
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            radius: 16
            color: "#161b22"
            clip: true
            layer.enabled: true
            border.color: root.theme ? root.theme.border : Qt.rgba(0, 1, 0.8, 0.3)
            border.width: 1.5
            z: 2

            Image {
                id: coverImg
                anchors.fill: parent
                anchors.margins: 1
                source: root.coverUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true

                // Fallback icon if no cover image
                Rectangle {
                    anchors.fill: parent
                    color: "#161b22"
                    visible: coverImg.status !== Image.Ready

                    AuraIcon {
                        anchors.centerIn: parent
                        theme: root.theme
                        iconSize: 56
                    }
                }
            }

            // Subtle gloss border on sleeve edge
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
            }
        }
    }
}
