import QtQuick

FText {
    text: pond.errorMessage
    visible: text !== ""
    anchors.horizontalCenter: parent.horizontalCenter
    color: Theme.textError
    font: Theme.sm
    lh: Theme.lhSm
}
