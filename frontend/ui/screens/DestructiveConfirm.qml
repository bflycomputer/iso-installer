import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    readonly property int rowCount: 0

    readonly property var option: controller.installOptions[controller.selectedInstallOption] || ({})
    readonly property var drive: controller.selectedDriveData
    readonly property real cardX: 605
    readonly property real cardY: 281

    function accept() {
        controller.advance()
    }

    Rectangle {
        x: root.cardX
        y: root.cardY
        width: 518
        height: 407
        radius: 24
        color: Theme.surface

        StorageBar {
            x: 40
            y: 40
            segments: root.option.plannedSegments || []
            animationMode: "erase"
        }

        Title {
            x: 40
            y: 120
            width: 438
            wrapMode: Text.WordWrap
            text: "Replace the contents of this disk?"
        }

        Label {
            x: 40
            y: Theme.capYSmR(212)
            width: 438
            wrapMode: Text.WordWrap
            text: root.option.preservesEfi
                  ? "The EFI partition will be kept. All other partitions and their files on " + root.drive.path + " will be permanently erased."
                  : "All partitions and files on " + root.drive.path + " will be permanently erased."
            color: Theme.textWhite
            opacity: 0.7
            font: Theme.smR
            lh: Theme.lhSm
        }

        Rectangle {
            x: 40
            y: 284
            width: 420
            height: 83
            radius: 12
            color: Theme.cardInset

            Label {
                x: 20
                y: 20
                width: 380
                elide: Text.ElideRight
                text: root.drive.name || "Selected disk"
                color: Theme.textWhite
                font: Theme.lg
                lh: Theme.lhLg
            }
            Label {
                x: 20
                y: Theme.capYBaseR(53)
                width: 380
                elide: Text.ElideRight
                text: (root.drive.capacity || "Unknown") + " Storage • " + (root.drive.used || "Unknown") + " allocated"
                color: Theme.textWhite
                opacity: 0.6
                font: Theme.baseR
                lh: Theme.lhBase
            }
        }
    }

    ChoiceBadge {
        x: 840
        y: 257
        number: controller.selectedInstallOption + 1
    }

    NavBar {
        x: 864 - width / 2
        y: 728
        label: "Confirm"
        showChevrons: false
    }
}
