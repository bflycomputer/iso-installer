pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: tree

    property string stage: ""
    property string localeCode: "EN"

    // One-based card choices already made. The value, not the step number, is
    // rendered inside each completed decision node.
    property var decisionChoices: []
    property int currentDecisionChoice: 1
    property int branchDepth: 0

    // Downstream stages only appear once the chosen branch makes them known.
    property bool includeProfile: false

    // Profile fields are ordered TL, TR, BR, BL. profileCompleted is a count;
    // profileActive is a zero-based index, or -1 when no field has focus.
    property int profileCompleted: 0
    property int profileActive: -1

    // The shell sets this while the physical Escape key is down. Mouse press
    // uses the same visual state.
    property bool escapePressed: false
    signal escapeClicked

    readonly property int activeDecision: decisionIndexForStage(stage)
    readonly property int visibleDecisionCount: branchDepth
    readonly property bool profileVisible: includeProfile || stage === "profile"
    readonly property bool compactHeader: visibleDecisionCount === 1
                                               && !profileVisible
    readonly property int baseX: compactHeader ? 32 : 0
    readonly property int contentHeight: {
        if (profileVisible)
            return Math.max(150, profileY + 30)
        return Math.max(150, decisionTop(visibleDecisionCount - 1)
                              + decisionHeight(visibleDecisionCount - 1))
    }

    implicitWidth: 208
    implicitHeight: contentHeight
    width: implicitWidth
    height: implicitHeight

    readonly property int languageX: baseX + 61
    readonly property int wifiX: baseX + 105
    readonly property int decisionOneX: baseX + 148
    readonly property int profileY: {
        if (visibleDecisionCount <= 1)
            return 37
        if (visibleDecisionCount === 2)
            return 96
        return 141
    }

    property bool profileBlinkOn: true

    function decisionIndexForStage(value) {
        const match = /^decision([1-3])$/.exec(value)
        return match ? Number(match[1]) - 1 : -1
    }

    function stateColor(state) {
        if (state === "active")
            return Theme.green
        if (state === "completed")
            return Theme.lavender
        return "#4c5164"
    }

    function languageState() {
        return stage === "language" ? "active" : "completed"
    }

    function wifiState() {
        if (stage === "language")
            return "idle"
        return stage === "wifi" ? "active" : "completed"
    }

    function decisionState(index) {
        if (activeDecision === index)
            return "active"
        if (activeDecision > index || stage === "profile"
                || (decisionChoices && decisionChoices.length > index))
            return "completed"
        return "idle"
    }

    function profileState() {
        return stage === "profile" ? "active" : "idle"
    }

    function decisionChoice(index) {
        if (decisionChoices && decisionChoices.length > index
                && Number(decisionChoices[index]) > 0)
            return Number(decisionChoices[index])
        if (activeDecision === index)
            return Math.max(1, currentDecisionChoice)
        return 1
    }

    function decisionTop(index) {
        if (index <= 0)
            return 5
        if (index === 1)
            return 45
        return 99
    }

    function decisionHeight(index) { return index === 1 ? 34 : 28 }
    function decisionWidth(index) { return index === 1 ? 24 : 28 }
    function decisionX(index) {
        if (index === 0)
            return decisionOneX
        return index === 1 ? 181 : 179
    }

    function languageText() {
        const normalized = String(localeCode || "EN").trim().toUpperCase()
        return normalized.length >= 2 ? normalized.slice(0, 2) : "EN"
    }

    function wifiAsset() {
        const state = wifiState()
        if (state === "active")
            return "../assets/progress/wifi-active.svg"
        if (state === "completed")
            return "../assets/progress/wifi-completed.svg"
        return "../assets/progress/wifi-idle.svg"
    }

    function profileAssetForCount(count) {
        const clamped = Math.max(0, Math.min(4, count))
        if (clamped <= 0)
            return "../assets/progress/profile-active.svg"
        return "../assets/progress/profile-fields-" + clamped + ".svg"
    }

    function activeProfileAsset() {
        if (profileActive < 0)
            return profileAssetForCount(profileCompleted)
        if (profileActive === 0 && profileCompleted === 0)
            return profileBlinkOn
                    ? "../assets/progress/profile-first-field-on.svg"
                    : "../assets/progress/profile-first-field-off.svg"
        const prior = Math.max(profileCompleted, profileActive)
        return profileAssetForCount(profileBlinkOn ? profileActive + 1 : prior)
    }

    Timer {
        interval: Theme.motionFrameMs
        repeat: true
        running: tree.stage === "profile" && tree.profileActive >= 0
        onTriggered: tree.profileBlinkOn = !tree.profileBlinkOn
    }

    onProfileActiveChanged: profileBlinkOn = true

    // Both vector states render on the software backend without a shader.
    Item {
        id: escapeControl
        objectName: "progressTreeEscapeControl"
        x: tree.baseX
        y: 5
        width: 50
        height: 20
        readonly property bool down: tree.escapePressed || escapeMouse.pressed

        Image {
            anchors.fill: parent
            source: "../assets/icons/escape.svg"
            sourceSize: Qt.size(100, 40)
            visible: !escapeControl.down
        }

        Image {
            anchors.fill: parent
            source: "../assets/icons/escape-pressed.svg"
            sourceSize: Qt.size(100, 40)
            visible: escapeControl.down
        }

        MouseArea {
            id: escapeMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tree.escapeClicked()
        }
    }

    Rectangle {
        width: 20
        height: 1
        x: tree.baseX + 47.35
        y: 22.16
        rotation: 122.33
        transformOrigin: Item.Center
        color: Theme.lavender
        antialiasing: true
    }

    Item {
        x: tree.languageX
        y: 19
        width: 30
        height: 25

        Image {
            anchors.fill: parent
            source: "../assets/progress/language-active.svg"
            sourceSize: Qt.size(60, 50)
            visible: tree.languageState() === "active"
        }

        Item {
            anchors.fill: parent
            visible: tree.languageState() !== "active"

            Image {
                anchors.centerIn: parent
                width: 25
                height: 30
                rotation: 90
                source: "../assets/progress/language-completed.svg"
                sourceSize: Qt.size(50, 60)
            }
            Label {
                anchors.fill: parent
                text: tree.languageText()
                color: Theme.lavender
                font: Theme.monoXs
                lh: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Rectangle {
        x: tree.languageX + 33
        y: 31
        width: tree.wifiX + 15 - x
        height: 1
        color: tree.stateColor(tree.wifiState())
    }
    Rectangle {
        x: tree.wifiX + 15
        y: 17
        width: 1
        height: 15
        color: tree.stateColor(tree.wifiState())
    }

    Image {
        x: tree.wifiX
        y: 0
        width: 30
        height: 15
        source: tree.wifiAsset()
        sourceSize: Qt.size(60, 30)
    }

    Rectangle {
        x: tree.wifiX + 15
        y: 31
        width: 1
        height: 11
        color: tree.stateColor(tree.decisionState(0))
    }
    Rectangle {
        x: tree.wifiX + 15
        y: 41
        width: tree.decisionOneX + 14 - x
        height: 1
        color: tree.stateColor(tree.decisionState(0))
    }
    Rectangle {
        x: tree.decisionOneX + 14
        y: 36
        width: 1
        height: 6
        color: tree.stateColor(tree.decisionState(0))
    }

    // First decision -> second decision is the single elbow in the vertical
    // part of the breadcrumb. Later paths are 14px straight segments.
    Rectangle {
        visible: tree.visibleDecisionCount >= 2 || tree.profileVisible
        x: tree.decisionOneX + 31
        y: 19
        width: 193 - x
        height: 1
        color: tree.stateColor(tree.visibleDecisionCount >= 2
                               ? tree.decisionState(1) : tree.profileState())
    }
    Rectangle {
        visible: tree.visibleDecisionCount >= 2 || tree.profileVisible
        x: 192
        y: 19
        width: 1
        height: tree.visibleDecisionCount >= 2 ? 23 : 18
        color: tree.stateColor(tree.visibleDecisionCount >= 2
                               ? tree.decisionState(1) : tree.profileState())
    }

    Repeater {
        model: tree.visibleDecisionCount

        delegate: Item {
            id: decisionNode
            required property int index
            readonly property string nodeState: tree.decisionState(index)
            readonly property color nodeColor: tree.stateColor(nodeState)
            readonly property bool pill: index === 1

            x: tree.decisionX(index)
            y: tree.decisionTop(index)
            width: tree.decisionWidth(index)
            height: tree.decisionHeight(index)

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: decisionNode.nodeColor
                radius: decisionNode.pill ? 12 : 0

                Rectangle {
                    visible: !decisionNode.pill
                    x: 3; y: 3; width: 20; height: 20
                    radius: 10
                    color: "transparent"
                    border.width: 1
                    border.color: decisionNode.nodeColor
                }

                Label {
                    anchors.centerIn: parent
                    width: 8
                    text: String(tree.decisionChoice(decisionNode.index))
                    color: decisionNode.nodeColor
                    font: Qt.font({ family: Theme.monoXs.family, pixelSize: 11,
                                    weight: Font.Medium })
                    lh: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Rectangle {
        visible: tree.visibleDecisionCount >= 3
                         || (tree.profileVisible && tree.visibleDecisionCount >= 2)
        x: 192
        y: 82
        width: 1
        height: 14
        color: tree.stateColor(tree.visibleDecisionCount >= 3
                               ? tree.decisionState(2)
                               : tree.profileState())
    }

    Rectangle {
        visible: tree.profileVisible && tree.visibleDecisionCount >= 3
        x: 192
        y: 130
        width: 1
        height: 14
        color: tree.stateColor(tree.profileState())
    }

    Image {
        visible: tree.profileVisible
        x: 178
        y: tree.profileY
        width: 30
        height: 30
        source: tree.stage === "profile"
                ? tree.activeProfileAsset() : "../assets/progress/profile-idle.svg"
        sourceSize: Qt.size(60, 60)
    }
}
