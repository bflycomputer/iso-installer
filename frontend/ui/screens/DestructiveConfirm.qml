import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    readonly property int rowCount: 0
    readonly property var option: controller.installOptions[controller.selectedInstallOption] || ({})
    readonly property var drive: controller.selectedDriveData

    function accept() { controller.advance() }

    Rectangle {
        x: 605
        y: 384
        width: 518
        height: 269
        radius: 24
        color: Theme.surface

        Title {
            x: 40
            y: 43
            width: 438
            text: "Erase this disk and install Pond?"
        }

        Label {
            x: 40
            y: Theme.capYSmR(88)
            width: 438
            wrapMode: Text.WordWrap
            text: "Everything on this disk will be permanently erased. Pond will then use the entire disk."
                  + (root.option.preservesEfi ? " (EFI partition is preserved)." : "")
            color: Theme.textWhite
            opacity: 0.7
            font: Theme.smR
            lh: Theme.lhSm
        }

        Rectangle {
            x: 40
            y: 146
            width: 438
            height: 83
            radius: 12
            color: Theme.cardInset

            Label {
                x: 20
                y: 16
                width: 398
                elide: Text.ElideRight
                text: root.drive.name || "Selected disk"
                color: Theme.textWhite
                font: Theme.lg
                lh: Theme.lhLg
            }
            Label {
                x: 20
                y: Theme.capYBaseR(49)
                width: 398
                elide: Text.ElideRight
                text: (root.drive.capacity || "Unknown") + " Storage • " + (root.drive.used || "Unknown") + " in use"
                color: Theme.textWhite
                opacity: 0.6
                font: Theme.baseR
                lh: Theme.lhBase
            }
        }
    }

    ChoiceBadge {
        x: 840
        y: 360
        number: controller.selectedInstallOption + 1
    }

    NavBar {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 693
    }
}
