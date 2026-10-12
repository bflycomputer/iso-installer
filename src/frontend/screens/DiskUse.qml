pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    readonly property int rowCount: options.count
    readonly property int activeRow: rowCount > 0
        ? Math.max(0, Math.min(rowCount - 1, controller.selectedInstallOption)) : -1
    readonly property var drive: controller.selectedDriveData

    function chooseIndex(index) {
        if (index >= 0 && index < rowCount)
            controller.selectedInstallOption = index
    }
    function moveSelection(delta) {
        if (rowCount > 0)
            chooseIndex((activeRow + delta + rowCount) % rowCount)
    }
    function accept() {
        controller.selectedInstallOption = activeRow
        controller.advance()
    }

    Title {
        y: 270
        width: 283
        x: 864.5 - width / 2
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "How should Pond use this disk?"
        color: Theme.textCream
    }

    Rectangle {
        y: 366
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(144, driveName.implicitWidth + 28, driveDetails.implicitWidth + 28)
        height: 59
        radius: 4
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0.796, 0.651, 0.969, 0.6)

        Label {
            id: driveName
            x: 14
            y: 10
            text: root.drive ? root.drive.name : ""
            color: Theme.lavender
            font: Theme.displaySm
            lh: Theme.lhDisplaySm
        }
        Label {
            id: driveDetails
            x: 14
            y: Theme.capYSm(34)
            text: root.drive ? root.drive.detail + " • " + root.drive.capacity + " • " + root.drive.used + " used" : ""
            color: Theme.lavender
            opacity: 0.7
            font: Theme.sm
            lh: Theme.lhSm
        }
    }

    Rectangle {
        x: 863
        y: 433
        width: 1
        height: 16
        color: Theme.lavender
    }

    ListView {
        id: options
        objectName: "installChoices"
        x: 504
        y: 457
        width: 720
        height: Math.min(430, count * 99 + Math.max(0, count - 1) * spacing)
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: controller.installOptions
        currentIndex: root.activeRow
        highlightMoveDuration: 0

        delegate: InstallOptionCard {
            id: card
            required property int index
            required property var modelData
            number: index + 1
            active: index === root.activeRow
            title: modelData.mode === "free-space" ? "Install in unallocated space"
                                                    : "Erase entire drive and install Pond"
            detail: modelData.mode === "free-space"
                    ? "Use space that’s already free without erasing the rest of the drive."
                    : modelData.preservesEfi
                      ? "Delete everything on the selected drive (EFI partition is preserved)."
                      : "Delete everything on the selected drive and use all of it for Pond."
            onSelected: root.chooseIndex(index)
            onAccepted: {
                root.chooseIndex(index)
                root.accept()
            }

        }
    }

    ErrorText {
        y: 675
    }

    NavBar {
        y: 701
        anchors.horizontalCenter: parent.horizontalCenter
        label: "Confirm"
    }
}
