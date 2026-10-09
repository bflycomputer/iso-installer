import QtQuick

Row {
    id: nav

    property string label: "Enter"
    property bool showChevrons: true
    // 104 is the standard control; 124 only the scroll variant.
    property int chevronWidth: 104
    // Keyboard focus ring for screens that make the pill a focusable row.
    property bool focused: false

    spacing: 10

    function submit() {
        if (!nav.parent)
            return
        if (nav.parent.submit !== undefined)
            nav.parent.submit()
        else if (nav.parent.accept !== undefined)
            nav.parent.accept()
    }

    Rectangle {
        id: chevronPill
        visible: nav.showChevrons
        width: nav.chevronWidth
        height: 64
        radius: 54
        color: Theme.surface
        clip: true

        Repeater {
            model: 2
            Item {
                id: arrow
                required property int index
                readonly property int direction: index === 0 ? 1 : -1
                readonly property bool held: Theme.navigationDirection === direction || pointer.pressed
                x: index * width
                width: chevronPill.width / 2
                height: 64

                Item {
                    x: arrow.index === 0 ? 2 : 0
                    y: 2
                    width: parent.width - 2
                    height: 60
                    clip: true
                    opacity: arrow.held ? 1 : 0.3
                    visible: arrow.held || pointer.containsMouse
                    Rectangle {
                        x: arrow.index === 0 ? 0 : -30
                        width: parent.width + 30
                        height: 60
                        topLeftRadius: arrow.index === 0 ? 30 : 0
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: arrow.index === 1 ? 30 : 0
                        bottomRightRadius: topRightRadius
                        color: Theme.navigationFeedback
                    }
                }
                Image {
                    x: nav.chevronWidth === 104 ? (arrow.index === 0 ? 20 : 8) : 19
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    source: "../assets/icons/chevron-" + (arrow.index === 0 ? "down" : "up") + ".svg"
                    sourceSize: Qt.size(48, 48)
                }
                MouseArea {
                    id: pointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nav.parent.moveSelection(arrow.direction)
                }
            }
        }
    }

    Rectangle {
        width: 240
        height: 64
        radius: 54
        color: Theme.green
        border.width: nav.focused ? 3 : 0
        border.color: Theme.lavender

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 0.5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Item {
                width: 20
                height: 20
                Image {
                    x: 0.666
                    y: 0.666
                    width: 18.668
                    height: 18.668
                    source: "../assets/icons/enter-key.svg"
                    sourceSize: Qt.size(38, 38)
                }
            }
            FText {
                text: nav.label
                color: Theme.onAccent
                font: Theme.base
                lh: Theme.lhBase
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.submit()
        }
    }
}
