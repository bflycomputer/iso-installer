import QtQuick
import QtQuick.Window
import "."

Window {
    id: window
    visible: true
    visibility: Window.FullScreen
    color: "#1a1409"
    title: "Pond Installer"

    readonly property bool standaloneScreen: (controller.route === "Installing" || controller.route === "Finished")

    Shell {
        anchors.fill: parent
        visible: !window.standaloneScreen
        focus: !window.standaloneScreen
        screen: window.standaloneScreen ? "" : "screens/" + controller.route + ".qml"
        onBack: controller.back()
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
