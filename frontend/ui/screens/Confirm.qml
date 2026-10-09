pragma ComponentBehavior: Bound
import QtQuick
import ".."

// "Confirm before install": the summary of every choice, then a
// hold-for-three-seconds Start install pill.
Item {
    id: root
    anchors.fill: parent

    property bool showDecisionTree: false
    readonly property int rowCount: 0

    readonly property var option: pond.installOptions[pond.selectedInstallOption] || ({})
    readonly property var drive: pond.selectedDriveData
    readonly property real driveBytes: Number(drive.capacityBytes || 0)
    readonly property real pondBytes: Number(option.pondBytes || 0)
    function capacityLabel() { return String(option.capacity || "") }

    function beginAccept() { startPill.begin() }
    function endAccept() { startPill.end() }

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

                FText {
                    y: 18
                    text: parent.modelData.label
                    color: Theme.textWhite
                    font: Theme.lg
                    lh: Theme.lhLg
                }
                FText {
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
        rows: [{ label: "Language", value: pond.languageLabel },
               { label: "Keyboard", value: pond.keyboardLabel },
               { label: "Region", value: pond.regionLabel }]
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
            freeSpace: root.option.type === "empty"
            emptyDisk: Boolean(root.drive.empty)
        }
        StorageBar {
            x: 474
            y: 26
            segments: root.option.plannedSegments || []
        }
        FText {
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

        FText {
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
                width: parent.width * (root.driveBytes > 0 ? Math.max(0, Math.min(1, root.pondBytes / root.driveBytes)) : 0)
                height: parent.height
                color: Theme.green
            }
        }
    }

    Summary {
        y: 637
        rows: [{ label: "Username", value: pond.username },
               { label: "Computer", value: pond.hostname },
               { label: "Network", value: !pond.wifi.networkConnected ? "Offline"
                   : (pond.wifi.activeSsid.length > 0 ? pond.wifi.activeSsid
                      : "Wired") }]
    }

    HoldPill {
        id: startPill
        x: 744
        y: 774
        label: "Start install"
        onCompleted: {
            pond.beginInstallation()
            if (pond.errorMessage !== "") {
                progress = 0
            }
        }
    }

    FText {
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
        onActivated: pond.back()
    }
}
