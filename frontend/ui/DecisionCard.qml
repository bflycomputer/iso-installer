pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    required property int number
    property bool active: false
    property string detail: ""
    property bool freeSpace: false

    default property alias visualizationData: visualizationSlot.data

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
        numeralOffset: 2
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
        width: Math.max(0, visualizationSlot.x - x - 24)
        height: root.height
        clip: true

        OptionTitle {
            y: 24
            width: parent.width
            active: root.visualActive
            freeSpace: root.freeSpace
        }

        FText {
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

    Item {
        id: visualizationSlot
        x: root.width - 24 - width
        y: Math.round((root.height - height) / 2)
        width: 150
        height: 40
        clip: true
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: if (Theme.hoverAllowed()) root.selected()
        onClicked: root.selected()
        onDoubleClicked: root.accepted()
    }
}
