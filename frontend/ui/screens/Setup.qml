pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    readonly property int rowCount: 4
    readonly property int continueRow: 3
    property int activeRow: 0
    property bool dropdownOpen: false
    property int highlightedChoice: -1
    property string typeAhead: ""

    readonly property var labels: ["Language", "Keyboard", "Region"]

    // The controller hands the long lists over as JSON: indexing a Python-backed
    // list from QML re-converts the whole list on every access, which made
    // type-ahead over 600 keyboard layouts take seconds per keystroke.
    readonly property var languageChoices: JSON.parse(controller.languageChoices)
    readonly property var keyboardChoices: JSON.parse(controller.keyboardChoices)
    readonly property var regionChoices: JSON.parse(controller.regionChoices)

    function choices(row) {
        return row === 0 ? languageChoices : row === 1 ? keyboardChoices : regionChoices
    }

    function currentValue(row) {
        return row === 0 ? controller.languageLabel
             : row === 1 ? controller.keyboardLabel : controller.regionLabel
    }

    function openDropdown(row) {
        activeRow = row
        if (choices(row).length === 0)
            return
        highlightedChoice = Math.max(0, controller.setupChoiceIndex(row))
        typeAhead = ""
        dropdownOpen = true
        Qt.callLater(function() { dropdown.positionAt(highlightedChoice) })
    }

    function closeDropdown() {
        dropdownOpen = false
        typeAhead = ""
        typeAheadReset.stop()
    }

    function toggleDropdown() {
        if (dropdownOpen)
            closeDropdown()
        else if (activeRow < continueRow)
            openDropdown(activeRow)
    }

    // Committing a choice moves to the next field; committing Region lands
    // on Continue.
    function selectChoice(index) {
        if (index < 0 || index >= choices(activeRow).length)
            return
        controller.selectSetupChoice(activeRow, index)
        closeDropdown()
        activeRow = activeRow + 1
    }

    function moveSelection(delta) {
        if (dropdownOpen) {
            const n = choices(activeRow).length
            if (n === 0)
                return
            highlightedChoice = (highlightedChoice + delta + n) % n
            dropdown.positionAt(highlightedChoice)
            return
        }
        activeRow = (activeRow + delta + rowCount) % rowCount
    }

    function chooseIndex(index) {
        if (dropdownOpen)
            selectChoice(index)
        else if (index < continueRow)
            openDropdown(index)
        else if (index === continueRow)
            activeRow = index
    }

    // Enter opens the active field, commits the highlighted choice, or
    // continues from the pill.
    function accept() {
        if (dropdownOpen)
            selectChoice(highlightedChoice)
        else if (activeRow === continueRow)
            submit()
        else
            openDropdown(activeRow)
    }

    function submit() {
        closeDropdown()
        controller.advance()
    }

    function dismiss() {
        if (!dropdownOpen)
            return false
        closeDropdown()
        return true
    }

    // Left/right step the active field's value without opening it.
    function adjust(delta) {
        if (dropdownOpen) {
            moveSelection(delta)
            return
        }
        const values = choices(activeRow)
        if (activeRow >= continueRow || values.length === 0)
            return
        const index = (Math.max(0, controller.setupChoiceIndex(activeRow)) + delta + values.length) % values.length
        controller.selectSetupChoice(activeRow, index)
    }

    // Type-ahead inside an open dropdown. Exact matches win, then prefixes,
    // then substrings; for keyboards, variants of the current layout are
    // searched first so "dvorak" from English (US) stays English (US).
    function handleTextInput(text) {
        if (!dropdownOpen || !text || text.length !== 1)
            return false
        typeAhead += text.toLocaleLowerCase()
        typeAheadReset.restart()

        const values = choices(activeRow)
        const query = typeAhead.replace(/[^a-z0-9]+/g, "")
        const currentLayout = activeRow === 1 ? String(controller.keyboardLayout || "") : ""
        function rank(item) {
            const fields = [item.label, item.detail, item.value, item.variant]
            let combined = ""
            for (let f = 0; f < fields.length; ++f) {
                const field = String(fields[f] || "").toLocaleLowerCase().replace(/[^a-z0-9]+/g, "")
                combined += field
                if (field === query)
                    return 0
                if (field.startsWith(query))
                    return 1
            }
            return combined.indexOf(query) >= 0 ? 2 : -1
        }
        let best = -1
        let bestRank = Infinity
        for (let i = 0; i < values.length; ++i) {
            const match = rank(values[i])
            if (match < 0)
                continue
            const priority = match * 2 + (activeRow === 1 && String(values[i].value || "") !== currentLayout ? 1 : 0)
            if (priority < bestRank) {
                best = i
                bestRank = priority
            }
        }
        if (best >= 0) {
            highlightedChoice = best
            dropdown.positionAt(best)
        }
        return true
    }

    Timer {
        id: typeAheadReset
        interval: 900
        onTriggered: root.typeAhead = ""
    }

    Title {
        x: 736
        y: 310
        text: "Language & region"
    }

    Repeater {
        model: 3

        Field {
            id: row
            required property int index
            x: 598
            y: 396 + index * 80
            label: root.labels[index]
            active: index === root.activeRow
            onClicked: root.openDropdown(index)

            Label {
                x: 15
                y: Theme.capYBase(19)
                width: 300
                elide: Text.ElideRight
                text: root.currentValue(row.index)
                color: Theme.textWhite
                font: Theme.base
                lh: Theme.lhBase
            }
            Image {
                x: 323
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                source: "../../assets/icons/chevron-vertical.svg"
                sourceSize: Qt.size(48, 48)
            }
        }
    }

    // While a menu is open, a click on another field switches to it and any
    // other click outside the menu dismisses it without changing the value.
    MouseArea {
        anchors.fill: parent
        z: 290
        visible: root.dropdownOpen
        onClicked: function(mouse) {
            const candidate = Math.floor((mouse.y - 396) / 80)
            if (mouse.x >= 598 && mouse.x < 1129 && candidate >= 0 && candidate < 3
                    && mouse.y < 396 + candidate * 80 + 68)
                root.openDropdown(candidate)
            else
                root.closeDropdown()
        }
    }

    ChoiceDropdown {
        id: dropdown
        x: 760
        // The authored dropdown overlays the inner value box of its field.
        y: 406 + Math.min(root.activeRow, 2) * 80
        z: 300
        visible: root.dropdownOpen
        choices: root.choices(root.activeRow)
        highlightedIndex: root.highlightedChoice
        onHighlighted: function(index) { root.highlightedChoice = index }
        onChosen: function(index) { root.selectChoice(index) }
    }

    ErrorText {
        y: 637
    }

    NavBar {
        y: 674
        anchors.horizontalCenter: parent.horizontalCenter
        label: "Continue"
        focused: root.activeRow === root.continueRow
    }

    Image {
        x: 252
        y: 758
        width: 1226
        height: 1532
        source: "../../assets/illustrations/moon.png"
        sourceSize: Qt.size(1226, 1532)
    }
}
