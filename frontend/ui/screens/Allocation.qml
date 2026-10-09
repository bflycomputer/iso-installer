import QtQuick
import ".."

Item {
    id: root
    readonly property int rowCount: 0
    readonly property int minimum: controller.minimumAllocationGiB
    readonly property int maximum: controller.maximumAllocationGiB
    readonly property int amount: controller.allocationGiB
    function moveSelection(delta) { adjust(-delta) }
    function accept() { controller.advance() }
    function adjust(delta) {
        controller.allocationGiB = Math.max(minimum, Math.min(maximum, amount + delta))
    }
    Title {
        y: 310
        anchors.horizontalCenter: parent.horizontalCenter
        text: "How much space for Pond?"
    }
    Rectangle {
        x: 584; y: 416; width: 560; height: 196
        radius: 24
        color: Theme.surface
        Title {
            x: 28; y: 24
            text: root.amount + " GiB"
            color: Theme.lavender
        }
        Rectangle {
            id: track
            x: 28; y: 100; width: 504; height: 6
            radius: 3
            color: Theme.fieldOnSurface
            readonly property real fraction: root.maximum > root.minimum
                ? (root.amount - root.minimum) / (root.maximum - root.minimum) : 1
            Rectangle { width: track.width * track.fraction; height: 6; radius: 3; color: Theme.lavender }
            Rectangle { x: track.width * track.fraction - 10; y: -7; width: 20; height: 20; radius: 10; color: Theme.lavender }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -18
                anchors.bottomMargin: -18
                cursorShape: Qt.PointingHandCursor
                function setAmount(mouse) {
                    controller.allocationGiB = Math.round(root.minimum + Math.max(0, Math.min(1, mouse.x / width)) * (root.maximum - root.minimum))
                }
                onPressed: function(mouse) { setAmount(mouse) }
                onPositionChanged: function(mouse) { if (pressed) setAmount(mouse) }
            }
        }
        Label { x: 28; y: 132; text: root.minimum + " GiB minimum"; color: Theme.textCream; font: Theme.sm; lh: Theme.lhSm }
        Label { x: 320; y: 132; width: 212; horizontalAlignment: Text.AlignRight; text: root.maximum + " GiB available"; color: Theme.textCream; font: Theme.sm; lh: Theme.lhSm }
    }
    Label {
        y: 644; width: 600
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        text: "Existing partitions stay as they are. Any space you leave remains unallocated."
        wrapMode: Text.WordWrap
        color: Theme.textCream; font: Theme.sm; lh: Theme.lhSm
    }
    NavBar { y: 726; anchors.horizontalCenter: parent.horizontalCenter; label: "Confirm" }
}
