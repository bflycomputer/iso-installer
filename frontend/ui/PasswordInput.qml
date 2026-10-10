import QtQuick

TextInput {
    id: input

    property bool masked: true
    property bool whiteMask: true
    property color textColor: Theme.textWhite

    // The native password layout reserves one 14 px cell for each symbol,
    // so the caret, selection, pointer editing and scrolling stay aligned.
    font.family: Theme.base.family
    font.pixelSize: Theme.base.pixelSize
    font.weight: Theme.base.weight
    font.letterSpacing: masked ? 14 - maskMetrics.advanceWidth : 0
    echoMode: masked ? TextInput.Password : TextInput.Normal
    passwordCharacter: "•"
    passwordMaskDelay: 0
    color: masked ? "transparent" : textColor
    selectionColor: Theme.lavender
    selectedTextColor: masked ? "transparent" : Theme.onAccent
    selectByMouse: true
    verticalAlignment: TextInput.AlignVCenter
    clip: true

    TextMetrics {
        id: maskMetrics
        font: Theme.base
        text: input.passwordCharacter
    }

    cursorDelegate: Rectangle {
        objectName: input.objectName + "Cursor"
        width: 1
        height: input.cursorRectangle.height
        color: input.textColor
        visible: input.activeFocus && input.cursorVisible && !input.readOnly
    }

    Row {
        visible: input.masked
        x: input.cursorRectangle.x - input.cursorPosition * 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: input.length

            Image {
                required property int index
                width: 12
                height: 12
                source: "../assets/icons/password-mask-"
                        + ["plant", "lily-pad", "hexagon", "plant", "leaf", "lily-pad", "hexagon", "plant"][index % 8]
                        + (input.whiteMask ? "-white.svg" : ".svg")
                sourceSize: Qt.size(24, 24)
            }
        }
    }
}
