import QtQuick

Item {
    id: root

    property color color: "#8b949e"
    implicitWidth: 16
    implicitHeight: 16

    // Glass Lens Ring
    Rectangle {
        width: 10
        height: 10
        radius: 5
        x: 1
        y: 1
        color: "transparent"
        border.color: root.color
        border.width: 1.8
    }

    // Slanted Handle
    Rectangle {
        width: 6.5
        height: 1.8
        radius: 0.9
        x: 8.5
        y: 9.5
        transformOrigin: Item.TopLeft
        rotation: 45
        color: root.color
    }
}
