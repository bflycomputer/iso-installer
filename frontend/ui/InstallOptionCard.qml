pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    required property int number
    property bool active: false
    property string detail: ""
    property string title: ""

    readonly property bool visualActive: enabled && (active || pointer.pressed)

    signal selected()
    signal accepted()

    width: 720
    height: 99
    implicitWidth: 720
    implicitHeight: 99
    opacity: enabled ? 1 : 0.55

    ChoiceBadge {
        number: root.number
        active: root.visualActive
    }

    Rectangle {
        x: 40
        width: 680
        height: 99
        radius: 24
        color: root.visualActive ? Theme.lavender : Theme.surface
    }

    Item {
        x: 64
        width: 632
        height: root.height
        clip: true

        Label {
            y: 24
            width: parent.width
            text: root.title
            color: root.visualActive ? "black" : Theme.textWhite
            font: Theme.lg
            lh: Theme.lhLg
        }

        Label {
            y: Theme.capYBase(58)
            width: parent.width
            elide: Text.ElideRight
            text: root.detail
            color: root.visualActive ? "#000000" : Theme.textWhite
            opacity: 0.7
            font: Theme.base
            lh: Theme.lhBase
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.selected()
        onDoubleClicked: root.accepted()
    }
}
