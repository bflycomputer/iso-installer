import QtQuick

Label {
    text: controller.errorMessage
    visible: text !== ""
    anchors.horizontalCenter: parent.horizontalCenter
    color: Theme.textError
    font: Theme.sm
    lh: Theme.lhSm
}
