pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Item {
    id: root

    Rectangle {
        id: shape
        anchors.fill: parent
        radius: 8
        color: "black"
        visible: false
    }

    Repeater {
        model: [
            { offset: 97, blur: 67, alpha: 0.04 },
            { offset: 47, blur: 55, alpha: 0.06 },
            { offset: 12, blur: 49, alpha: 0.10 },
            { offset: 11, blur: 46, alpha: 0.13 },
            { offset: 9, blur: 20, alpha: 0.15 }
        ]

        MultiEffect {
            required property var modelData
            anchors.fill: parent
            source: shape
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: modelData.alpha
            shadowVerticalOffset: modelData.offset
            blurMax: 64
            shadowBlur: modelData.blur / 67
        }
    }
}
