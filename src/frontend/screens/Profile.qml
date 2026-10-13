pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    property Item shell: null
    readonly property bool childOwnsFocus: activeRow < fields.count
    readonly property int rowCount: rows.length + 1
    property int activeRow: 0

    readonly property var rows: [
        { label: "Username", placeholder: "Enter username", key: "username", error: "usernameError" },
        { label: "Password", placeholder: "Password", key: "password", error: "passwordError" },
        { label: "Confirm password", placeholder: "Confirm password", key: "passwordConfirmation", error: "confirmationError" },
        { label: "Computer name", placeholder: "Enter computer name", key: "hostname", error: "hostnameError" }
    ]
    readonly property int completedCount: rows.filter((row, index) => fieldCompleted(index)).length
    readonly property bool canSubmit: rows.every(row => controller[row.key] !== "")
        && ["usernameError", "passwordError", "hostnameError"].every(error => controller[error] === "")

    Keys.onTabPressed: function(event) { moveSelection(event.modifiers & Qt.ShiftModifier ? -1 : 1) }
    Keys.onBacktabPressed: moveSelection(-1)

    function activateRow(index) {
        if (index < 0 || index >= rowCount)
            return
        activeRow = index
        if (index === fields.count) {
            forceActiveFocus()
            return
        }
        const row = fields.itemAt(index)
        if (row)
            row.focusInput()
    }

    function moveSelection(delta) { activateRow((activeRow + delta + rowCount) % rowCount) }
    function chooseIndex(index) { activateRow(index) }

    function accept() {
        if (activeRow < fields.count)
            activateRow(activeRow + 1)
        else
            submit()
    }

    function submit() {
        // The controller validates and may replace this screen synchronously,
        // so the field to return to is chosen before advancing.
        const invalid = firstInvalidRow()
        controller.advance()
        if (invalid >= 0)
            activateRow(invalid)
    }

    function firstInvalidRow() {
        return rows.findIndex(row => controller[row.error] !== "")
    }
    function liveError(row) {
        return controller[row.key] !== "" && row.error !== "confirmationError" ? controller[row.error] : ""
    }
    function fieldCompleted(index) {
        const row = rows[index]
        return controller[row.key] !== "" && (index === 1 || controller[row.error] === "")
            && (index !== 2 || controller.passwordError === "")
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.activateRow(fields.count)
    }

    Title {
        y: 289
        width: 210
        x: 864 - width / 2
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "Set up your profile"
    }

    Repeater {
        id: fields
        model: root.rows.length

        Field {
            id: row
            required property int index
            readonly property bool complete: root.fieldCompleted(index)
            readonly property bool isPassword: index === 1 || index === 2
            property bool passwordVisible: false
            function focusInput() { input.forceActiveFocus() }
            function togglePasswordVisibility() { passwordVisible = !passwordVisible }

            x: 571
            y: 405 + index * 80
            labelWidth: 201
            compactLabel: index >= 2
            label: root.rows[index].label
            active: index === root.activeRow
            labelColor: active ? Theme.bg : Theme.textDim
            onClicked: root.activateRow(index)
            Component.onCompleted: if (active) Qt.callLater(focusInput)

            Label {
                visible: input.text.length === 0
                x: 15
                y: Theme.capYBase(19)
                text: root.rows[row.index].placeholder
                color: row.active ? Theme.textWhite : Theme.textDim
                opacity: row.active ? 0.3 : 0.5
                font: Theme.base
                lh: Theme.lhBase
            }

            PasswordInput {
                id: input
                objectName: "profileInput" + row.index
                x: 15
                width: row.isPassword ? reveal.x - x - 8 : 329
                height: 48
                text: controller[root.rows[row.index].key]
                masked: row.isPassword && !row.passwordVisible
                inputMethodHints: Qt.ImhNoPredictiveText
                                  | (row.isPassword ? Qt.ImhSensitiveData : 0)
                Keys.forwardTo: root.shell ? [root.shell] : []
                onTextEdited: controller[root.rows[row.index].key] = text
                onActiveFocusChanged: if (activeFocus) root.activeRow = row.index
            }

            Rectangle {
                id: reveal
                objectName: "profilePasswordReveal" + row.index
                visible: row.isPassword
                x: 319
                y: 8
                width: 32
                height: 32
                radius: 4
                color: revealPointer.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                Accessible.role: Accessible.Button
                Accessible.name: (row.passwordVisible ? "Hide " : "Show ") + root.rows[row.index].label.toLowerCase()
                Accessible.checkable: true
                Accessible.checked: row.passwordVisible
                Accessible.onPressAction: row.togglePasswordVisibility()

                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: row.passwordVisible ? "../assets/icons/eye-open.svg"
                                                : "../assets/icons/eye-closed.svg"
                    sourceSize: Qt.size(40, 40)
                }

                MouseArea {
                    id: revealPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.togglePasswordVisibility()
                }
            }
        }
    }

    ErrorText {
        objectName: "profileError"
        y: 727
        text: (root.activeRow < root.rows.length ? root.liveError(root.rows[root.activeRow]) : "")
              || root.rows.map(root.liveError).find(error => error) || controller.errorMessage
    }

    NavBar {
        y: 753
        anchors.horizontalCenter: parent.horizontalCenter
        label: "Confirm"
        primaryEnabled: root.canSubmit
    }
}
