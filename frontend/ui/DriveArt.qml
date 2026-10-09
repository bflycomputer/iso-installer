pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    anchors.fill: parent

    property int driveCount: 0
    property int selectedIndex: 0
    property bool scrollMode: driveCount > 2

    signal hovered(int index)
    signal clicked(int index)

    readonly property real diskWidth: 232
    readonly property real diskHeight: 150.777
    readonly property real normalStep: 108.637
    readonly property real scrollStep: driveCount > 5
                                               ? 451.73 / Math.max(1, driveCount - 1)
                                               : 114.363
    readonly property real stackCenterY: scrollMode ? 574.2535 : 546.7085

    function offsetFor(index) {
        if (!scrollMode)
            return index * normalStep

        if (driveCount === 5 && index > 0)
            return 108.637 + (index - 1) * 114.363

        return index * scrollStep
    }

    readonly property real stackHeight: driveCount > 0
                                                 ? offsetFor(driveCount - 1) + diskHeight
                                                 : 0
    readonly property real firstDiskY: stackCenterY - stackHeight / 2

    Repeater {
        model: Math.max(0, root.driveCount)

        delegate: Item {
            id: disk
            required property int index

            x: 10
            y: root.firstDiskY + root.offsetFor(index)
            width: root.diskWidth
            height: root.diskHeight

            Image {
                anchors.fill: parent
                source: disk.index === root.selectedIndex
                        ? "../assets/illustrations/disk-active.svg"
                        : "../assets/illustrations/disk-idle.svg"
                sourceSize: Qt.size(464, 302)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: if (Theme.hoverAllowed()) root.hovered(disk.index)
                onClicked: root.clicked(disk.index)
            }
        }
    }
}
