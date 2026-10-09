import QtQuick

Item {
    id: title
    property bool freeSpace: false
    property bool emptyDisk: false
    property bool active: false
    implicitWidth: titleRow.implicitWidth
    implicitHeight: 28
    height: 28
    clip: true

    Row {
        id: titleRow
        height: 28
        spacing: 4
        Label {
            text: title.freeSpace ? "Install" : title.emptyDisk ? "Use this empty disk" : "Replace the contents of this disk"
            color: title.active ? "black" : Theme.textWhite
            font: Theme.lg
            lh: Theme.lhLg
        }
        Item {
            visible: title.freeSpace
            width: tag.implicitWidth + 8
            height: 28
            Rectangle {
                y: 2
                width: parent.width
                height: 24
                radius: 4
                color: Theme.systemPond
            }
            Label {
                id: tag
                x: 4
                y: 4
                text: "Pond"
                color: title.active ? "black" : Theme.bg
                font: Theme.displaySm
                lh: Theme.lhDisplaySm
            }
        }
        Label {
            visible: title.freeSpace
            text: "in unallocated space"
            color: title.active ? "black" : Theme.textWhite
            font: Theme.lg
            lh: Theme.lhLg
        }
    }
}
