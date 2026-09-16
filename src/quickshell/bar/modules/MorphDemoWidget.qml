import QtQuick
import Quickshell
import "../../reusables"
import "../../"

// Local-only demo module: the one pill on this bar that records a morph origin,
// so the panel it opens grows out of it instead of fading in. Toggled by
// bar.morphDemo in the settings panel.
Rectangle {
    id: morphDemoRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)

    property real targetX: 0

    x: targetX
    Behavior on x {
        enabled: barWindow ? barWindow.startupCascadeFinished : true
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    height: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : 30
    y: barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - height) / 2 : 0

    property real sidePadding: barWindow ? barWindow.s(isCompact ? 6 : 8) : 8
    property real targetWidth: moduleActive ? (demoPill.implicitWidth + sidePadding * 2) : 0

    width: targetWidth
    Behavior on width {
        enabled: barWindow ? barWindow.startupCascadeFinished : true
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    opacity: moduleActive ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    property alias demoPill: demoPill

    ClickButton {
        id: demoPill
        anchors.centerIn: parent
        height: barWindow ? barWindow.s(morphDemoRoot.isCompact ? 28 : 30) : 30
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))

        buttonIcon: "󰑮"
        buttonText: "Morph"
        iconFontSize: barWindow ? barWindow.s(morphDemoRoot.isCompact ? 13 : 14) : 14
        textFontSize: barWindow ? barWindow.s(morphDemoRoot.isCompact ? 11 : 12) : 12

        accentColor: morphDemoRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
        textColor: isHoveredOrHighlighted ? ThemeBackend.mauve : (morphDemoRoot.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)

        onClicked: {
            MorphController.capture(demoPill, "morphdemo", demoPill.cornerRadius, barWindow);
            Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle morphdemo"]);
        }
    }
}
