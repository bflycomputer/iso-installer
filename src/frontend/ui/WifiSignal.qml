import QtQuick

Image {
    id: signal

    property int strength: 0
    property bool active: false

    readonly property string level: strength >= 67 ? "full" : strength >= 34 ? "2" : "1"

    width: 20
    height: 20

    source: Qt.resolvedUrl("../assets/icons/wifi-signal-" + signal.level
                           + (signal.active ? "-active.svg" : "-idle.svg"))
    sourceSize: Qt.size(40, 40)
}
