pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    property Item shell: null
    readonly property bool childOwnsFocus: editing
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

    function togglePasswordVisibility() {
        if (!editing)
            return
        passwordVisible = !passwordVisible
        password.forceActiveFocus()
    }

    function accept() { submit() }

    function submit() {
        if (connecting)
            return
        if (joinFailed) {
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

    WifiStatusCard {
        objectName: "wifiJoinCard"
        x: 685
        y: 454
        showStatus: !root.editing
        busy: root.connecting
        failed: root.joinFailed
        message: root.connecting ? "Joining" : "Failed to connect"

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
                objectName: "wifiPasswordReveal"
                x: 310
                y: 68
                width: 36
                height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "transparent"
                    border.width: eyeArea.containsMouse ? 1 : 0
                    border.color: Theme.green
                }
                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: root.passwordVisible ? "../assets/icons/eye-closed.svg"
                                                 : "../assets/icons/eye-open.svg"
                    sourceSize: Qt.size(40, 40)
                }
                MouseArea {
                    id: eyeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePasswordVisibility()
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
                    readOnly: !root.editing
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    Keys.forwardTo: root.shell ? [root.shell] : []
                    Keys.onTabPressed: root.focusPassword()
                    Keys.onBacktabPressed: root.focusPassword()
                }
            }
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
