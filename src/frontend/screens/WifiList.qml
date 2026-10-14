pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    readonly property int rowCount: networks.count
    readonly property int activeRow: controller.selectedNetwork >= 0
        ? controller.selectedNetwork : controller.selectedSsid === "" && rowCount > 0 ? 0 : -1
    readonly property bool scanFailed: controller.wifi.errorMessage !== ""
        && !controller.wifi.scanning && !controller.wifi.networkConnected
    readonly property bool busy: rowCount === 0 && controller.wifi.scanning
    readonly property bool showStatus: scanFailed || rowCount === 0

    function moveSelection(delta) {
        if (rowCount > 0 && !showStatus)
            chooseIndex(activeRow < 0 ? (delta > 0 ? 0 : rowCount - 1)
                                     : (activeRow + delta + rowCount) % rowCount)
    }
    function chooseIndex(index) {
        if (!showStatus && index >= 0 && index < rowCount)
            controller.selectedNetwork = index
    }
    function accept() {
        if (!navigation.primaryEnabled)
            return
        if (scanFailed) {
            controller.wifi.requestScan()
            return
        }
        if (activeRow >= 0)
            controller.selectedNetwork = activeRow
        controller.advance()
    }

    Title {
        y: root.showStatus ? 376 : 310
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Connect to Wifi"
    }

    Rectangle {
        visible: !root.showStatus
        width: 376
        height: Math.max(60, Math.min(280, networks.contentHeight + 16))
        anchors.horizontalCenter: parent.horizontalCenter
        y: 536 - height / 2
        radius: 16
        color: Theme.surface
        clip: true

        ListView {
            id: networks
            objectName: "wifiChoices"
            x: 8
            y: 8
            width: 360
            height: parent.height - 16
            spacing: 0
            model: controller.wifi
            currentIndex: root.activeRow
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            delegate: Rectangle {
                id: netRow
                required property int index
                required property string ssid
                required property int strength
                required property bool secured

                width: 360
                height: 44
                radius: 12
                color: index === root.activeRow ? Theme.lavender : "transparent"

                WifiSignal {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    strength: netRow.strength
                    active: netRow.index === root.activeRow
                }

                Label {
                    x: 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: 275
                    elide: Text.ElideRight
                    text: netRow.ssid
                    color: netRow.index === root.activeRow ? Theme.onWifiActive : Theme.textWhite
                    font: Theme.sm
                    lh: Theme.lhSm
                }

                Image {
                    visible: netRow.secured
                    x: 332
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    source: netRow.index === root.activeRow ? "../assets/icons/lock-active.svg"
                                                             : "../assets/icons/lock-idle.svg"
                    sourceSize: Qt.size(32, 32)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.chooseIndex(netRow.index)
                        root.accept()
                    }
                }
            }
        }
    }

    WifiStatusCard {
        objectName: "wifiListStatus"
        x: 685
        y: 454
        visible: root.showStatus
        busy: root.busy
        message: root.busy ? "Scanning"
               : root.scanFailed ? "Failed to scan"
               : controller.wifi.available ? "No Wi-Fi networks found" : "No Wi-Fi adapter found"
    }

    NavBar {
        id: navigation
        objectName: "wifiListNavigation"
        visible: !root.busy
        y: root.showStatus ? 661 : 716
        anchors.horizontalCenter: parent.horizontalCenter
        label: root.scanFailed ? "Try again" : "Next"
        spacing: 12
        primaryEnabled: !root.busy && (root.scanFailed ? controller.wifi.available
            : root.activeRow >= 0 || controller.wifi.networkConnected)
    }
}
