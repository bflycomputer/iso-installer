pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    width: 359
    height: choices.length >= 7 ? 272 : 16 + 40 * choices.length

    property var choices: []
    property int highlightedIndex: -1

    signal chosen(int index)
    signal highlighted(int index)

    function positionAt(index) {
        if (index < 0 || index >= choices.length)
            return
        Theme.blockHover()
        choiceList.positionViewAtIndex(index, ListView.Contain)
    }

    onVisibleChanged: Theme.blockHover()

    Repeater {
        model: [
            { x: -16, y: 30, grow: 32, alpha: 0.04 },
            { x: -12, y: 20, grow: 24, alpha: 0.06 },
            { x: -9, y: 12, grow: 18, alpha: 0.10 },
            { x: -6, y: 9, grow: 12, alpha: 0.13 },
            { x: -3, y: 5, grow: 6, alpha: 0.15 }
        ]

        Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: root.width + modelData.grow
            height: root.height + modelData.grow / 2
            radius: 12
            color: "#000000"
            opacity: modelData.alpha
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 8
        color: Theme.fieldOnLavender
        clip: true

        ListView {
            id: choiceList
            // The authored content frame is inset by 8.5 px on both sides.
            x: 8.5
            y: 8
            width: 342
            height: root.height - 8
            clip: true
            model: root.choices
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            reuseItems: true

            delegate: Rectangle {
                id: choiceRow
                required property int index
                required property var modelData

                readonly property bool highlighted: index === root.highlightedIndex
                width: choiceList.width
                height: 40
                radius: highlighted ? 4 : 12
                color: highlighted ? Theme.green : "transparent"

                Label {
                    x: 12
                    y: Theme.capYSm(15.5)
                    width: parent.width - 24
                    text: choiceRow.modelData.detail
                          ? choiceRow.modelData.label + "  ·  " + choiceRow.modelData.detail
                          : choiceRow.modelData.label
                    elide: Text.ElideRight
                    color: choiceRow.highlighted ? "#000000" : Theme.textWhite
                    font: Theme.sm
                    lh: Theme.lhSm
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (Theme.hoverAllowed()) root.highlighted(choiceRow.index)
                    onClicked: root.chosen(choiceRow.index)
                }
            }
        }

        Rectangle {
            readonly property real travel: panel.height - 32 - height
            readonly property real scrollRange: Math.max(1, choiceList.contentHeight - choiceList.height)

            visible: choiceList.contentHeight > choiceList.height
            x: 355
            y: 16 + travel * Math.max(0, Math.min(1, choiceList.contentY / scrollRange))
            width: 2
            height: 116
            radius: 17
            color: "#ba98e2"
            opacity: 0.2
        }
    }
}
