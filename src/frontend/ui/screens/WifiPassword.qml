pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    property Item shell: null
    readonly property bool childOwnsFocus: editing
    property int activeRow: 0
    readonly property int rowCount: 2
    property bool passwordVisible: false

    readonly property bool connecting: controller.wifi.connecting
    property bool joinFailed: false
    readonly property bool editing: !connecting && !joinFailed
    readonly property int selectedStrength:
        controller.selectedNetworkStrength

    function focusPassword() {
        Qt.callLater(function() {
            if (root.editing)
                password.forceActiveFocus()
        })
    }

    function moveSelection(delta) {
        if (!editing)
            return
        activeRow = (activeRow + delta + rowCount) % rowCount
        password.forceActiveFocus()
    }

    function chooseIndex(index) {
        if (!editing)
            return
        if (index >= 0 && index < rowCount)
            activeRow = index
        password.forceActiveFocus()
    }

    function togglePasswordVisibility() {
        if (!editing)
            return
        passwordVisible = !passwordVisible
        password.forceActiveFocus()
    }

    function accept() {
        if (editing && activeRow === 1)
            togglePasswordVisibility()
        else
            submit()
    }

    function submit() {
        if (connecting)
            return
        if (joinFailed) {
            activeRow = 0
            joinFailed = false
            return
        }
        controller.connectSelectedNetwork(password.text)
    }

    Connections {
        target: controller.wifi
        function onConnectionFailed() { root.joinFailed = true }
    }

    onConnectingChanged: if (connecting) joinFailed = false
    onEditingChanged: {
        if (editing)
            focusPassword()
        else if (shell)
            shell.forceActiveFocus()
    }

    Component.onCompleted: {
        focusPassword()
    }
    onVisibleChanged: if (visible) focusPassword()

    Title {
        y: 376
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Connect to Wifi"
    }

    Rectangle {
        objectName: "wifiJoinCard"
        x: 685
        y: 454
        width: 358
        height: 167
        radius: 16
        color: Theme.surface

        Item {
            anchors.fill: parent
            visible: root.editing

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

            Label {
                x: 20
                y: Theme.capYBase(80)
                text: "Password"
                color: Theme.textWhite
                font: Theme.base
                lh: Theme.lhBase
            }

            Item {
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
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.activeRow = 0
                        root.togglePasswordVisibility()
                    }
                }
            }

            Rectangle {
                x: 20
                y: 103
                width: 318
                height: 44
                radius: 12
                color: Theme.fieldOnSurface

                PasswordInput {
                    id: password
                    objectName: "wifiPasswordInput"
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    masked: !root.passwordVisible
                    whiteMask: false
                    textColor: Theme.green
                    readOnly: root.activeRow !== 0 || !root.editing
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
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

                TapHandler {
                    onTapped: {
                        root.activeRow = 0
                        password.forceActiveFocus()
                    }
                }
            }
        }

        Row {
            id: joining
            objectName: "wifiJoining"
            visible: root.connecting
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 0.5
            anchors.verticalCenterOffset: 0.5
            spacing: 20
            property int frame: 0
            onVisibleChanged: frame = 0

            Timer {
                interval: Theme.motionFrameMs
                running: joining.visible
                repeat: true
                onTriggered: joining.frame = 1 - joining.frame
            }

            Image {
                objectName: "wifiJoiningLoader"
                width: 50
                height: 50
                source: joining.frame === 0 ? "../../assets/animations/joining-straight.svg"
                                            : "../../assets/animations/joining-diagonal.svg"
                sourceSize: Qt.size(100, 100)
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Joining"
                color: Theme.lavender
                font: Theme.xlItalic
                lh: Theme.lhXl
            }
        }

        Label {
            objectName: "wifiJoinFailure"
            visible: root.joinFailed && !root.connecting
            anchors.centerIn: parent
            text: "Failed to connect"
            color: Theme.statusError
            font: Theme.xlItalic
            lh: Theme.lhXl
        }
    }

    NavBar {
        objectName: "wifiJoinNavigation"
        visible: !root.connecting
        y: 661
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12
        label: root.joinFailed ? "Try again" : "Connect"
    }
}
