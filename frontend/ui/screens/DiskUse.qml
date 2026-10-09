pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    readonly property int rowCount: options.count
    readonly property int activeRow: rowCount > 0
        ? Math.max(0, Math.min(rowCount - 1, pond.selectedInstallOption)) : -1
    readonly property var drive: pond.selectedDriveData

    function chooseIndex(index) {
        if (index >= 0 && index < rowCount)
            pond.selectedInstallOption = index
    }
    function moveSelection(delta) {
        if (rowCount > 0)
            chooseIndex((activeRow + delta + rowCount) % rowCount)
    }
    function accept() {
        pond.selectedInstallOption = activeRow
        pond.advance()
    }

    Title {
        y: 243
        width: 283
        x: 864.5 - width / 2
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "How should Pond use this disk?"
        color: Theme.textCream
    }

    Rectangle {
        y: 336
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(144, driveName.implicitWidth + 28, driveDetails.implicitWidth + 28)
        height: 59
        radius: 4
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0.796, 0.651, 0.969, 0.6)

        FText {
            id: driveName
            x: 14
            y: 10
            text: root.drive ? root.drive.name : ""
            color: Theme.lavender
            font: Theme.displaySm
            lh: Theme.lhDisplaySm
        }
        FText {
            id: driveDetails
            x: 14
            y: Theme.capYSm(34)
            text: root.drive ? root.drive.detail + " • " + root.drive.capacity + " • " + root.drive.used + " allocated" : ""
            color: Theme.lavender
            opacity: 0.7
            font: Theme.sm
            lh: Theme.lhSm
        }
    }

    ListView {
        id: options
        objectName: "installChoices"
        x: 504
        y: 427
        width: 720
        height: Math.min(430, count * 99 + Math.max(0, count - 1) * spacing)
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: pond.installOptions
        currentIndex: root.activeRow
        highlightMoveDuration: 0
        onContentYChanged: Theme.blockHover()

        delegate: DecisionCard {
            id: card
            required property int index
            required property var modelData
            number: index + 1
            active: index === root.activeRow
            freeSpace: modelData.type === "empty"
            detail: String(modelData.detail || "")
            onSelected: root.chooseIndex(index)
            onAccepted: {
                root.chooseIndex(index)
                root.accept()
            }

            StorageBar {
                anchors.fill: parent
                segments: card.modelData.plannedSegments
                animationMode: card.modelData.type === "erase" ? "erase" : "none"
            }
        }
    }

    ErrorText {
        y: 638
    }

    NavBar {
        y: 663
        anchors.horizontalCenter: parent.horizontalCenter
        label: "Confirm"
    }
}
