import QtQuick

Item {
    id: field

    property string label: ""
    property bool active: false
    property color labelColor: active ? Theme.onAccent : Theme.textWhite
    property int labelWidth: 146
    // Profile's two-line labels sit 4 px lower with a 20 px line box.
    property bool compactLabel: false
    default property alias content: inner.data

    signal clicked

    width: labelWidth + 6 + 379
    height: 68

    // Below the blocks so a text input placed in the value box still gets
    // its own clicks; the blocks themselves let clicks fall through.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: field.clicked()
    }

    Rectangle {
        width: field.labelWidth
        height: 68
        radius: 16
        color: field.active ? Theme.lavender : Theme.surface

        Label {
            x: 20
            y: field.compactLabel ? 24 : 20
            lh: field.compactLabel ? 20 : 28
            text: field.label
            color: field.labelColor
            font: Theme.lg
        }
    }

    Rectangle {
        x: field.labelWidth + 6
        width: 379
        height: 68
        radius: 16
        color: field.active ? Theme.lavender : Theme.surface

        Rectangle {
            id: inner
            x: 10
            y: 10
            width: 359
            height: 48
            radius: 8
            color: field.active ? Theme.fieldOnLavender : Theme.fieldOnSurface
        }
    }

    Image {
        x: field.labelWidth - 9
        y: 22
        width: 24
        height: 24
        source: field.active ? "../assets/icons/dot-active.svg" : "../assets/icons/dot-idle.svg"
        sourceSize: Qt.size(48, 48)
    }
}
