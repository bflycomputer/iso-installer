import QtQuick

Rectangle {
    property bool failed: false
    objectName: "pondLogo"
    width: 100
    height: 100
    color: Theme.surface

    Rectangle {
        x: 0; y: 50; width: 50; height: 50
        color: Theme.green; visible: parent.failed
    }

    // One continuous background prevents seams at fractional display scales.
    Image {
        anchors.fill: parent
        source: "../assets/branding/pond-letters.svg"
        sourceSize: Qt.size(200, 200)
    }
}
