import QtQuick

Rectangle {
    objectName: "pondLogo"
    width: 100
    height: 100
    color: Theme.surface

    // One continuous background prevents seams at fractional display scales.
    Image {
        anchors.fill: parent
        source: "../assets/branding/pond-letters.svg"
        sourceSize: Qt.size(200, 200)
    }
}
