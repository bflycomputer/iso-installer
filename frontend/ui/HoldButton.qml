import QtQuick

// The 240x64 Pond-green pill for irreversible actions: hold Enter or the
// pointer for three seconds; the lavender fill shows progress. The owning
// screen implements beginAccept/endAccept and receives `completed`.
Rectangle {
    id: button

    property string label: ""
    property bool busy: false
    property string busyLabel: ""
    property real progress: 0
    property int holdMs: 3000
    signal completed

    width: 240
    height: 64
    radius: 54
    color: Theme.green
    clip: true

    function begin() {
        if (busy || hold.running)
            return
        progress = 0
        hold.restart()
    }

    function end() {
        if (!busy && hold.running) {
            hold.stop()
            progress = 0
        }
    }

    NumberAnimation {
        id: hold
        target: button
        property: "progress"
        from: 0
        to: 1
        duration: button.holdMs
        onFinished: button.completed()
    }

    // Reveal a full-size pill so its curved edge stays fixed as progress
    // advances. Resizing a rounded rectangle distorts the left cap and
    // leaks into the corners: an Item's clip only clips its bounding box.
    Item {
        width: button.width * button.progress
        height: button.height
        clip: true

        Rectangle {
            width: button.width
            height: button.height
            radius: button.radius
            color: Theme.lavender
            opacity: 0.72
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 10

        Image {
            width: 20
            height: 20
            source: "../assets/icons/enter-key.svg"
            sourceSize: Qt.size(40, 40)
        }
        Label {
            text: button.busy ? button.busyLabel : button.label
            color: Theme.onAccent
            font: Theme.base
            lh: Theme.lhBase
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: button.begin()
        onReleased: button.end()
        onCanceled: button.end()
    }
}
