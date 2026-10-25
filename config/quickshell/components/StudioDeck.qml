import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var theme
    property bool isOpen: true
    signal closeRequested()

    implicitWidth: 1060
    implicitHeight: 610

    property alias card: deckContainer

    AppState {
        id: globalState
    }

    function togglePlay(): void { globalState.togglePlay(); }
    function playNextSong(manual): void { globalState.nextTrack(); }
    function playPreviousSong(manual): void { globalState.prevTrack(); }
    function autoNext(): void { globalState.nextTrack(); }

    // Main Studio Container
    Item {
        id: deckContainer
        anchors.centerIn: parent
        width: 1050
        height: 600

        // Backdrop Glow behind the entire Studio Deck
        Rectangle {
            anchors.fill: parent
            anchors.margins: -10
            radius: 28
            color: root.theme ? root.theme.accent : "#00ffcc"
            opacity: 0.08
            z: -1
        }

        RowLayout {
            anchors.fill: parent
            spacing: 18

            // Left: Player Deck (Hero stage, Vinyl, Scrubber, Transport)
            PlayerDeck {
                Layout.preferredWidth: 480
                Layout.fillHeight: true
                theme: root.theme
                appState: globalState
            }

            // Right: Library Deck (Branding, Search, Tabs, Queue/Favorites)
            LibraryDeck {
                Layout.preferredWidth: 550
                Layout.fillHeight: true
                theme: root.theme
                appState: globalState
                onCloseRequested: root.closeRequested()
            }
        }
    }

    // Keyboard shortcuts
    focus: true
    Keys.onEscapePressed: {
        root.closeRequested();
    }
}
