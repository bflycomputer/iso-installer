pragma Singleton
import QtQuick

QtObject {
    id: theme

    // Design canvas. All screen content is authored in these coordinates.
    readonly property int canvasW: 1728
    readonly property int canvasH: 1117

    readonly property color bg: "#1a1409"
    readonly property color lavender: "#cba6f7"
    readonly property color green: "#cbe25b"
    readonly property color surface: "#33273d"
    readonly property color fieldOnLavender: "#3d2641"
    readonly property color fieldOnSurface: "#59415e"
    readonly property color searchSurface: "#2c1a2f"
    readonly property color searchDivider: "#563e61"
    readonly property color onAccent: "#23270d"
    readonly property color textWhite: "#ffffff"
    readonly property color textCream: "#f8fff1"
    readonly property color chromeMuted: "#656a84"
    readonly property color isoBadge: "#afc0ff"
    readonly property color onWifiActive: "#262326"
    readonly property color onCard: "#151515"
    readonly property color barUsed: "#fa6d80"
    // Inline error text, used by every screen that surfaces a message.
    readonly property color textError: "#ff9faf"
    readonly property color statusError: "#fa6d80"
    readonly property color numText: "#f8f9f9"
    readonly property color cardInset: "#463a50"
    readonly property color textDim: "#ebebeb"
    readonly property color systemPond: green
    readonly property color systemColor1: "#6e88a6"
    readonly property color systemColor2: "#da8446"
    readonly property color systemColor3: "#fa6d80"
    readonly property color navigationFeedback: "#bc9ae5"
    readonly property int motionFrameMs: 750

    // Shared input feedback keeps hardware-key presses and pointer presses on
    // the same component states. Shell owns these values and clears them when
    // its window or route changes.
    property int navigationDirection: 0 // 1 = down/left, -1 = up/right
    // Hover selection must come from the pointer moving. A list scrolling,
    // opening or appearing under a resting pointer also raises hover events,
    // which once let the row under the cursor steal a type-ahead selection
    // (the "Dvorak, Macintosh" defect). Programmatic movement blocks hover
    // selection for a moment; a real move after that selects as usual.
    property real hoverBlockedUntil: 0
    function blockHover() { hoverBlockedUntil = Date.now() + 200 }
    function hoverAllowed() { return Date.now() >= hoverBlockedUntil }

    function resetInputFeedback() {
        navigationDirection = 0
    }

    readonly property string displayFont: "Pond Gramercy"
    readonly property string displayBookFont: "Pond Gramercy Book"
    property FontLoader plexMonoMedium: FontLoader {
        source: Qt.resolvedUrl("../assets/fonts/ibm-plex-mono-medium.ttf")
    }
    property FontLoader onest: FontLoader {
        source: Qt.resolvedUrl("../assets/fonts/onest.ttf")
    }
    readonly property font monoXs: Qt.font({
        family: "IBM Plex Mono",
        pixelSize: 12,
        weight: Font.Medium
    })

    readonly property font xl: Qt.font({
        family: displayFont,
        pixelSize: 32,
        letterSpacing: -0.64
    })
    readonly property font xlItalic: Qt.font({
        family: displayFont,
        pixelSize: 32,
        letterSpacing: -0.64,
        italic: true
    })
    readonly property font lg: Qt.font({
        family: displayBookFont,
        pixelSize: 20
    })
    readonly property font displaySm: Qt.font({
        family: displayBookFont,
        pixelSize: 16
    })
    readonly property font base: Qt.font({
        family: onest.font.family,
        pixelSize: 15,
        weight: Font.Medium
    })
    readonly property font sm: Qt.font({
        family: onest.font.family,
        pixelSize: 13,
        weight: Font.Medium
    })
    readonly property font baseR: Qt.font({
        family: onest.font.family,
        pixelSize: 15
    })
    readonly property font smR: Qt.font({
        family: onest.font.family,
        pixelSize: 13
    })
    readonly property font xs: Qt.font({
        family: onest.font.family,
        pixelSize: 11,
        weight: Font.Medium,
        letterSpacing: 0.11
    })

    readonly property int lhXl: 36
    readonly property int lhLg: 28
    readonly property int lhDisplaySm: 20
    readonly property int lhBase: 21
    readonly property int lhSm: 19
    readonly property int lhXs: 16

    property FontMetrics fmBase: FontMetrics { font: theme.base }
    property FontMetrics fmSm: FontMetrics { font: theme.sm }
    property FontMetrics fmXs: FontMetrics { font: theme.xs }
    property FontMetrics fmBaseR: FontMetrics { font: theme.baseR }
    property FontMetrics fmSmR: FontMetrics { font: theme.smR }

    function capY(fm, lh, capTop) {
        return capTop - ((lh - fm.height) / 2 + (fm.ascent - fm.capitalHeight))
    }
    function capYBase(capTop) { return capY(fmBase, lhBase, capTop) }
    function capYSm(capTop) { return capY(fmSm, lhSm, capTop) }
    function capYXs(capTop) { return capY(fmXs, lhXs, capTop) }
    function capYBaseR(capTop) { return capY(fmBaseR, lhBase, capTop) }
    function capYSmR(capTop) { return capY(fmSmR, lhSm, capTop) }
}
