pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import ".."

// Installation status with an indeterminate activity animation.
Rectangle {
    id: root

    readonly property string status: String(pond.status)

    // Names the machine being installed onto; the design shows up to four
    // words as coloured tags.
    readonly property string deviceName: pond.deviceName ? String(pond.deviceName) : "Pond"

    color: "#1a1409"
    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat) cancelPill.begin()
            event.accepted = true
        }
    }
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat) cancelPill.end()
            event.accepted = true
        }
    }
    Connections {
        target: root.Window.window
        function onActiveChanged() { if (!target.active) cancelPill.end() }
    }

    readonly property real designScale: Math.min(width / 1728, height / 1117)
    property int tick: 0
    readonly property int activeBlock: Math.floor(tick / 6) % 10

    readonly property var words: {
        const parts = String(deviceName).trim().split(/\s+/)
        const kept = []
        for (let i = 0; i < parts.length && kept.length < 4; ++i)
            if (parts[i].length > 0)
                kept.push(parts[i])
        return kept.length > 0 ? kept : ["Pond"]
    }

    readonly property int bufferFrame: Math.floor(tick / 3) % 2
    readonly property var loaderFrames: [
        ["cross-straight.svg", "cross-diagonal.svg"],
        ["diamond.svg", "square.svg"],
        ["download-raised.svg", "download-lowered.svg"],
        ["hourglass.svg", "hourglass.svg"],
        ["sprout.svg", "plant.svg"]
    ]

    readonly property var deviceColorSets: [
        [{ bg: "#ffe51d", fg: "#632b0f" }, { bg: "#ff9f67", fg: "#632b0f" },
         { bg: "#cba6f7", fg: "#33273d" }, { bg: "#ff9faf", fg: "#632b0f" }],
        [{ bg: "#ff9faf", fg: "#33273d" }, { bg: "#cef058", fg: "#1b322d" },
         { bg: "#ff9f67", fg: "#632b0f" }, { bg: "#ffe51d", fg: "#632b0f" }],
        [{ bg: "#cba6f7", fg: "#33273d" }, { bg: "#ffe51d", fg: "#632b0f" },
         { bg: "#94e2d5", fg: "#33273d" }, { bg: "#cef058", fg: "#1b322d" }]
    ]
    readonly property var installationColorSets: [
        [{ bg: "#ffe51d", fg: "#632b0f" }, { bg: "#cef058", fg: "#1b322d" },
         { bg: "#ff9f67", fg: "#632b0f" }, { bg: "#632b0f", fg: "#ff9f67" }],
        [{ bg: "#ff9f67", fg: "#632b0f" }, { bg: "#cba6f7", fg: "#33273d" },
         { bg: "#ff9faf", fg: "#632b0f" }, { bg: "#33273d", fg: "#ff9faf" }],
        [{ bg: "#cba6f7", fg: "#33273d" }, { bg: "#ffe51d", fg: "#632b0f" },
         { bg: "#cef058", fg: "#1b322d" }, { bg: "#1b322d", fg: "#cef058" }]
    ]

    function labelSet(index) {
        const order = index < 4 ? index : words.length + index - 4
        return Math.floor(Math.max(0, tick - order - 1) / 20) % 3
    }

    Timer {
        interval: 250
        running: root.visible
        repeat: true
        onTriggered: root.tick += 1
    }

    Item {
        width: 1728
        height: 1117
        anchors.centerIn: parent
        scale: root.designScale
        transformOrigin: Item.Center

        Column {
            x: 824
            y: 159
            width: 80
            height: 800

            Repeater {
                model: 10

                Item {
                    id: block
                    required property int index
                    width: 80
                    height: 80
                    clip: true

                    readonly property bool active: index === root.activeBlock

                    // One 1 px separator between cells: every cell but the
                    // last lets the clip swallow its bottom edge.
                    Rectangle {
                        width: parent.width
                        height: block.index === 9 ? parent.height : parent.height + 1
                        color: "transparent"
                        border.width: 1
                        border.color: "#cba6f7"
                        visible: !block.active
                    }

                    Item {
                        anchors.fill: parent
                        visible: block.active
                        clip: true

                        readonly property int animation: (block.index % 5) + 1
                        readonly property string frameSource: "../../assets/animations/"
                            + root.loaderFrames[animation - 1][root.bufferFrame]

                        Image {
                            anchors.fill: parent
                            visible: parent.animation <= 3
                            source: parent.animation <= 3 ? parent.frameSource : ""
                            sourceSize: Qt.size(160, 160)
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: parent.animation === 4 || parent.animation === 5
                            color: parent.animation === 4 ? "#ff9f67" : "#ffe51d"

                            Image {
                                visible: parent.parent.animation === 4
                                source: parent.parent.animation === 4 ? parent.parent.frameSource : ""
                                x: 22.056
                                y: 17
                                width: 35.887
                                height: 46.578
                                rotation: root.bufferFrame === 1 ? 90 : 0
                                sourceSize: Qt.size(72, 94)
                            }

                            Image {
                                visible: parent.parent.animation === 5
                                source: parent.parent.animation === 5 ? parent.parent.frameSource : ""
                                x: root.bufferFrame === 0 ? 23.884 : 19
                                y: root.bufferFrame === 0 ? 39.887 : 18.73
                                width: root.bufferFrame === 0 ? 32.233 : 41.999
                                height: root.bufferFrame === 0 ? 20.113 : 41.671
                                sourceSize: Qt.size(84, 84)
                            }
                        }
                    }
                }
            }
        }

        Row {
            x: 10
            y: 532
            height: 54

            Repeater {
                model: root.words

                Item {
                    id: word
                    required property int index
                    required property var modelData
                    // The third and fourth words sit 40 px apart, clearing the
                    // loader column; the first two are adjacent.
                    readonly property int leadingGap: index >= 2 ? 40 : 0
                    width: plate.width + leadingGap
                    height: 54

                    readonly property var colors: root.deviceColorSets[root.labelSet(index)][index]

                    Rectangle {
                        id: plate
                        x: word.leadingGap
                        width: wordText.implicitWidth + 30
                        height: 54
                        color: word.colors.bg

                        Text {
                            id: wordText
                            anchors.centerIn: parent
                            text: word.modelData
                            color: word.colors.fg
                            font.family: Theme.displayFont
                            font.pixelSize: 20
                            font.weight: Font.Normal
                        }
                    }
                }
            }
        }

        Item {
            id: readout
            x: 1322
            y: 532
            width: 396
            height: 54

            readonly property var labels: ["Installing", "Pond", "·", "·"]
            readonly property var offsets: [0, 162.576, 288, 341.578]
            readonly property var widths: [113, 75, 54, 54]

            Repeater {
                model: 4

                Item {
                    id: chip
                    required property int index
                    x: readout.offsets[index]
                    y: 0
                    width: readout.widths[index]
                    height: 54

                    readonly property var colors: root.installationColorSets[root.labelSet(index + 4)][index]

                    Rectangle { anchors.fill: parent; color: chip.colors.bg }

                    Text {
                        anchors.centerIn: parent
                        text: readout.labels[chip.index]
                        color: chip.colors.fg
                        font.family: Theme.displayFont
                        font.pixelSize: 20
                        font.weight: 350
                    }
                }
            }
        }

        PondLogo {
            x: 10
            y: 10
        }

        Rectangle {
            x: 10
            y: 1037
            width: 116
            height: 30
            radius: 4
            color: "transparent"
            border.width: 1
            border.color: "#afc0ff"
            opacity: 0.5

            Text {
                anchors.centerIn: parent
                text: "ISO INSTALLER"
                color: "#afc0ff"
                font.family: Theme.plexMonoMedium.name
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        Text {
            x: 10
            y: 1071
            height: 36
            verticalAlignment: Text.AlignVCenter
            // The installation screen uses the longer wording.
            text: "Early Preview Version"
            color: "#656a84"
            font.family: Theme.displayFont
            font.pixelSize: 32
            font.letterSpacing: -0.64
        }

        Text {
            x: 1580
            y: 1057
            width: 142
            text: "Some features may not work as expected. Please report any issues or bugs."
            color: "#656a84"
            wrapMode: Text.WordWrap
            lineHeight: 16
            lineHeightMode: Text.FixedHeight
            font.family: Theme.onest.name
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.11
        }
        FText {
            y: 978
            anchors.horizontalCenter: parent.horizontalCenter
            width: 700
            horizontalAlignment: Text.AlignHCenter
            text: root.status
            color: Theme.textCream
            font: Theme.base
            lh: Theme.lhBase
        }
        HoldPill {
            id: cancelPill
            x: 744; y: 1020
            label: "Cancel install"
            busyLabel: "Cleaning up…"
            busy: root.status === "Cancelling and cleaning up…"
            onCompleted: pond.cancelInstallation()
        }

        FText {
            y: 1092
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Hold for 3s"
            color: Theme.textCream; opacity: 0.5
            font: Theme.xs; lh: Theme.lhXs
        }
    }
}
