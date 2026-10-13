import QtQuick
import QtQuick.Window

Window {
    id: window
    visible: true
    visibility: Window.FullScreen
    color: Theme.bg
    title: "Pond Installer"

    readonly property bool standaloneScreen: (controller.route === "Installing" || controller.route === "Finished")

    Shell {
        anchors.fill: parent
        visible: !window.standaloneScreen
        focus: !window.standaloneScreen
        screen: window.standaloneScreen ? "" : "screens/" + controller.route + ".qml"
    }

    Loader {
        anchors.fill: parent
        active: window.standaloneScreen
        source: active ? "screens/" + controller.route + ".qml" : ""
        onLoaded: {
            item.forceActiveFocus()
        }
    }
}
