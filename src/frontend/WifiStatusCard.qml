import QtQuick

Rectangle {
    id: root

    property bool showStatus: true
    property bool busy: false
    property string message: ""

    width: 358
    height: 167
    radius: 16
    color: Theme.surface

    Row {
        id: joining
        objectName: "wifiJoining"
        visible: root.showStatus && root.busy
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 0.5
        anchors.verticalCenterOffset: 0.5
        spacing: 20
        property int frame: 0
        onVisibleChanged: frame = 0

        Timer {
            interval: Theme.motionFrameMs
            running: joining.visible
            repeat: true
            onTriggered: joining.frame = 1 - joining.frame
        }

        Image {
            objectName: "wifiJoiningLoader"
            width: 50
            height: 50
            source: joining.frame === 0 ? "assets/animations/joining-straight.svg"
                                        : "assets/animations/joining-diagonal.svg"
            sourceSize: Qt.size(100, 100)
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.message
            color: Theme.lavender
            font: Theme.xlItalic
            lh: Theme.lhXl
        }
    }

    Label {
        objectName: "wifiJoinFailure"
        visible: root.showStatus && !root.busy
        anchors.centerIn: parent
        width: parent.width - 40
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.message
        color: Theme.statusError
        font: Theme.xlItalic
        lh: Theme.lhXl
    }
}
