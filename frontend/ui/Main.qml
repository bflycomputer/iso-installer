import QtQuick
import QtQuick.Window
import "."

Window {
    id: window
    visible: true
    visibility: Window.FullScreen
    color: "#1a1409"
    title: "Pond Installer"
    onClosing: function(close) { close.accepted = !pond.busy }

    readonly property bool bare: (pond.route === "Installing" || pond.route === "Finished")

    Shell {
        anchors.fill: parent
        visible: !window.bare
        focus: !window.bare
        screen: window.bare ? "" : "screens/" + pond.route + ".qml"
        onBack: pond.back()
    }

    Loader {
        anchors.fill: parent
        active: window.bare
        source: active ? "screens/" + pond.route + ".qml" : ""
        onLoaded: {
            item.forceActiveFocus()
        }
    }
}
