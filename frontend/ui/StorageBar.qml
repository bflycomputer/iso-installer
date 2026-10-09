pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: bar
    property var segments: []
    property string animationMode: "none"
    property bool hatch: false
    width: 150
    height: 40
    color: "white"
    border.color: "black"
    border.width: 1
    clip: true

    function edge(index) {
        let fraction = 0
        for (let i = 0; i < index; ++i)
            fraction += Math.max(0, Number(segments[i].capacityFraction) || 0)
        return Math.round((width - 2) * Math.min(1, fraction))
    }
    Timer {
        interval: Theme.motionFrameMs
        running: bar.visible && bar.animationMode === "erase"
        repeat: true
        onTriggered: bar.hatch = !bar.hatch
    }
    Repeater {
        model: bar.segments.length
        Rectangle {
            required property int index
            x: 1 + bar.edge(index)
            y: 1
            width: Math.max(0, bar.edge(index + 1) - bar.edge(index))
            height: bar.height - 2
            color: bar.segments[index].pond ? Theme.green : bar.segments[index].free ? "white"
                : bar.segments[index].systemColorIndex === 1 ? Theme.systemColor1
                : bar.segments[index].systemColorIndex === 2 ? Theme.systemColor2 : Theme.systemColor3
            border.color: "black"
            border.width: bar.segments[index].pond ? 0 : 1
            clip: true
            Image {
                anchors.fill: parent
                visible: bar.animationMode === "erase" && bar.hatch && bar.segments[parent.index].pond
                source: "../assets/textures/storage-hatch.svg"
                fillMode: Image.Tile
            }
        }
    }
}
