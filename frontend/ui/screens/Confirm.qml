pragma ComponentBehavior: Bound
import QtQuick
import ".."

// "Confirm before install": the summary of every choice, then a
// hold-for-three-seconds Start install pill.
Item {
    id: root
    anchors.fill: parent

    property bool showProgressTree: false
    readonly property int rowCount: 0

    readonly property var option: controller.installOptions[controller.selectedInstallOption] || ({})
    readonly property var drive: controller.selectedDriveData
    readonly property real driveBytes: Number(drive.capacityBytes || 0)
    readonly property real rootBytes: Number(option.rootBytes || 0)
    function capacityLabel() { return String(option.capacity || "") }

    function beginAccept() { startButton.begin() }
    function endAccept() { startButton.end() }

    Title {
        y: 195
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Confirm before install"
    }

    component Summary: Rectangle {
        property var rows: []
        x: 540
        width: 648
        height: 97
        radius: 12
        color: Theme.surface

        Repeater {
            model: parent.rows
            Item {
                required property int index
                required property var modelData
                x: 28 + index * 174
                width: 160
                height: 97

                Label {
                    y: 18
                    text: parent.modelData.label
                    color: Theme.textWhite
                    font: Theme.lg
                    lh: Theme.lhLg
                }
                Label {
                    y: Theme.capYBase(54)
                    width: 155
                    elide: Text.ElideRight
                    text: parent.modelData.value
                    color: Theme.textWhite
                    font: Theme.base
                    lh: Theme.lhBase
                }
            }
        }
    }

    Summary {
        y: 291
        rows: [{ label: "Language", value: controller.languageLabel },
               { label: "Keyboard", value: controller.keyboardLabel },
               { label: "Region", value: controller.regionLabel }]
    }

    Rectangle {
        x: 540
        y: 396
        width: 648
        height: 92
        radius: 12
        color: Theme.surface

        OptionTitle {
            x: 24
            y: 32
            width: 430
            freeSpace: root.option.mode === "free-space"
            emptyDisk: Boolean(root.drive.empty)
        }
        StorageBar {
            x: 474
            y: 26
            segments: root.option.plannedSegments || []
        }
        Label {
            x: 24; y: 65; width: 430
            text: (root.drive.name || "") + " · " + (root.drive.path || "")
            elide: Text.ElideRight
            color: Theme.textWhite; opacity: 0.7
            font: Theme.xs; lh: Theme.lhXs
        }
    }

    Rectangle {
        x: 540
        y: 496
        width: 648
        height: 132
        radius: 12
        color: Theme.surface

        Label {
            x: 24
            y: 38
            text: root.capacityLabel() + " for Pond"
            color: Theme.textWhite
            font: Theme.lg
            lh: Theme.lhLg
        }
        Rectangle {
            x: 24
            y: 78
            width: 600
            height: 30
            color: Theme.fieldOnSurface
            border.width: 1
            border.color: Theme.lavender

            Rectangle {
                width: parent.width * (root.driveBytes > 0 ? Math.max(0, Math.min(1, root.rootBytes / root.driveBytes)) : 0)
                height: parent.height
                color: Theme.green
            }
        }
    }

    Summary {
        y: 637
        rows: [{ label: "Username", value: controller.username },
               { label: "Computer", value: controller.hostname },
               { label: "Network", value: !controller.wifi.networkConnected ? "Offline"
                   : (controller.wifi.activeSsid.length > 0 ? controller.wifi.activeSsid
                      : "Wired") }]
    }

    HoldButton {
        id: startButton
        x: 744
        y: 774
        label: "Start install"
        onCompleted: {
            controller.beginInstallation()
            if (controller.errorMessage !== "") {
                progress = 0
            }
        }
    }

    Label {
        y: Theme.capYXs(853)
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Hold for 3s"
        color: Theme.textWhite
        opacity: 0.5
        font: Theme.xs
        lh: Theme.lhXs
    }

    ErrorText {
        y: 884
    }

    EscapeHint {
        onActivated: controller.back()
    }
}
