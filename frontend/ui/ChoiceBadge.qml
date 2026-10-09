import QtQuick

Rectangle {
    id: badge
    required property int number
    property bool active: false
    property int numeralOffset: 0

    width: 48
    height: 48

    radius: 24
    color: badge.active ? Theme.lavender : Theme.surface

    Rectangle {
        anchors.centerIn: parent
        width: 30
        height: 30
        radius: 15
        color: Theme.bg

        Label {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: badge.numeralOffset
            text: String(badge.number)
            color: Theme.numText
            font: Theme.base
            lh: Theme.lhBase
        }
    }
}
