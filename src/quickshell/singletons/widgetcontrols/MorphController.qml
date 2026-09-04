pragma Singleton
import QtQuick
import Quickshell
import "../../"

// Keeps track of the bar element a dash widget was opened from, so the widget
// can perform a container transform (morph out of / back into the source pill)
// instead of simply fading in place.
Item {
    id: controller

    // Raised the moment a bar module is clicked, i.e. ~100 ms before the toggle
    // makes it back through qs_manager. Main uses that dead time to map its
    // surface and render the panel once, so the morph does not have to pay for
    // it mid-motion.
    signal prewarm(string widget)

    // The bar element the currently pending / open widget was launched from.
    property var sourceItem: null
    property var sourceWindow: null
    property string sourceWidget: ""
    property real sourceRadius: 12
    property real sourceBorderWidth: 0
    property color sourceBorderColor: "transparent"

    // timing knobs for the transform, so they live next to everything else
    // that describes it rather than being buried in Main
    property int openDuration: 320
    property int closeDuration: 210

    readonly property bool enabled: {
        let g = (typeof Config !== "undefined") ? Config.getSetting("general", {}) : null;
        if (!g || g.containerMorph === undefined) return true;
        return Boolean(g.containerMorph);
    }

    // Called by a bar module right before it asks for a dash widget to be toggled.
    // `item` is the visual pill, `win` the bar PanelWindow it lives in.
    function capture(item, widgetName, radius, win) {
        if (!item || !win || !widgetName) {
            clear();
            return;
        }
        controller.sourceItem = item;
        controller.sourceWindow = win;
        controller.sourceWidget = widgetName;
        controller.sourceRadius = (radius !== undefined && radius !== null && radius > 0) ? radius : 12;

        // only Rectangles carry a frame; buttons and plain Items do not
        controller.sourceBorderWidth = 0;
        try {
            if (item.border && item.border.width > 0) {
                controller.sourceBorderWidth = item.border.width;
                controller.sourceBorderColor = item.border.color;
            }
        } catch (e) {}

        controller.prewarm(widgetName);
    }

    function clear() {
        controller.sourceItem = null;
        controller.sourceWindow = null;
        controller.sourceWidget = "";
    }

    // Geometry of the source pill in screen coordinates, or null when there is
    // nothing sensible to morph from (opened from the launcher, bar reloaded,
    // widget on another monitor, module hidden, ...).
    function originFor(widgetName, screen) {
        if (!controller.enabled) return null;
        if (!widgetName || controller.sourceWidget !== widgetName) return null;

        let item = controller.sourceItem;
        let win = controller.sourceWindow;
        if (!item || !win) return null;

        // the bar can be torn down between the click and this call, so every
        // access to the source item has to be able to fail
        try {
            if (typeof item.mapToItem !== "function") return null;
            if (screen && win.screen && screen !== win.screen) return null;
            if (item.visible === false || item.opacity < 0.05) return null;
            if (!(item.width > 4) || !(item.height > 4)) return null;

            let pos = item.mapToItem(null, 0, 0);
            if (!pos) return null;

            let ml = (win.margins && win.margins.left !== undefined) ? win.margins.left : 0;
            let mt = (win.margins && win.margins.top !== undefined) ? win.margins.top : 0;

            let rect = {
                x: pos.x + ml,
                y: pos.y + mt,
                w: item.width,
                h: item.height,
                radius: controller.sourceRadius,
                borderWidth: controller.sourceBorderWidth,
                borderColor: controller.sourceBorderColor
            };

            if (isNaN(rect.x) || isNaN(rect.y)) return null;
            return rect;
        } catch (e) {
            return null;
        }
    }
}
