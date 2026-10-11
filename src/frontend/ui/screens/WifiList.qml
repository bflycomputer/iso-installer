pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    readonly property int rowCount: networks.count
    readonly property int activeRow: controller.selectedNetwork >= 0 && controller.selectedNetwork < rowCount
        ? controller.selectedNetwork : 0

    function moveSelection(delta) {
        if (rowCount > 0)
            chooseIndex((activeRow + delta + rowCount) % rowCount)
    }
    function chooseIndex(index) {
        if (index >= 0 && index < rowCount)
            controller.selectedNetwork = index
    }
    function accept() {
        controller.selectedNetwork = rowCount > 0 ? activeRow : -1
        controller.advance()
    }

    Title {
        y: 310
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Connect to Wifi"
    }

    Rectangle {
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
                required property bool active

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
                    text: netRow.ssid + (netRow.active ? "  • Connected" : "")
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
                    source: netRow.index === root.activeRow ? "../../assets/icons/lock-active.svg"
                                                             : "../../assets/icons/lock-idle.svg"
                    sourceSize: Qt.size(32, 32)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chooseIndex(netRow.index)
                    onDoubleClicked: {
                        root.chooseIndex(netRow.index)
                        root.accept()
                    }
                }
            }

            Label {
                visible: networks.count === 0
                anchors.centerIn: parent
                width: 340
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: controller.wifi.scanning ? "Looking for networks…"
                      : controller.wifi.networkConnected ? "Connected with a cable"
                      : controller.wifi.available ? "No Wi-Fi networks found"
                                                       : "No Wi-Fi adapter found"
                color: Theme.textWhite
                opacity: 0.7
                font: Theme.base
                lh: Theme.lhBase
            }
        }
    }

    ErrorText {
        visible: (controller.errorMessage !== ""
                                     || controller.wifi.errorMessage !== "")
        y: 690
        text: controller.errorMessage !== "" ? controller.errorMessage : controller.wifi.errorMessage
    }

    NavBar {
        y: 716
        anchors.horizontalCenter: parent.horizontalCenter
        label: "Next"
        spacing: 12
        primaryEnabled: !controller.wifi.connecting && (root.rowCount > 0 || controller.wifi.networkConnected)
    }

}
