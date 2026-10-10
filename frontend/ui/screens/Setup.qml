pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent

    property Item shell: null
    readonly property bool childOwnsFocus: dropdownOpen && activeRow === 2
    readonly property int rowCount: 4
    readonly property int continueRow: 3
    property int activeRow: 0
    property bool dropdownOpen: false
    property int highlightedChoice: -1
    property string typeAhead: ""

    readonly property var labels: ["Language", "Keyboard", "Timezone"]

    // The controller hands the long lists over as JSON: indexing a Python-backed
    // list from QML re-converts the whole list on every access, which made
    // type-ahead over 600 keyboard layouts take seconds per keystroke.
    readonly property var languageChoices: JSON.parse(controller.languageChoices)
    readonly property var keyboardChoices: JSON.parse(controller.keyboardChoices)
    readonly property var timezoneChoices: JSON.parse(controller.timezoneChoices)
    readonly property var dropdownChoices: {
        if (activeRow !== 2)
            return choices(activeRow)
        const current = controller.timezone
        const indexed = timezoneChoices.map((item, index) => Object.assign({}, item, { choiceIndex: index }))
        const ordered = indexed.filter(item => item.value === current)
            .concat(indexed.filter(item => item.value !== current))
        const query = dropdown.query.trim().toLocaleLowerCase().replace(/_/g, " ")
        const groups = new Set()
        return ordered.filter(item => {
            if (query)
                return [item.label, item.value, item.detail, item.search].join(" ")
                    .toLocaleLowerCase().replace(/_/g, " ").includes(query)
            const group = item.group || item.value
            if (groups.has(group))
                return false
            groups.add(group)
            return true
        })
    }

    function choices(row) {
        return row === 0 ? languageChoices : row === 1 ? keyboardChoices : timezoneChoices
    }

    function currentValue(row) {
        return row === 0 ? controller.languageLabel
             : row === 1 ? controller.keyboardLabel : controller.timezoneLabel
    }

    function openDropdown(row) {
        activeRow = row
        if (choices(row).length === 0)
            return
        dropdown.query = ""
        highlightedChoice = row === 2 ? 0 : Math.max(0, controller.setupChoiceIndex(row))
        typeAhead = ""
        dropdownOpen = true
        Qt.callLater(function() {
            dropdown.positionAt(highlightedChoice)
            if (root.childOwnsFocus)
                dropdown.focusSearch()
            else if (root.shell)
                root.shell.forceActiveFocus()
        })
    }

    function closeDropdown() {
        dropdownOpen = false
        dropdown.query = ""
        typeAhead = ""
        typeAheadReset.stop()
        if (shell)
            shell.forceActiveFocus()
    }

    function toggleDropdown() {
        if (dropdownOpen)
            closeDropdown()
        else if (activeRow < continueRow)
            openDropdown(activeRow)
    }

    function selectChoice(index) {
        if (index < 0 || index >= dropdownChoices.length)
            return
        const sourceIndex = activeRow === 2 ? dropdownChoices[index].choiceIndex : index
        controller.selectSetupChoice(activeRow, sourceIndex)
        closeDropdown()
        activeRow = activeRow + 1
    }

    function moveSelection(delta) {
        if (dropdownOpen) {
            const n = dropdownChoices.length
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
        if (activeRow === 2 && dropdown.query.length > 0) {
            dropdown.query = ""
            return true
        }
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

    function handleTextInput(text) {
        if (!dropdownOpen || activeRow === 2 || !text || text.length !== 1)
            return false
        typeAhead += text.toLocaleLowerCase()
        typeAheadReset.restart()

        const values = choices(activeRow)
        const ignored = activeRow === 2 ? /[^a-z0-9+-]+/g : /[^a-z0-9]+/g
        const query = typeAhead.replace(ignored, "")
        function rank(item) {
            const fields = [item.label, item.detail, item.value, item.search]
            let combined = ""
            for (let f = 0; f < fields.length; ++f) {
                const field = String(fields[f] || "").toLocaleLowerCase().replace(ignored, "")
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
            if (match < bestRank) {
                best = i
                bestRank = match
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
        text: "Language & timezone"
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
        searchable: root.activeRow === 2
        shell: root.shell
        choices: root.dropdownChoices
        highlightedIndex: root.highlightedChoice
        onQueryChanged: {
            if (root.activeRow === 2) {
                root.highlightedChoice = root.dropdownChoices.length > 0 ? 0 : -1
                Qt.callLater(function() { dropdown.positionAt(root.highlightedChoice) })
            }
        }
        onHighlighted: function(index) { root.highlightedChoice = index }
        onChosen: function(index) { root.selectChoice(index) }
        onTabbed: function(direction) {
            root.closeDropdown()
            root.moveSelection(direction)
        }
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
