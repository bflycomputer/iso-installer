import QtQuick
import QtQuick.Window

Rectangle {
    id: shell

    property alias screen: sceneLoader.source

    signal back

    readonly property string routeName: controller.route

    // Chrome flags a screen may override. Written out per flag: QML only
    // tracks a binding dependency on a named property access.
    readonly property bool showProgressTree:
        !sceneLoader.item || sceneLoader.item.showProgressTree === undefined || sceneLoader.item.showProgressTree
    readonly property int rowCount:
        sceneLoader.item && sceneLoader.item.rowCount !== undefined ? sceneLoader.item.rowCount : 0
    // A text field owns typing: digit shortcuts, left/right and space go to it.
    readonly property bool childOwnsFocus:
        sceneLoader.item && sceneLoader.item.childOwnsFocus !== undefined ? sceneLoader.item.childOwnsFocus : false

    property int acceptKey: 0
    property bool escapeHeld: false

    readonly property real designScale: Math.min(width / Theme.canvasW, height / Theme.canvasH)

    // ---- Decision-tree state, derived from the route history and the
    // controller's choices so a changed earlier answer drops its old branch.
    readonly property string decisionStage: stageForRoute(routeName)
    readonly property string localeCode: {
        const name = controller.localeName
        const language = name.split(/[_.-]/)[0]
        return (language.length >= 2 ? language.slice(0, 2) : "en").toUpperCase()
    }
    readonly property int branchDepth: branchDepthForRoute(routeName)
    readonly property var decisionChoices: completedChoices()
    readonly property int currentDecisionChoice: currentChoiceForRoute(routeName)
    readonly property bool includeProfile: ["DestructiveConfirm", "Profile", "Confirm"]
                                               .indexOf(routeName) >= 0
    readonly property int profileCompleted: routeName === "Confirm" ? 4
        : (routeName === "Profile" && sceneLoader.item && sceneLoader.item.completedCount !== undefined
           ? sceneLoader.item.completedCount : 0)
    readonly property int profileActive:
        routeName === "Profile" && sceneLoader.item && sceneLoader.item.activeRow !== undefined
            ? sceneLoader.item.activeRow : -1

    color: Theme.bg
    focus: true

    Component.onCompleted: {
        Theme.blockHover()
        forceActiveFocus()
    }
    Component.onDestruction: Theme.resetInputFeedback()
    onActiveFocusChanged: if (!activeFocus && !childOwnsFocus) releaseHeldKeys()
    onVisibleChanged: {
        if (visible && !childOwnsFocus)
            forceActiveFocus()
        else if (!visible)
            cancelActiveInteraction()
    }
    onRouteNameChanged: {
        // A key held across a route change must not act on the next screen,
        // and the new screen must not hover-select whatever is under a
        // resting pointer.
        releaseHeldKeys()
        Theme.blockHover()
    }

    Connections {
        target: shell.Window.window
        enabled: target !== null
        function onActiveChanged() { if (!target.active) shell.cancelActiveInteraction() }
        // A key held while focus moves outside the shell (a text field
        // hands off, or the host takes focus) would never see its release.
        function onActiveFocusItemChanged() {
            let item = target.activeFocusItem
            while (item && item !== shell)
                item = item.parent
            if (!item)
                shell.releaseHeldKeys()
        }
    }

    // The ESC chip flashes green for at least this long, even on a quick tap.
    Timer {
        id: escapeFlash
        interval: 150
    }

    function releaseHeldKeys() {
        cancelAccept()
        acceptKey = 0
        Theme.navigationDirection = 0

        escapeHeld = false
    }

    function cancelAccept() {
        if (sceneLoader.item && sceneLoader.item.endAccept !== undefined)
            sceneLoader.item.endAccept()
    }

    function cancelActiveInteraction() {
        releaseHeldKeys()
        escapeFlash.stop()
        Theme.resetInputFeedback()
    }

    function navigateBack() {
        if (!sceneLoader.item || sceneLoader.item.dismiss === undefined || !sceneLoader.item.dismiss())
            shell.back()
    }

    function requestPowerOff() {
        controller.powerOffComputer()
    }

    function move(delta) {
        const item = sceneLoader.item
        if (!item)
            return
        if (item.moveSelection !== undefined)
            item.moveSelection(delta)
    }

    function choose(index) {
        const item = sceneLoader.item
        if (!item)
            return
        if (item.chooseIndex !== undefined)
            item.chooseIndex(index)
    }

    function activate() {
        if (sceneLoader.item && sceneLoader.item.accept !== undefined)
            sceneLoader.item.accept()
    }

    function handleKeyPress(event) {
        const item = sceneLoader.item
        switch (event.key) {
        case Qt.Key_Down:
            Theme.navigationDirection = 1
            move(1)
            break
        case Qt.Key_Up:
            Theme.navigationDirection = -1
            move(-1)
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (event.isAutoRepeat || acceptKey !== 0)
                break
            acceptKey = event.key

            if (item && item.beginAccept !== undefined)
                item.beginAccept()
            else
                activate()
            break
        case Qt.Key_Escape:
            if (event.isAutoRepeat)
                break
            escapeHeld = true

            escapeFlash.restart()
            navigateBack()
            break
        default:
            if (childOwnsFocus || !item)
                return
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && rowCount > event.key - Qt.Key_1)
                choose(event.key - Qt.Key_1)
            else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && item.adjust !== undefined)
                item.adjust(event.key === Qt.Key_Left ? -1 : 1)
            else if (event.key === Qt.Key_Space && item.toggleDropdown !== undefined)
                item.toggleDropdown()
            else if (!(item.handleTextInput !== undefined && item.handleTextInput(event.text)))
                return
        }
        event.accepted = true
    }

    function handleKeyRelease(event) {
        if (event.isAutoRepeat)
            return
        switch (event.key) {
        case Qt.Key_Down:
            if (Theme.navigationDirection === 1)
                Theme.navigationDirection = 0
            break
        case Qt.Key_Up:
            if (Theme.navigationDirection === -1)
                Theme.navigationDirection = 0
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (event.key === acceptKey) {
                cancelAccept()
                acceptKey = 0
            }
            break
        case Qt.Key_Escape:
            escapeHeld = false

            break
        default:
            return
        }
        event.accepted = true
    }

    Keys.onPressed: function (event) { shell.handleKeyPress(event) }
    Keys.onReleased: function (event) { shell.handleKeyRelease(event) }

    // ---- Decision tree derivation.
    function visited(route) { return controller.routeTrail.indexOf(route) >= 0 }

    function stageForRoute(route) {
        switch (route) {
        case "WifiList":
        case "WifiPassword": return "wifi"
        case "DriveSelect": return "decision1"
        case "DiskUse": return "decision2"
        case "DestructiveConfirm": return "decision3"
        case "Profile":
        case "Confirm": return "profile"
        default: return "language"
        }
    }

    function chosen(propertyName) {
        return Math.max(1, Number(controller[propertyName]) + 1)
    }

    function branchDepthForRoute(route) {
        if (route === "DestructiveConfirm" || visited("DestructiveConfirm")) return 3
        return visited("DiskUse") && route !== "DriveSelect" ? 2 : 1
    }

    function completedChoices() {
        const stage = decisionStage
        let completed = branchDepth
        if (stage.startsWith("decision"))
            completed = Number(stage.slice(8)) - 1
        else if (stage === "language" || stage === "wifi")
            completed = 0
        const values = []
        if (completed >= 1)
            values.push(chosen("selectedDrive"))
        if (completed >= 2)
            values.push(chosen("selectedInstallOption"))
        if (completed >= 3)
            values.push(1)
        return values
    }

    function currentChoiceForRoute(route) {
        if (route === "DriveSelect")
            return chosen("selectedDrive")
        if (route === "DiskUse")
            return chosen("selectedInstallOption")
        return 1
    }

    Item {
        width: Theme.canvasW
        height: Theme.canvasH
        anchors.centerIn: parent
        scale: shell.designScale

        Loader {
            id: sceneLoader
            anchors.fill: parent
            onLoaded: {
                Theme.blockHover()
                if (item.shell !== undefined)
                    item.shell = shell
                if (!shell.childOwnsFocus)
                    shell.forceActiveFocus()
            }
        }

        PondLogo {
            x: 10
            y: 10
        }

        ProgressTree {
            stage: shell.decisionStage
            localeCode: shell.localeCode
            decisionChoices: shell.decisionChoices
            branchDepth: shell.branchDepth
            currentDecisionChoice: shell.currentDecisionChoice
            includeProfile: shell.includeProfile
            profileCompleted: shell.profileCompleted
            profileActive: shell.profileActive
            escapePressed: shell.escapeHeld || escapeFlash.running
            onEscapeClicked: shell.navigateBack()
            visible: shell.showProgressTree

            transformOrigin: Item.TopRight
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 10
        }

        Label {
            text: "Early Preview"
            color: Theme.chromeMuted
            font: Theme.xl
            lh: Theme.lhXl
            transformOrigin: Item.BottomLeft
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
        }

        Rectangle {
            width: 116
            height: 30
            color: "transparent"
            border.width: 1
            border.color: Theme.isoBadge
            opacity: 0.5
            radius: 4
            transformOrigin: Item.BottomLeft
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50

            Label {
                anchors.centerIn: parent
                text: "ISO INSTALLER"
                color: Theme.isoBadge
                font: Theme.monoXs
                lh: 12
            }
        }

        Label {
            text: "Some features may not work as expected. Please report any issues or bugs."
            color: Theme.chromeMuted
            font: Theme.xs
            lh: Theme.lhXs
            wrapMode: Text.WordWrap
            width: 142
            transformOrigin: Item.BottomRight
            anchors.right: parent.right
            anchors.rightMargin: 94
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 13
        }

        Item {
            width: 80
            height: 80
            transformOrigin: Item.BottomRight
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Image {
                anchors.fill: parent
                source: "../assets/icons/power.svg"
                sourceSize: Qt.size(160, 160)
                visible: !powerArea.containsMouse
            }

            Image {
                anchors.fill: parent
                source: "../assets/icons/power-hover.svg"
                sourceSize: Qt.size(160, 160)
                visible: powerArea.containsMouse
            }

            MouseArea {
                id: powerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: shell.requestPowerOff()
            }
        }
    }
}
