pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    width: 359
    height: searchable || choices.length >= 7 ? 272 : 16 + 40 * choices.length

    property var choices: []
    property int highlightedIndex: -1
    property bool searchable: false
    property Item shell: null
    property alias query: search.text

    signal chosen(int index)
    signal highlighted(int index)
    signal tabbed(int direction)

    function focusSearch() { search.forceActiveFocus() }

    function positionAt(index) {
        if (index < 0 || index >= choices.length)
            return
        Theme.blockHover()
        if (searchable && index === 0)
            choiceList.positionViewAtBeginning()
        else
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
            visible: !root.searchable
            x: modelData.x
            y: modelData.y
            width: root.width + modelData.grow
            height: root.height + modelData.grow / 2
            radius: 12
            color: "#000000"
            opacity: modelData.alpha
        }
    }

    MenuShadow {
        anchors.fill: parent
        visible: root.searchable
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 8
        color: Theme.fieldOnLavender
        clip: true

        MenuShadow {
            width: parent.width
            height: 51
            visible: root.searchable
        }

        ListView {
            id: choiceList
            objectName: "setupChoices"
            // The authored content frame is inset by 8.5 px on both sides.
            x: 8.5
            y: root.searchable ? 51 : 8
            width: 342
            height: root.height - y
            clip: true
            model: root.choices
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            reuseItems: true
            onContentYChanged: Theme.blockHover()
            header: Item { height: root.searchable ? (root.query.trim() ? 7 : 8) : 0 }

            delegate: Rectangle {
                id: choiceRow
                objectName: "setupChoice" + index
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
                    text: !root.searchable && choiceRow.modelData.detail
                          ? choiceRow.modelData.detail + "  ·  " + choiceRow.modelData.label
                          : choiceRow.modelData.label
                    elide: Text.ElideRight
                    color: choiceRow.highlighted ? "#000000" : Theme.textWhite
                    font: Theme.sm
                    lh: Theme.lhSm
                    renderType: root.searchable ? Text.CurveRendering : Text.QtRendering
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (Theme.hoverAllowed()) root.highlighted(choiceRow.index)
                    onPositionChanged: if (containsMouse && Theme.hoverAllowed()) root.highlighted(choiceRow.index)
                    onClicked: root.chosen(choiceRow.index)
                }
            }
        }

        Label {
            visible: root.searchable && root.choices.length === 0
            x: 20
            y: 74
            text: "No time zones found"
            renderType: Text.CurveRendering
            font: Theme.sm
            lh: Theme.lhSm
            color: Theme.textWhite
            opacity: 0.7
        }

        Item {
            width: parent.width
            height: 51
            visible: root.searchable

            Rectangle {
                anchors.fill: parent
                topLeftRadius: 8
                topRightRadius: 8
                color: Theme.searchSurface
            }

            Rectangle {
                y: 50
                width: parent.width
                height: 1
                color: Theme.searchDivider
            }

            TapHandler { onTapped: root.focusSearch() }

            Label {
                x: 20
                y: Theme.capYSm(21)
                visible: search.text.length === 0
                text: "Start searching"
                renderType: Text.CurveRendering
                color: Theme.textWhite
                opacity: 0.2
                font: Theme.sm
                lh: Theme.lhSm
            }

            TextInput {
                id: search
                objectName: "timezoneSearch"
                x: 20
                y: Theme.capYSm(21)
                width: parent.width - 40
                height: Theme.lhSm
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                selectByMouse: true
                color: Theme.textWhite
                selectionColor: Theme.lavender
                selectedTextColor: Theme.onAccent
                font: Theme.sm
                inputMethodHints: Qt.ImhNoPredictiveText
                renderType: TextInput.CurveRendering
                Accessible.name: "Search time zones"
                Keys.forwardTo: root.shell ? [root.shell] : []
                Keys.onTabPressed: root.tabbed(1)
                Keys.onBacktabPressed: root.tabbed(-1)

                cursorDelegate: Item {
                    id: caret
                    width: 1
                    Rectangle {
                        x: 1
                        y: 3
                        width: 1
                        height: 12
                        color: Theme.green
                    }
                    Timer {
                        interval: Math.max(1, Qt.styleHints.cursorFlashTime / 2)
                        running: search.cursorVisible && Qt.styleHints.cursorFlashTime > 0
                        repeat: true
                        onRunningChanged: caret.opacity = 1
                        onTriggered: caret.opacity = 1 - caret.opacity
                    }
                }
            }
        }

        Rectangle {
            readonly property real trackTop: root.searchable ? 61 : 16
            readonly property real travel: panel.height - trackTop - 16 - height
            readonly property real scrollRange: Math.max(1, choiceList.contentHeight - choiceList.height)

            visible: choiceList.contentHeight > choiceList.height
            x: 355
            y: trackTop + travel * Math.max(0, Math.min(1, choiceList.contentY / scrollRange))
            width: 2
            height: 116
            radius: 17
            color: "#ba98e2"
            opacity: 0.2
        }
    }
}
