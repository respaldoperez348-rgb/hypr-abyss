import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root

    property var theme
    property var appState
    signal closeRequested()

    implicitWidth: 540
    implicitHeight: 570

    radius: 22
    color: root.theme ? Qt.rgba(root.theme.backgroundSolid.r, root.theme.backgroundSolid.g, root.theme.backgroundSolid.b, 0.82) : Qt.rgba(0.05, 0.07, 0.1, 0.85)
    border.color: root.theme ? root.theme.border : Qt.rgba(0, 1, 0.8, 0.25)
    border.width: 1.5

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 16

        // 1. Header: Branding + Search Bar + Close Button
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 12

            // Branding (Isotype + Name)
            Row {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                AuraIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root.theme
                    iconSize: 32
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        text: "AURA"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 16
                        font.bold: true
                        color: root.theme ? root.theme.accent : "#00ffcc"
                    }

                    Text {
                        text: "MUSIC"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 16
                        font.bold: true
                        color: root.theme ? root.theme.mediaColor : "#ff79c6"
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Search Bar Pill
            Rectangle {
                Layout.preferredWidth: 210
                Layout.preferredHeight: 38
                radius: 19
                color: root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05)
                border.color: searchInput.activeFocus 
                    ? (root.theme ? root.theme.accent : "#00ffcc") 
                    : (root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.1))
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8

                    SearchIcon {
                        color: searchInput.activeFocus 
                            ? (root.theme ? root.theme.accent : "#00ffcc") 
                            : (root.theme ? root.theme.textDim : "#8b949e")
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        color: root.theme ? root.theme.text : "#ffffff"
                        clip: true
                        selectByMouse: true

                        Text {
                            text: "Buscar en YouTube..."
                            font: searchInput.font
                            color: root.theme ? root.theme.textDim : "#8b949e"
                            visible: !searchInput.text && !searchInput.activeFocus
                        }

                        onAccepted: {
                            if (root.appState && text.trim().length > 0) {
                                root.appState.search(text.trim());
                            }
                        }
                    }

                    // Clear button
                    Text {
                        text: ""
                        font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: root.theme ? root.theme.textDim : "#8b949e"
                        visible: searchInput.text.length > 0
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                if (root.appState && root.appState.activeTab === "search") {
                                    root.appState.activeTab = "favorites";
                                }
                            }
                        }
                    }
                }
            }

            // Close Button (neatly spaced next to search bar)
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: closeArea.containsMouse 
                    ? (root.theme ? root.theme.danger : "#ff5555") 
                    : (root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05))
                border.color: closeArea.containsMouse
                    ? (root.theme ? root.theme.danger : "#ff5555")
                    : (root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.12))
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.family: "sans-serif"
                    font.pixelSize: 13
                    font.bold: true
                    color: closeArea.containsMouse ? "#ffffff" : (root.theme ? root.theme.textDim : "#8b949e")
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeRequested();
                    }
                }
            }
        }

        // 2. Segmented Tabs & Quick Actions
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 10

            // Tab Favoritos
            Rectangle {
                Layout.preferredHeight: 34
                Layout.preferredWidth: 130
                radius: 17
                color: (root.appState && root.appState.activeTab === "favorites") 
                    ? (root.theme ? root.theme.surfaceActive : Qt.rgba(1, 1, 1, 0.12)) 
                    : "transparent"
                border.color: (root.appState && root.appState.activeTab === "favorites")
                    ? (root.theme ? root.theme.mediaColor : "#ff79c6")
                    : (root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.08))
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    HeartIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: 14
                        isFavorite: true
                        activeColor: (root.appState && root.appState.activeTab === "favorites") ? "#ff2a6d" : (root.theme ? root.theme.textDim : "#8b949e")
                    }
                    Text {
                        text: "Favoritos (" + (root.appState ? root.appState.favorites.length : 0) + ")"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        font.bold: root.appState && root.appState.activeTab === "favorites"
                        color: root.theme ? root.theme.text : "#ffffff"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.appState) root.appState.activeTab = "favorites";
                    }
                }
            }

            // Tab Cola
            Rectangle {
                Layout.preferredHeight: 34
                Layout.preferredWidth: 110
                radius: 17
                color: (root.appState && root.appState.activeTab === "queue") 
                    ? (root.theme ? root.theme.surfaceActive : Qt.rgba(1, 1, 1, 0.12)) 
                    : "transparent"
                border.color: (root.appState && root.appState.activeTab === "queue")
                    ? (root.theme ? root.theme.accent : "#00ffcc")
                    : (root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.08))
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    Text {
                        text: ""
                        font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: (root.appState && root.appState.activeTab === "queue") ? (root.theme ? root.theme.accent : "#00ffcc") : (root.theme ? root.theme.textDim : "#8b949e")
                    }
                    Text {
                        text: "Cola (" + (root.appState ? root.appState.queue.length : 0) + ")"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        font.bold: root.appState && root.appState.activeTab === "queue"
                        color: root.theme ? root.theme.text : "#ffffff"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.appState) root.appState.activeTab = "queue";
                    }
                }
            }

            // Tab Resultados de Búsqueda (si existen)
            Rectangle {
                visible: root.appState && (root.appState.isSearching || root.appState.searchResults.length > 0)
                Layout.preferredHeight: 34
                Layout.preferredWidth: 120
                radius: 17
                color: (root.appState && root.appState.activeTab === "search") 
                    ? (root.theme ? root.theme.surfaceActive : Qt.rgba(1, 1, 1, 0.12)) 
                    : "transparent"
                border.color: (root.appState && root.appState.activeTab === "search")
                    ? (root.theme ? root.theme.accent : "#00ffcc")
                    : (root.theme ? root.theme.borderSubtle : Qt.rgba(1, 1, 1, 0.08))
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    SearchIcon {
                        color: root.theme ? root.theme.accent : "#00ffcc"
                    }
                    Text {
                        text: "Resultados"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        font.bold: root.appState && root.appState.activeTab === "search"
                        color: root.theme ? root.theme.text : "#ffffff"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.appState) root.appState.activeTab = "search";
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Botón Reproducir Todo (si está en favoritos)
            Rectangle {
                visible: root.appState && root.appState.activeTab === "favorites" && root.appState.favorites.length > 0
                Layout.preferredHeight: 32
                Layout.preferredWidth: 96
                radius: 16
                color: root.theme ? root.theme.surface : Qt.rgba(1, 1, 1, 0.05)
                border.color: root.theme ? root.theme.accent : "#00ffcc"
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: ""
                        font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: root.theme ? root.theme.accent : "#00ffcc"
                    }
                    Text {
                        text: "Todo"
                        font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        font.bold: true
                        color: root.theme ? root.theme.accent : "#00ffcc"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.appState) root.appState.playAllFavorites();
                    }
                }
            }
        }

        // 3. Track List View
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading indicator
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: root.appState && root.appState.isSearching

                SearchIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root.theme ? root.theme.accent : "#00ffcc"
                    scale: 2.0
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Buscando canciones en YouTube..."
                    font.family: root.theme ? root.theme.fontFamily : "sans-serif"
                    font.pixelSize: 13
                    color: root.theme ? root.theme.accent : "#00ffcc"
                }
            }

            // Track list
            ListView {
                id: trackListView
                anchors.fill: parent
                clip: true
                spacing: 4
                visible: !(root.appState && root.appState.isSearching)

                model: {
                    if (!root.appState) return [];
                    if (root.appState.activeTab === "favorites") return root.appState.favorites;
                    if (root.appState.activeTab === "queue") return root.appState.queue;
                    if (root.appState.activeTab === "search") return root.appState.searchResults;
                    return [];
                }

                delegate: TrackRow {
                    width: trackListView.width
                    theme: root.theme
                    appState: root.appState
                    trackData: modelData
                    trackIndex: index
                    isCurrentPlaying: (root.appState && root.appState.currentTrack && modelData) 
                        ? (root.appState.currentTrack.id === modelData.id || root.appState.currentTrack.url === modelData.url) 
                        : false
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                    width: 4
                }
            }
        }
    }
}
