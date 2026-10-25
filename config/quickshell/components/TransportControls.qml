import QtQuick

Item {
    id: root

    property var theme
    property var appState

    implicitWidth: 380
    implicitHeight: 56

    Row {
        anchors.centerIn: parent
        spacing: 14

        // Left Pill: Shuffle & Repeat
        Rectangle {
            width: 86
            height: 42
            radius: 21
            color: root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05)
            border.color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 14

                // Shuffle button ( \uf074)
                Text {
                    text: ""
                    font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: (root.appState && root.appState.shuffle) ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#8b949e")
                    opacity: (root.appState && root.appState.shuffle) ? 1.0 : 0.5
                    scale: shuffleArea.containsMouse ? 1.15 : 1.0

                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    MouseArea {
                        id: shuffleArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.appState) root.appState.toggleShuffle();
                        }
                    }
                }

                // Repeat button ( \uf01e)
                Text {
                    text: (root.appState && root.appState.repeatMode === "one") ? "" : ""
                    font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: (root.appState && root.appState.repeatMode !== "none") ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#8b949e")
                    opacity: (root.appState && root.appState.repeatMode !== "none") ? 1.0 : 0.5
                    scale: repeatArea.containsMouse ? 1.15 : 1.0

                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    MouseArea {
                        id: repeatArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.appState) root.appState.cycleRepeat();
                        }
                    }
                }
            }
        }

        // Center Pill: Previous, Play/Pause, Next
        Rectangle {
            width: 170
            height: 50
            radius: 25
            color: root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05)
            border.color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 16

                // Previous ( \uf048)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: prevArea.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.text : "#ffffff")
                    scale: prevArea.pressed ? 0.9 : (prevArea.containsMouse ? 1.12 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 100 } }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.appState) root.appState.prevTrack();
                        }
                    }
                }

                // Play / Pause Circle Button with Halo Glow
                Rectangle {
                    id: playBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    height: 42
                    radius: 21
                    color: root.theme ? root.theme.accent : "#00ffcc"

                    // Glow halo
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 10
                        height: parent.height + 10
                        radius: width / 2
                        color: parent.color
                        opacity: (root.appState && root.appState.isPlaying) ? 0.35 : 0.15
                        z: -1
                    }

                    // Play ( \uf04b) or Pause ( \uf04c)
                    Text {
                        anchors.centerIn: parent
                        text: (root.appState && root.appState.isPlaying) ? "" : ""
                        font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                        font.pixelSize: 17
                        color: "#0a0c10"
                    }

                    scale: playArea.pressed ? 0.92 : (playArea.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.appState) root.appState.togglePlay();
                        }
                    }
                }

                // Next ( \uf051)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: nextArea.containsMouse ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.text : "#ffffff")
                    scale: nextArea.pressed ? 0.9 : (nextArea.containsMouse ? 1.12 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 100 } }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.appState) root.appState.nextTrack();
                        }
                    }
                }
            }
        }

        // Right Pill: Volume Quick Control
        Rectangle {
            width: 106
            height: 42
            radius: 21
            color: root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05)
            border.color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 8

                // Volume Icon ( \uf028 or  \uf026)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.appState && root.appState.volume === 0) ? "" : ""
                    font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: root.theme ? root.theme.text : "#ffffff"
                    opacity: 0.8
                }

                // Volume mini-bar
                Rectangle {
                    id: volBar
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52
                    height: 5
                    radius: 2.5
                    color: root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.15)

                    Rectangle {
                        height: parent.height
                        width: Math.max(0, Math.min(parent.width, parent.width * ((root.appState ? root.appState.volume : 80) / 100.0)))
                        radius: parent.radius
                        color: root.theme ? root.theme.accent : "#00ffcc"
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: function(mouse) {
                            if (pressed && root.appState) {
                                var ratio = Math.max(0, Math.min(1, mouse.x / volBar.width));
                                root.appState.setVolume(Math.round(ratio * 100));
                            }
                        }
                        onPressed: function(mouse) {
                            if (root.appState) {
                                var ratio = Math.max(0, Math.min(1, mouse.x / volBar.width));
                                root.appState.setVolume(Math.round(ratio * 100));
                            }
                        }
                    }
                }
            }
        }
    }
}
