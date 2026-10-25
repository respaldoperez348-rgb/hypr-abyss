import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var theme
    property var appState
    property var trackData
    property int trackIndex: 0
    property bool isCurrentPlaying: false

    implicitWidth: 420
    implicitHeight: 54
    radius: 12

    readonly property bool isFav: {
        if (!appState || !trackData) return false;
        var tid = trackData.id || trackData.url;
        return appState.favorites.some(function(f) {
            return f.id === tid || f.url === tid;
        });
    }

    color: rowArea.containsMouse 
        ? (root.theme ? root.theme.surfaceHover : Qt.rgba(1, 1, 1, 0.08)) 
        : (root.isCurrentPlaying ? (root.theme ? root.theme.surfaceActive : Qt.rgba(1, 1, 1, 0.05)) : "transparent")

    border.color: root.isCurrentPlaying 
        ? (root.theme ? root.theme.border : Qt.rgba(0, 1, 0.8, 0.3)) 
        : "transparent"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.appState && root.trackData) {
                root.appState.playTrack(root.trackData);
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 14
        spacing: 12

        // 1. Index number or Playing Indicator
        Text {
            Layout.preferredWidth: 26
            text: root.isCurrentPlaying ? "" : ((root.trackIndex + 1 < 10 ? "0" : "") + (root.trackIndex + 1))
            font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
            font.pixelSize: root.isCurrentPlaying ? 13 : 11
            color: root.isCurrentPlaying ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#8b949e")
            horizontalAlignment: Text.AlignRight
        }

        // 2. Thumbnail
        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 8
            clip: true
            color: "#161b22"
            border.color: root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Image {
                anchors.fill: parent
                source: (root.trackData && root.trackData.thumbnail) ? root.trackData.thumbnail : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        // 3. Title & Artist
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: (root.trackData && root.trackData.title) ? root.trackData.title : "Canción"
                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                font.pixelSize: 13
                font.bold: root.isCurrentPlaying
                color: root.isCurrentPlaying ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.text : "#f0f6fc")
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: (root.trackData && root.trackData.artist) ? root.trackData.artist : "Artista"
                font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                font.pixelSize: 11
                color: root.theme ? root.theme.textDim : "#8b949e"
                elide: Text.ElideRight
            }
        }

        // 4. Duration
        Text {
            text: (root.trackData && root.trackData.duration) ? root.trackData.duration : "--:--"
            font.family: root.theme ? root.theme.fontMono : "monospace"
            font.pixelSize: 11
            color: root.theme ? root.theme.textDim : "#8b949e"
        }

        // 5. Heart Favorite Button
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: "transparent"

            HeartIcon {
                anchors.centerIn: parent
                iconSize: 17
                isFavorite: root.isFav
                activeColor: "#ff2a6d"
                inactiveColor: root.theme ? root.theme.textDim : "#8b949e"
                scale: favArea.containsMouse ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
            }

            MouseArea {
                id: favArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.appState && root.trackData) {
                        root.appState.toggleFavorite(root.trackData);
                    }
                }
            }
        }
    }
}
