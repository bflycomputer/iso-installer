import QtQuick

Text {
    property int lh: 0

    readonly property bool wraps: lh > 0 && wrapMode !== Text.NoWrap
    lineHeight: wraps ? lh : 1
    lineHeightMode: wraps ? Text.FixedHeight : Text.ProportionalHeight
    height: lh > 0 ? lh * Math.max(1, lineCount) : implicitHeight
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering
}
