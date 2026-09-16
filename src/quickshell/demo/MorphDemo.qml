import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../reusables"

// Showcase panel for the container transform. Opened from the demo pill in the
// bar, which is the only thing on this machine that records a morph origin, so
// this is the only widget that grows out of the bar instead of fading in.
Item {
    id: root

    focus: true

    function s(val) { return Scaler.s(val); }

    property real targetMasterWidth: 0
    property real targetMasterHeight: 0

    // the container transform ends on this card's border
    property real morphFrameWidth: 1
    property color morphFrameColor: ThemeBackend.mauve

    property bool morphIntro: false

    property real introMain: 0
    property real introRows: 0

    function replayIntro() {
        introMain = 0;
        introRows = 0;
        introAnim.restart();
    }

    onVisibleChanged: if (visible) { forceActiveFocus(); replayIntro(); }
    Component.onCompleted: if (visible) replayIntro();

    ParallelAnimation {
        id: introAnim
        SequentialAnimation {
            PauseAnimation { duration: root.morphIntro ? 110 : 0 }
            NumberAnimation { target: root; property: "introMain"; from: 0; to: 1; duration: 420; easing.type: Easing.OutQuart }
        }
        SequentialAnimation {
            PauseAnimation { duration: root.morphIntro ? 190 : 80 }
            NumberAnimation { target: root; property: "introRows"; from: 0; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.base
        border.width: 1
        border.color: ThemeBackend.mauve

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(18)
            spacing: root.s(12)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.s(2)
                opacity: root.introMain
                transform: Translate { y: root.s(8) * (1 - root.introMain) }

                Text {
                    text: "Container transform"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Black
                    font.pixelSize: root.s(18)
                    color: ThemeBackend.text
                }
                Text {
                    Layout.fillWidth: true
                    text: "This panel grows out of its pill in the bar and collapses back into it. "
                        + "Click the pill again, press Escape, or click anywhere outside."
                    wrapMode: Text.WordWrap
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    color: ThemeBackend.subtext0
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.5)
                opacity: root.introMain
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.s(10)
                opacity: root.introRows
                transform: Translate { y: root.s(14) * (1 - root.introRows) }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(12)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: root.s(1)
                        Text {
                            text: "Grow"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            text: "How long the pill takes to become this card"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10)
                            color: ThemeBackend.subtext0
                        }
                    }

                    NumberSelector {
                        id: openSel
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: root.s(150)
                        implicitHeight: root.s(32)
                        from: 120
                        to: 900
                        stepSize: 10
                        decimals: 0
                        suffix: " ms"
                        value: MorphController.openDuration
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        buttonColor: ThemeBackend.surface1
                        buttonTextColor: ThemeBackend.text
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontFamily: ThemeBackend.fontFamily
                        fontPixelSize: root.s(12)
                        onValueChanged: MorphController.openDuration = Math.round(openSel.value)
                        onTriggered: MorphController.openDuration = Math.round(openSel.value)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(12)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: root.s(1)
                        Text {
                            text: "Collapse"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            text: "How long it takes to fold back into the pill"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10)
                            color: ThemeBackend.subtext0
                        }
                    }

                    NumberSelector {
                        id: closeSel
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: root.s(150)
                        implicitHeight: root.s(32)
                        from: 100
                        to: 700
                        stepSize: 10
                        decimals: 0
                        suffix: " ms"
                        value: MorphController.closeDuration
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        buttonColor: ThemeBackend.surface1
                        buttonTextColor: ThemeBackend.text
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontFamily: ThemeBackend.fontFamily
                        fontPixelSize: root.s(12)
                        onValueChanged: MorphController.closeDuration = Math.round(closeSel.value)
                        onTriggered: MorphController.closeDuration = Math.round(closeSel.value)
                    }
                }
            }

            Item { Layout.fillHeight: true; Layout.fillWidth: true }

            Text {
                Layout.fillWidth: true
                opacity: root.introRows * 0.85
                text: "Everything else on this bar still opens the way it always did - only this "
                    + "pill records where the panel should come from."
                wrapMode: Text.WordWrap
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(10)
                color: ThemeBackend.overlay2
            }
        }
    }
}
