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
    property bool validationRequested: false

    readonly property var rows: [
        { label: "Username", placeholder: "Enter username", key: "username", error: "usernameError" },
        { label: "Password", placeholder: "Password", key: "password", error: "passwordError" },
        { label: "Confirm password", placeholder: "Confirm password", key: "passwordConfirmation", error: "confirmationError" },
        { label: "Computer name", placeholder: "Enter computer name", key: "hostname", error: "hostnameError" }
    ]
    readonly property int completedCount: rows.filter((row, index) => fieldCompleted(index)).length
    readonly property bool canSubmit: rows.every(row => controller[row.error] === "")

    Keys.onTabPressed: moveSelection(1)
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
        validationRequested = true

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
            function focusInput() { input.forceActiveFocus() }

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
                width: 329
                height: 48
                text: controller[root.rows[row.index].key]
                masked: row.index === 1 || row.index === 2
                inputMethodHints: Qt.ImhNoPredictiveText
                                  | (row.index === 1 || row.index === 2 ? Qt.ImhSensitiveData : 0)
                Keys.forwardTo: root.shell ? [root.shell] : []
                onTextEdited: controller[root.rows[row.index].key] = text
                onActiveFocusChanged: if (activeFocus && root.activeRow !== row.index) root.activeRow = row.index
            }
        }
    }

    ErrorText {
        visible: root.validationRequested && text !== ""
        y: 727
        text: (root.activeRow < root.rows.length ? controller[root.rows[root.activeRow].error] : "")
              || controller.errorMessage
    }

    NavBar {
        y: 753
        anchors.horizontalCenter: parent.horizontalCenter
        label: "Confirm"
        primaryEnabled: root.canSubmit
    }
}
