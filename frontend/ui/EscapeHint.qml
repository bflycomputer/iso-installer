import QtQuick

Item {
    id: root

    signal activated

    x: 21
    y: 550
    width: 62
    height: 18
    opacity: 0.7

    Image {
        x: -5.50
        y: -6.52
        width: 32.35
        height: 31.03
        fillMode: Image.Stretch
        source: "../assets/icons/arrow-back.svg"
        sourceSize: Qt.size(320, 320)
    }

    FText {
        x: 34
        y: 3
        width: 28
        text: "ESC"
        color: Theme.lavender
        font: Theme.monoXs
        lh: 12
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
