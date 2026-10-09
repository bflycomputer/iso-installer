pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    property Item shell: null
    readonly property bool childOwnsFocus: true
    property int activeRow: 0
    readonly property int rowCount: 2
    property bool passwordVisible: false
    property var maskSequence: []

    readonly property bool connecting: controller.wifi.connecting
    readonly property string joinError: controller.errorMessage !== "" ? controller.errorMessage : controller.wifi.errorMessage
    readonly property bool joinFailed: !connecting && joinError !== ""
    readonly property int selectedStrength:
        controller.selectedNetworkStrength

    readonly property var maskGlyphs: ["../../assets/icons/password-mask-plant.svg",
                                       "../../assets/icons/password-mask-lily-pad.svg",
                                       "../../assets/icons/password-mask-leaf.svg"]

    // A newly typed character never repeats the glyph before it; existing
    // glyphs stay put rather than reshuffling on every keystroke.
    function syncMaskSequence(length) {
        const target = Math.max(0, Math.min(22, Number(length) || 0))
        const sequence = maskSequence.slice(0, target)
        while (sequence.length < target) {
            let glyph = Math.floor(Math.random() * maskGlyphs.length)
            if (sequence.length > 0 && glyph === sequence[sequence.length - 1])
                glyph = (glyph + 1 + (sequence.length % 2)) % maskGlyphs.length
            sequence.push(glyph)
        }
        maskSequence = sequence
    }

    function focusPassword() { Qt.callLater(function() { password.forceActiveFocus() }) }

    function moveSelection(delta) {
        activeRow = (activeRow + delta + rowCount) % rowCount
        password.forceActiveFocus()
    }

    function chooseIndex(index) {
        if (index >= 0 && index < rowCount)
            activeRow = index
        password.forceActiveFocus()
    }

    function togglePasswordVisibility() {
        passwordVisible = !passwordVisible
        password.forceActiveFocus()
    }

    function accept() {
        if (activeRow === 1)
            togglePasswordVisibility()
        else
            submit()
    }

    function submit() {
        if (!connecting)
            controller.connectSelectedNetwork(password.text)
    }

    Component.onCompleted: {
        syncMaskSequence(password.length)
        focusPassword()
    }
    onVisibleChanged: if (visible) focusPassword()

    Title {
        y: 310
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Connect to Wifi"
    }

    Rectangle {
        x: 685
        y: 396
        width: 358
        height: 167
        radius: 16
        color: Theme.surface

        Label {
            x: 20
            y: 20
            width: 285
            elide: Text.ElideRight
            text: "Join “" + (controller.selectedSsid) + "”"
            color: Theme.textWhite
            font: Theme.lg
            lh: Theme.lhLg
        }

        WifiSignal {
            x: 318
            y: 24
            width: 20
            height: 20
            strength: root.selectedStrength
        }

        Rectangle {
            x: 20
            y: 63
            width: 318
            height: 1
            color: Theme.textWhite
            opacity: 0.1
        }

        Row {
            id: connectingDots
            visible: root.connecting
            x: 20
            y: 88
            spacing: 6
            property int frame: 0

            Timer {
                interval: Theme.motionFrameMs
                running: connectingDots.visible
                repeat: true
                onTriggered: connectingDots.frame = (connectingDots.frame + 1) % 3
            }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.green
                    opacity: connectingDots.frame === index ? 1 : 0.3
                }
            }
        }

        Label {
            visible: root.connecting
            x: 60
            y: Theme.capYSm(84)
            text: "Connecting to this network…"
            color: Theme.textWhite
            opacity: 0.7
            font: Theme.sm
            lh: Theme.lhSm
        }

        Label {
            visible: !root.connecting
            x: 20
            y: Theme.capYBase(80)
            text: "Password"
            color: Theme.textWhite
            font: Theme.base
            lh: Theme.lhBase
        }

        Item {
            visible: !root.connecting
            x: 310
            y: 68
            width: 36
            height: 36

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: "transparent"
                border.width: root.activeRow === 1 || eyeArea.containsMouse ? 1 : 0
                border.color: Theme.green
            }
            Image {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: root.passwordVisible ? "../../assets/icons/eye-closed.svg"
                                             : "../../assets/icons/eye-open.svg"
                sourceSize: Qt.size(40, 40)
            }
            MouseArea {
                id: eyeArea
                anchors.fill: parent
                enabled: !root.connecting
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.activeRow = 0
                    root.togglePasswordVisibility()
                }
            }
        }

        Rectangle {
            visible: !root.connecting
            x: 20
            y: 103
            width: 318
            height: 44
            radius: 12
            color: Theme.fieldOnSurface

            TextInput {
                id: password
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                echoMode: root.passwordVisible ? TextInput.Normal : TextInput.NoEcho
                color: root.passwordVisible ? Theme.green : "transparent"
                selectionColor: Theme.lavender
                selectedTextColor: Theme.onWifiActive
                cursorVisible: root.passwordVisible && activeFocus && root.activeRow === 0
                readOnly: root.activeRow !== 0 || root.connecting
                font: Theme.base
                verticalAlignment: TextInput.AlignVCenter
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                onTextChanged: root.syncMaskSequence(length)
                Keys.forwardTo: root.shell ? [root.shell] : []
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Tab) {
                        root.moveSelection(event.modifiers & Qt.ShiftModifier ? -1 : 1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Space && root.activeRow === 1) {
                        if (!event.isAutoRepeat)
                            root.togglePasswordVisibility()
                        event.accepted = true
                    }
                }
            }

            Row {
                visible: !root.passwordVisible
                x: 12
                y: 16
                spacing: 2
                clip: true
                width: 270

                Repeater {
                    model: Math.min(password.length, 22)
                    Image {
                        required property int index
                        width: 12
                        height: 12
                        source: root.maskGlyphs[root.maskSequence[index] !== undefined
                                                ? root.maskSequence[index] : index % root.maskGlyphs.length]
                        sourceSize: Qt.size(24, 24)
                    }
                }
            }

            TapHandler {
                onTapped: {
                    root.activeRow = 0
                    password.forceActiveFocus()
                }
            }
        }
    }

    ErrorText {
        visible: root.joinFailed
        y: 580
        text: root.joinError
    }

    NavBar {
        y: 613
        anchors.horizontalCenter: parent.horizontalCenter
        showChevrons: false
        label: root.connecting ? "Connecting…" : (root.joinFailed ? "Try again" : "Connect")
    }
}
