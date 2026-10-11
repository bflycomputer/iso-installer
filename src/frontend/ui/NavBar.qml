import QtQuick

Row {
    id: nav

    property string label: "Confirm"
    property bool showBack: true
    property bool primaryEnabled: true
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
        objectName: "navigationBack"
        visible: nav.showBack
        width: 64
        height: 64
        radius: 32
        color: backPointer.containsMouse ? Theme.lavender : Theme.surface

        Image {
            anchors.centerIn: parent
            width: 24
            height: 24
            source: backPointer.containsMouse ? "../assets/icons/navigation-back-hover.svg"
                                              : "../assets/icons/navigation-back.svg"
            sourceSize: Qt.size(48, 48)
        }

        MouseArea {
            id: backPointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: controller.back()
        }
    }

    Rectangle {
        objectName: "navigationConfirm"
        width: 240
        height: 64
        radius: 32
        readonly property bool highlighted: nav.primaryEnabled && (confirmPointer.containsMouse || nav.focused)
        color: !nav.primaryEnabled ? Theme.disabled : highlighted ? Theme.lavender : Theme.green
        enabled: nav.primaryEnabled

        Label {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 2
            text: nav.label
            color: !nav.primaryEnabled ? Theme.bg : parent.highlighted ? Theme.surface : Theme.onAccent
            font: Theme.base
            lh: Theme.lhBase
        }

        MouseArea {
            id: confirmPointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.submit()
        }
    }
}
