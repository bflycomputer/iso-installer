import QtQuick
import ".."

Rectangle {
    id: root

    readonly property bool failed: Boolean(controller.failed)
    readonly property string failureMessage: String(controller.failureMessage)
    readonly property string warnings: String(controller.warnings)
    readonly property real designScale: Math.min(width / Theme.canvasW, height / Theme.canvasH)

    color: Theme.bg
    focus: true

    function submit() {
        if (failed)
            controller.powerOffComputer()
        else
            controller.restartComputer()
    }

    Keys.onPressed: function(event) {
        if (event.isAutoRepeat)
            return
        if ((!root.failed && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter))
                || (root.failed && event.key === Qt.Key_Escape)
                || (navigation.activeFocus && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space))) {
            root.submit()
            event.accepted = true
        }
    }

    Item {
        id: canvas
        width: Theme.canvasW
        height: Theme.canvasH
        anchors.centerIn: parent
        scale: root.designScale
        clip: true

        function submit() { root.submit() }

        component Artwork: Canvas {
            required property url source
            property rect imageBounds: Qt.rect(0, 0, width, height)
            property real imageRotation: 0
            property rect accent: Qt.rect(0, 0, 0, 0)
            antialiasing: true

            Component.onCompleted: loadImage(source, Qt.size(Math.ceil(imageBounds.width), Math.ceil(imageBounds.height)))
            onImageLoaded: requestPaint()
            onPaint: {
                if (!isImageLoaded(source))
                    return
                const ctx = getContext("2d")
                ctx.reset()
                ctx.save()
                ctx.globalAlpha = 0.5
                ctx.translate(imageBounds.x, imageBounds.y)
                ctx.rotate(imageRotation * Math.PI / 180)
                ctx.drawImage(source, 0, 0, imageBounds.width, imageBounds.height)
                ctx.restore()
                ctx.globalCompositeOperation = "source-in"
                ctx.fillStyle = "#c390ff"
                ctx.fillRect(0, 0, width, height)
                if (accent.width > 0) {
                    ctx.globalCompositeOperation = "destination-over"
                    ctx.fillStyle = Theme.bg
                    ctx.fillRect(accent.x, accent.y, accent.width, accent.height)
                    ctx.globalCompositeOperation = "qt-difference"
                    ctx.fillStyle = Theme.green
                    ctx.fillRect(accent.x, accent.y, accent.width, accent.height)
                }
            }
        }

        Artwork {
            objectName: "completionLeafTop"
            x: 52
            y: -96
            width: 428
            height: 388
            source: "../../assets/illustrations/lilypad.png"
            imageBounds: Qt.rect(-117.87, 89.51, 421.73, 527.17)
            imageRotation: -33.67
            accent: Qt.rect(338, 126, 80, 80)
        }

        Artwork {
            objectName: "completionButterfly"
            x: 1256
            y: 49
            width: 319
            height: 400
            source: "../../assets/illustrations/butterfly.png"
            imageBounds: Qt.rect(-0.64, -0.66, 314.45, 393.06)
        }

        Artwork {
            objectName: "completionLeafBottom"
            x: 1316
            y: 889
            width: 303
            height: 275
            source: "../../assets/illustrations/lilypad.png"
            imageBounds: Qt.rect(380.93, 99.98, 299.78, 374.73)
            imageRotation: 119.97
        }

        Rectangle {
            x: 1216
            width: 40
            height: 40
            color: "#ff9f67"
        }

        Rectangle {
            x: 303
            y: 1077
            width: 40
            height: 40
            color: "#ff9f67"
        }

        Rectangle {
            objectName: "completionRing"
            x: 1640
            y: 680
            width: 40
            height: 40
            color: "transparent"
            border.width: 1
            border.color: Theme.lavender
            antialiasing: true

            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: Theme.lavender
                antialiasing: true
            }
        }

        Rectangle {
            x: 1640
            y: 720
            width: 40
            height: 40
            color: "#ff96da"
        }

        Image {
            objectName: "completionLogo"
            x: 250
            y: 390
            width: 140
            height: 140
            source: "../../assets/icons/pond-logo.svg"
            sourceSize: Qt.size(280, 280)
            mipmap: true
        }

        FontMetrics { id: headingMetrics; font: heading.font }
        Label {
            id: heading
            objectName: "completionHeading"
            x: 782
            y: Theme.capY(headingMetrics, 72, 399)
            width: 427
            text: root.failed ? "Installation\nfailed" : "Installation\ncomplete"
            color: root.failed ? Theme.textError : Theme.lavender
            font.family: Theme.displayFont
            font.pixelSize: 72
            font.italic: true
            font.letterSpacing: -2.16
            lh: 72
            wrapMode: Text.WordWrap
        }

        FontMetrics { id: messageMetrics; font: message.font }
        Flickable {
            id: messageArea
            x: 782
            y: Theme.capY(messageMetrics, 24, 569)
            width: root.failed || root.warnings.length > 0 ? 427 : 344
            height: Math.min(320, message.height)
            contentHeight: message.height
            contentWidth: width
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Label {
                id: message
                objectName: "completionMessage"
                width: messageArea.width
                text: {
                    let paragraphs = root.failed
                        ? [root.failureMessage || "The installation failed before it finished."]
                        : ["Pond has been installed successfully."]
                    if (root.warnings.length > 0)
                        paragraphs.push(root.warnings)
                    paragraphs.push(root.failed
                        ? "Please reach out to us so we can fix it. You can also try shutting down and trying again."
                        : "You can now restart to boot into Pond. Thank you for joining our Early Preview.")
                    return paragraphs.join("\n\n")
                }
                textFormat: Text.PlainText
                color: "#dec2ff"
                opacity: 0.7
                font.family: Theme.onest.name
                font.pixelSize: 17
                font.weight: Font.Normal
                font.letterSpacing: 0.17
                font.hintingPreference: Font.PreferNoHinting
                lh: 24
                wrapMode: Text.Wrap
            }
        }

        Rectangle {
            visible: messageArea.interactive
            x: messageArea.x + messageArea.width + 12
            y: messageArea.y + messageArea.visibleArea.yPosition * messageArea.height
            width: 2
            height: messageArea.visibleArea.heightRatio * messageArea.height
            radius: 1
            color: Theme.chromeMuted
        }

        NavBar {
            id: navigation
            objectName: "completionNavigation"
            x: 782
            y: Math.max(693, messageArea.y + messageArea.height + 28)
            label: root.failed ? "Shut down" : "Restart"
            showBack: false
            activeFocusOnTab: true
            focused: activeFocus
        }

        ErrorText {
            objectName: "completionActionError"
            x: 782
            y: navigation.y + navigation.height + 24
            anchors.horizontalCenter: undefined
            width: 427
            text: controller.errorMessage
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }

        Rectangle {
            x: 10
            y: 1037
            width: 116
            height: 30
            color: "transparent"
            border.width: 1
            border.color: Theme.chromeMuted
            radius: 4

            Label {
                anchors.centerIn: parent
                text: "ISO INSTALLER"
                color: Theme.chromeMuted
                font: Theme.monoXs
                lh: 12
            }
        }

        Label {
            x: 10
            y: 1071
            text: "Early Preview"
            color: Theme.chromeMuted
            font: Theme.xl
            lh: Theme.lhXl
        }
    }
}
