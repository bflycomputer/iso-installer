import QtQuick
import ".."

// The last screen: "Pond is ready" or why the installation stopped.
Rectangle {
    id: root

    readonly property bool failed: Boolean(controller.failed)
    readonly property string failureMessage: String(controller.failureMessage)
    readonly property string failureDetails: String(controller.warnings)
    readonly property real designScale: Math.min(width / 1728, height / 1117)

    color: "#1a1409"
    focus: true

    Keys.onPressed: function(event) {
        if (!root.failed && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            controller.restartComputer()
            event.accepted = true
        } else if (root.failed && event.key === Qt.Key_Escape) {
            controller.powerOffComputer()
            event.accepted = true
        }
    }

    Image {
        objectName: "pondLogo"
        width: 100
        height: 100
        source: "../../assets/icons/pond-letters.svg"
        sourceSize: Qt.size(200, 200)
        scale: root.designScale
        transformOrigin: Item.Top
        anchors.top: parent.top
        anchors.topMargin: 20 * root.designScale
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Column {
        width: Math.min(760 * root.designScale, parent.width - 80 * root.designScale)
        spacing: 28 * root.designScale
        anchors.centerIn: parent

        Text {
            width: parent.width
            text: root.failed ? "Pond couldn’t be installed" : "Pond is ready"
            color: root.failed ? "#cbe25b" : "#cba6f7"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: Theme.displayFont
            font.pixelSize: 32 * root.designScale
            font.letterSpacing: -0.64 * root.designScale
        }

        Text {
            width: parent.width
            text: root.failed
                ? (root.failureMessage.length > 0 ? root.failureMessage : "The installation stopped before it finished.")
                : "Restart the computer to begin using your new system."
            color: "#f8fff1"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: Theme.onest.name
            font.pixelSize: 15 * root.designScale
            font.weight: Font.Medium
        }

        Text {
            visible: root.failureDetails.length > 0
            width: parent.width
            height: Math.min(160 * root.designScale, implicitHeight)
            text: root.failureDetails
            color: "#868686"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 6
            font.family: Theme.onest.name
            font.pixelSize: 13 * root.designScale
        }

        Rectangle {
            width: actionText.implicitWidth + 44 * root.designScale
            height: 44 * root.designScale
            radius: height / 2
            color: root.failed ? "#33273d" : "#cbe25b"
            anchors.horizontalCenter: parent.horizontalCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.failed) controller.powerOffComputer()
                    else controller.restartComputer()
                }
            }

            Text {
                id: actionText
                anchors.centerIn: parent
                text: root.failed ? "ESC   Shut down" : "Enter   Restart"
                color: root.failed ? "#f8fff1" : "#23270d"
                font.family: Theme.onest.name
                font.pixelSize: 15 * root.designScale
                font.weight: Font.Medium
            }
        }

        Text {
            visible: controller.errorMessage !== ""
            width: parent.width
            text: controller.errorMessage
            color: Theme.textError
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: Theme.onest.name
            font.pixelSize: 15 * root.designScale
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 10 * root.designScale
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10 * root.designScale
        text: "Early Preview"
        color: "#f8fff1"
        font.family: Theme.displayFont
        font.pixelSize: 32 * root.designScale
    }

    Text {
        width: 228 * root.designScale
        anchors.right: parent.right
        anchors.rightMargin: 22 * root.designScale
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14 * root.designScale
        text: "Some features may not work as expected. Please report any issues or bugs."
        color: "#868686"
        wrapMode: Text.WordWrap
        font.family: Theme.onest.name
        font.pixelSize: 11 * root.designScale
        font.weight: Font.Medium
    }
}
