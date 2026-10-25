import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var theme
    property var appState

    implicitWidth: 480
    implicitHeight: 570

    radius: 22
    color: root.theme ? Qt.rgba(root.theme.backgroundSolid.r, root.theme.backgroundSolid.g, root.theme.backgroundSolid.b, 0.82) : Qt.rgba(0.05, 0.07, 0.1, 0.85)
    border.color: root.theme ? root.theme.border : Qt.rgba(0, 1, 0.8, 0.25)
    border.width: 1.5

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        // 1. Vinyl Record Section
        VinylRecord {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 340
            Layout.preferredHeight: 210
            theme: root.theme
            appState: root.appState
        }

        // 2. Track Title, Artist and Heart Button
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52

            Column {
                anchors.left: parent.left
                anchors.right: heartBtn.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    width: parent.width
                    text: (root.appState && root.appState.currentTrack) ? root.appState.currentTrack.title : "Aura Music"
                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                    font.pixelSize: 18
                    font.bold: true
                    color: root.theme ? root.theme.text : "#f0f6fc"
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: (root.appState && root.appState.currentTrack) ? root.appState.currentTrack.artist : "Listo para reproducir"
                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                    font.pixelSize: 13
                    color: root.theme ? root.theme.accent : "#00ffcc"
                    elide: Text.ElideRight
                }
            }

            // Quick Heart Favorite Toggle
            Rectangle {
                id: heartBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 22
                color: (root.appState && root.appState.isCurrentFavorite)
                    ? Qt.rgba(1.0, 0.16, 0.42, 0.15)
                    : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05))
                border.color: (root.appState && root.appState.isCurrentFavorite) 
                    ? "#ff2a6d" 
                    : (root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.15))
                border.width: 1.5

                // Glowing aura when favorite
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 8
                    height: parent.height + 8
                    radius: width / 2
                    color: "#ff2a6d"
                    opacity: (root.appState && root.appState.isCurrentFavorite) ? 0.22 : 0.0
                    z: -1
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }

                HeartIcon {
                    anchors.centerIn: parent
                    iconSize: 22
                    isFavorite: root.appState ? root.appState.isCurrentFavorite : false
                    activeColor: "#ff2a6d"
                    inactiveColor: root.theme ? root.theme.textDim : "#8b949e"
                    scale: heartArea.containsMouse ? 1.15 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    id: heartArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.appState) root.appState.toggleFavorite();
                    }
                }
            }
        }

        // 3. Audio Visualizer Spectrum
        AudioVisualizer {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: 32
            theme: root.theme
            isPlaying: root.appState ? root.appState.isPlaying : false
        }

        // 4. Progress Scrubber
        ProgressScrubber {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: 32
            theme: root.theme
            appState: root.appState
        }

        // 5. Media Transport Controls
        TransportControls {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: 56
            theme: root.theme
            appState: root.appState
        }
    }
}
