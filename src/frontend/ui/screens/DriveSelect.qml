pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    readonly property int rowCount: driveList.count
    readonly property bool scrollMode: rowCount > 2
    readonly property int activeRow: Math.max(0, Math.min(rowCount - 1, controller.selectedDrive))

    function selectDrive(index) {
        if (rowCount > 0 && controller.selectedDrive !== index)
            controller.selectedDrive = Math.max(0, Math.min(rowCount - 1, index))
    }
    function moveSelection(delta) {
        if (rowCount > 0)
            selectDrive((activeRow + delta + rowCount) % rowCount)
    }
    function chooseIndex(index) {
        if (index >= 0 && index < rowCount)
            selectDrive(index)
    }
    function accept() {
        controller.selectedDrive = activeRow
        controller.advance()
    }

    DriveIllustration {
        driveCount: root.rowCount
        selectedIndex: root.activeRow
        scrollMode: root.scrollMode
        onClicked: index => root.selectDrive(index)
    }

    Title {
        z: 3
        y: root.scrollMode ? 32 : 235
        width: 291
        x: 864.5 - width / 2
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "Where should Pond be installed?"
        color: Theme.textCream
    }

    ListView {
        id: driveList
        objectName: "driveChoices"
        z: 1
        x: root.scrollMode ? 569 : 579
        y: root.scrollMode ? 0 : 339
        width: 610
        height: root.scrollMode ? 1117 : 408
        spacing: 8
        header: Item { height: root.scrollMode ? 134 : 0 }
        footer: Item { height: root.scrollMode ? 135 : 0 }
        preferredHighlightBegin: root.scrollMode ? 134 : 0
        preferredHighlightEnd: root.scrollMode ? 982 : height
        highlightRangeMode: ListView.ApplyRange
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: controller.drives
        currentIndex: root.activeRow
        highlightMoveDuration: 0

        onCountChanged: Qt.callLater(function() {
            forceLayout()
            if (currentIndex === 0)
                positionViewAtBeginning()
        })

        delegate: Item {
            id: item
            required property int index
            required property string name
            required property string detail
            required property string capacity
            required property string used
            required property string available
            required property real capacityBytes
            required property real usedBytes
            required property bool empty

            width: 610
            height: 200
            readonly property bool active: index === root.activeRow

            ChoiceBadge {
                x: 0
                y: 0
                number: item.index + 1
                active: item.active
            }

            Rectangle {
                x: 40
                y: 0
                width: 530
                height: 200
                radius: 24
                color: item.active ? Theme.lavender : Theme.surface

                Label {
                    x: 24
                    y: 17
                    width: 270
                    elide: Text.ElideRight
                    text: item.name
                    color: item.active ? Theme.onCard : Theme.textWhite
                    font: Theme.lg
                    lh: Theme.lhLg
                }

                Label {
                    x: 24
                    y: Theme.capYBase(49)
                    width: 440
                    elide: Text.ElideRight
                    opacity: 0.7
                    text: item.detail
                    color: item.active ? Theme.onCard : Theme.textWhite
                    font: Theme.base
                    lh: Theme.lhBase
                }

                Repeater {
                    model: item.empty
                           ? [{ label: "Storage:", value: item.capacity, y: 144 },
                              { label: "Available:", value: item.available, y: 165 }]
                           : [{ label: "Storage:", value: item.capacity, y: 123 },
                              { label: "Used:", value: item.used, y: 144 },
                              { label: "Available:", value: item.available, y: 165 }]

                    Item {
                        id: stat
                        required property var modelData

                        Label {
                            x: 24
                            y: Theme.capYBase(stat.modelData.y)
                            opacity: 0.7
                            text: stat.modelData.label
                            color: item.active ? Theme.onCard : Theme.textWhite
                            font: Theme.base
                            lh: Theme.lhBase
                        }
                        Label {
                            x: 103
                            y: Theme.capYBase(stat.modelData.y)
                            opacity: 0.7
                            text: stat.modelData.value
                            color: item.active ? Theme.onCard : Theme.textWhite
                            font: Theme.base
                            lh: Theme.lhBase
                        }
                    }
                }

                Rectangle {
                    x: 326
                    y: 123
                    width: 180
                    height: 53
                    color: Theme.textCream
                    border.color: "black"
                    border.width: 1

                    Rectangle {
                        visible: !item.empty
                        width: Math.max(0, Math.min(180, Math.round(180 * item.usedBytes / Math.max(1, item.capacityBytes))))
                        height: 53
                        color: Theme.barUsed
                        border.color: "black"
                        border.width: 1
                    }

                    Label {
                        visible: item.empty
                        anchors.centerIn: parent
                        text: "Empty"
                        color: Theme.bg
                        opacity: 0.7
                        font: Theme.base
                        lh: Theme.lhBase
                    }
                }
            }

            MouseArea {
                x: 0
                y: 0
                width: 570
                height: 200
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectDrive(item.index)
                onDoubleClicked: {
                    root.selectDrive(item.index)
                    root.accept()
                }
            }
        }

        Label {
            visible: driveList.count === 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: 100
            text: !controller.storageReady
                  ? "Looking for storage…" : "No installable storage found"
            color: Theme.textWhite
            opacity: 0.7
            font: Theme.base
            lh: Theme.lhBase
        }
    }

    Rectangle {
        z: 2
        visible: root.scrollMode && !driveList.atYBeginning
        x: 469
        y: 0
        width: 790
        height: 135
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.bg }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Rectangle {
        z: 2
        visible: root.scrollMode
        x: 469
        y: 982
        width: 790
        height: 135
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Theme.bg }
        }
    }

    ErrorText {
        z: 3
        y: root.scrollMode ? 1004 : 746
    }

    NavBar {
        z: 4
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.scrollMode ? 1033 : 787
        primaryEnabled: root.rowCount > 0
        label: "Confirm"
    }
}
