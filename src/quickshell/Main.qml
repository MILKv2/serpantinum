import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Networking
import "WindowRegistry.js" as Registry
import "notifications" as Notifs

PanelWindow {
    id: masterWindow
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: masterWindow.isVisible
        onActivated: switchWidget("hidden", "")
    }

    function resolveTargetScreen() {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor) {
                let monName = Hyprland.focusedMonitor.name;
                let screens = Quickshell.screens || [];
                let len = screens.length !== undefined ? screens.length : (screens.count !== undefined ? screens.count : 0);
                for (let i = 0; i < len; i++) {
                    let s = screens[i] !== undefined ? screens[i] : screens.get(i);
                    if (s && s.name === monName) return s;
                }
            }
        } catch (e) {}

        try {
            if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.screens && ToplevelManager.activeToplevel.screens.length > 0) {
                return ToplevelManager.activeToplevel.screens[0];
            }
        } catch (e) {}

        if (masterWindow.screen) return masterWindow.screen;
        return (Quickshell.screens && (Quickshell.screens.length > 0 || Quickshell.screens.count > 0))
            ? (Quickshell.screens[0] || Quickshell.screens.get(0))
            : null;
    }

    function reportWidgetState() {
        if (typeof Caching === "undefined" || !Caching.runDir) return;
        let sName = (masterWindow.currentActive === "hidden" || !masterWindow.screen) ? "" : (masterWindow.screen.name || "");
        let payload = JSON.stringify({
            widget: masterWindow.currentActive,
            screen: sName
        });
        Quickshell.execDetached(["bash", "-c", "echo '" + payload + "' > " + Caching.runDir + "/current_widget"]);
    }

    Process {
        id: startupResetProcess
        command: ["bash", "-c", `[ -n "${Caching.runDir}" ] && echo '{"widget":"hidden","screen":""}' > "${Caching.runDir}/current_widget"`]
        running: true
    }

    Connections {
        target: (typeof Caching !== "undefined") ? Caching : null
        function onRunDirChanged() {
            masterWindow.reportWidgetState();
        }
    }

    IpcHandler {
        target: "main"

        function forceReload(): void {
            Quickshell.reload(true);
        }

        function clearNotifications(): void {
            NotificationManager.clearNotifications();
        }

        function handleCommand(cmd: string, targetWidget: string, arg: string): void {
            cmd = cmd || "";
            targetWidget = targetWidget || "";
            arg = arg || "";

            if (cmd === "clearNotifications" || cmd === "clear_notifications" || cmd === "clearNotifs") {
                NotificationManager.clearNotifications();
                return;
            }

            if (cmd === "launcher" || targetWidget === "launcher") {
                if (cmd === "close") {
                    LauncherController.hide();
                } else if (cmd === "open") {
                    ClipboardController.hide();
                    LauncherController.show();
                } else {
                    ClipboardController.hide();
                    LauncherController.toggle();
                }
                return;
            }

            if (cmd === "clipboard" || targetWidget === "clipboard" || cmd === "clip" || targetWidget === "clip") {
                if (cmd === "close") {
                    ClipboardController.hide();
                } else if (cmd === "open") {
                    LauncherController.hide();
                    ClipboardController.show();
                } else {
                    LauncherController.hide();
                    ClipboardController.toggle();
                }
                return;
            }

            if (cmd === "airplane" || targetWidget === "airplane" || cmd === "flight" || targetWidget === "flight") {
                let isAirplane = !Networking.wifiEnabled && !(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled);
                if (isAirplane) {
                    Networking.wifiEnabled = true;
                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = true;
                } else {
                    Networking.wifiEnabled = false;
                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = false;
                }
                return;
            }

            if (cmd === "autohide" || targetWidget === "autohide") {
                let bar = Config.getSetting("bar", {});
                bar.autohide = !bar.autohide;
                Config.setSetting("bar", bar);
                return;
            }

            let effectivelyActive = masterWindow.targetActive;

            if (cmd === "close") {
                switchWidget("hidden", "");
            } else if (cmd === "toggle" || cmd === "open") {
                if (targetWidget === effectivelyActive) {
                    let currentItem = widgetCache[targetWidget] || widgetStack.currentItem;

                    if (arg !== "" && arg !== masterWindow.activeArg) {
                        masterWindow.activeArg = arg;
                        if (currentItem && currentItem.activeMode !== undefined) {
                            currentItem.activeMode = arg;
                        }
                        if (currentItem && currentItem.gotoTab !== undefined) {
                            currentItem.gotoTab(arg);
                        }
                    } else if (cmd === "toggle") {
                        switchWidget("hidden", "");
                    }
                } else if (getLayout(targetWidget)) {
                    switchWidget(targetWidget, arg);
                }
            } else if (getLayout(cmd)) {
                let legacyArg = targetWidget;

                if (cmd === effectivelyActive) {
                    let currentItem = widgetCache[cmd] || widgetStack.currentItem;
                    if (legacyArg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== legacyArg) {
                        currentItem.activeMode = legacyArg;
                    } else if (legacyArg !== "" && currentItem && currentItem.gotoTab !== undefined) {
                        currentItem.gotoTab(legacyArg);
                    } else {
                        switchWidget("hidden", "");
                    }
                } else {
                    switchWidget(cmd, legacyArg);
                }
            }
        }

        function getWidgetGeometry(widgetName: string): void {
            let layout = getLayout(widgetName);
            if (layout) {
                let geo = {
                    startX: Math.round(layout.rx),
                    startY: Math.round(layout.ry),
                    endX: Math.round(layout.rx + layout.w),
                    endY: Math.round(layout.ry + layout.h)
                };
                Quickshell.execDetached(["bash", "-c", "echo '" + JSON.stringify(geo) + "' > " + Caching.runDir + "/tutorial_target.json"]);
            }
        }
    }

    WlrLayershell.namespace: "qs-master"
    WlrLayershell.layer: WlrLayer.Overlay

    exclusionMode: ExclusionMode.Ignore
    // keyboard focus is on demand, so a click is what would hand it over - and
    // while prewarming or closing nothing can be clicked anyway
    focusable: masterWindow.isVisible || masterWindow.prewarming

    implicitWidth: masterWindow.screen ? masterWindow.screen.width : 0
    implicitHeight: masterWindow.screen ? masterWindow.screen.height : 0

    // stays mapped while prewarming and while the closing morph plays out
    visible: isVisible || morphClosing || prewarming

    Region {
        id: maskRegion
        item: masterWindow.isCurrentDraggable ? animContainer : topBarHole
        intersection: masterWindow.isCurrentDraggable ? Intersection.Combine : Intersection.Xor
    }
    // 1x1 dummy: everything is click-through while the surface is up but the
    // widget is not (prewarming, or collapsing back into its pill)
    Region { id: passthroughRegion; width: 1; height: 1 }

    mask: (masterWindow.morphClosing || !masterWindow.isVisible) ? passthroughRegion : maskRegion

    property var rawBarSettings: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({})
    property string barPosition: (rawBarSettings && rawBarSettings.position !== undefined) ? rawBarSettings.position : "top"
    property bool barAutohide: (rawBarSettings && rawBarSettings.autohide !== undefined) ? Boolean(rawBarSettings.autohide) : false

    readonly property bool isFullscreenActive: {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
                return Boolean(Hyprland.focusedWorkspace.hasFullscreen || (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen));
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreenActive
    readonly property bool screenReady: masterWindow.width >= 100 && masterWindow.height >= 100
    readonly property bool isCurrentDraggable: {
        let t = getLayout(masterWindow.currentActive);
        return Boolean(t && t.draggable) || masterWindow.currentActive === "guide";
    }

    Item {
        id: topBarHole

        property int barThickness: 48
        property string bp: masterWindow.barPosition
        property bool activeBar: !masterWindow.isBarEffectivelyHidden

        property bool overlapTopLeft: masterWindow.currentActive !== "hidden" && animContainer.x < 10 && animContainer.y < barThickness
        property bool overlapTopRight: masterWindow.currentActive !== "hidden" && (animContainer.x + animContainer.width) > (masterWindow.width - 10) && animContainer.y < barThickness
        property bool overlapBottomLeft: masterWindow.currentActive !== "hidden" && animContainer.x < 10 && (animContainer.y + animContainer.height) > (masterWindow.height - barThickness)
        property bool overlapBottomRight: masterWindow.currentActive !== "hidden" && (animContainer.x + animContainer.width) > (masterWindow.width - 10) && (animContainer.y + animContainer.height) > (masterWindow.height - barThickness)

        x: {
            if (!activeBar) return 0;
            if (bp === "left") return 0;
            if (bp === "right") return masterWindow.width - barThickness;
            if (overlapTopLeft && bp === "top") return animContainer.width;
            if (overlapBottomLeft && bp === "bottom") return animContainer.width;
            return 0;
        }

        y: {
            if (!activeBar) return 0;
            if (bp === "top") return 0;
            if (bp === "bottom") return masterWindow.height - barThickness;
            if (overlapTopLeft && bp === "left") return animContainer.height;
            if (overlapTopRight && bp === "right") return animContainer.height;
            return 0;
        }

        width: {
            if (!activeBar) return 0;
            if (bp === "left" || bp === "right") return barThickness;
            let w = masterWindow.width;
            if (overlapTopLeft && bp === "top") w -= animContainer.width;
            if (overlapTopRight && bp === "top") w -= animContainer.width;
            if (overlapBottomLeft && bp === "bottom") w -= animContainer.width;
            if (overlapBottomRight && bp === "bottom") w -= animContainer.width;
            return Math.max(0, w);
        }

        height: {
            if (!activeBar) return 0;
            if (bp === "top" || bp === "bottom") return barThickness;
            let h = masterWindow.height;
            if (overlapTopLeft && bp === "left") h -= animContainer.height;
            if (overlapBottomLeft && bp === "left") h -= animContainer.height;
            if (overlapTopRight && bp === "right") h -= animContainer.height;
            if (overlapBottomRight && bp === "right") h -= animContainer.height;
            return Math.max(0, h);
        }

        Behavior on x {
            enabled: masterWindow.currentActive !== "hidden" && !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: masterWindow.currentActive !== "hidden" && !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: masterWindow.currentActive !== "hidden" && !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: masterWindow.currentActive !== "hidden" && !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: masterWindow.isVisible && !masterWindow.isCurrentDraggable
        onClicked: switchWidget("hidden", "")
    }

    Item {
        id: preloaderContainer
        visible: false
    }

    property var widgetCache: ({})
    property var componentCache: ({})
    property var _allWidgetNames: ["battery", "network", "volume", "guide", "calendar", "wallpaper", "music", "movies", "notifications", "system"]
    property int _preloadIndex: 0

    function widgetNameForItem(item) {
        for (let name in widgetCache) {
            if (widgetCache[name] === item) return name;
        }
        return null;
    }

    function ensureWidgetItem(name, t) {
        let cached = widgetCache[name];
        if (cached) return cached;

        let comp = componentCache[name];
        if (!comp) {
            comp = typeof t.comp === "string" ? Qt.createComponent(t.comp) : t.comp;
            if (comp) componentCache[name] = comp;
        }
        if (!comp) return null;

        if (comp.status === Component.Loading) return null;
        if (comp.status === Component.Error) {
            console.warn("Widget component failed to load:", name, comp.errorString());
            return null;
        }

        let item = comp.createObject(preloaderContainer);
        if (item) widgetCache[name] = item;
        return item;
    }

    function preloadWidget(name) {
        let t = getLayout(name);
        if (!t || !t.comp) return;
        ensureWidgetItem(name, t);
    }

    Component.onCompleted: {
        reportWidgetState();
        preloadStaggerTimer.start();
    }

    Component.onDestruction: {
        if (typeof Caching !== "undefined" && Caching.runDir) {
            Quickshell.execDetached(["bash", "-c", "echo '{\"widget\":\"hidden\",\"screen\":\"\"}' > " + Caching.runDir + "/current_widget"]);
        }
    }

    Timer {
        id: preloadStaggerTimer
        interval: 150
        repeat: true
        onTriggered: {
            if (masterWindow._preloadIndex >= masterWindow._allWidgetNames.length) {
                preloadStaggerTimer.stop();
                return;
            }
            if (masterWindow.currentActive !== "hidden") {
                return;
            }
            preloadWidget(masterWindow._allWidgetNames[masterWindow._preloadIndex]);
            masterWindow._preloadIndex++;
        }
    }

    property string targetActive: "hidden"
    property string currentActive: "hidden"

    onCurrentActiveChanged: {
        reportWidgetState();
    }

    onScreenChanged: {
        if (currentActive !== "hidden") {
            reportWidgetState();
        }
    }

    property bool isVisible: false
    property string activeArg: ""
    property bool disableMorph: true
    property int switchGeneration: 0
    property bool userMoved: false

    property int morphDuration:       300
    property int morphDurationSwitch: 300
    property int exitDuration:        180

    property real _animW: 1
    property real _animH: 1
    property real _animX: 0
    property real _animY: 0

    property real _stageW: 1
    property real _stageH: 1

    property real globalUiScale: 1.0

    // ---------------------------------------------------------------------
    // container transform
    //
    // When a dash widget is opened from a bar module, the panel does not fade
    // in place: a plate is drawn at the source pill's geometry and morphed
    // (position, size, corner radius) into the panel's bounds while the panel
    // content is masked to that plate and cross-faded in. Closing plays the
    // same thing backwards, so the panel collapses back into its pill.
    // ---------------------------------------------------------------------

    // {x, y, w, h, radius} of the source pill in screen coordinates, or null
    property var morphOrigin: null
    // 0 = fully collapsed onto the source pill, 1 = panel bounds
    property real morphT: 1.0
    // panel content cross-fade, 0 = invisible
    property real contentReveal: 0.0
    // true while a morph is in flight (mask + plate are only paid for then)
    property bool morphRunning: false
    // true from the moment a close starts until the window may be unmapped
    property bool morphClosing: false

    property int morphOpenDuration:  MorphController.openDuration
    property int morphCloseDuration: MorphController.closeDuration
    property int fadeOpenDuration:   180

    property int _openDuration: morphOpenDuration
    property int _closeDuration: morphCloseDuration

    // surface is up and the panel has been rendered once, but nothing is shown
    property bool prewarming: false

    Connections {
        target: (typeof MorphController !== "undefined") ? MorphController : null
        function onPrewarm(widget) { masterWindow.prewarmWidget(widget); }
    }

    // Runs on the click, not on the command that follows it. Only ever from a
    // closed dash: with a widget already open there is no surface to map, and
    // swapping the stack under it would skip the switch animation.
    function prewarmWidget(name) {
        if (!name || name === "hidden") return;
        if (masterWindow.isVisible || masterWindow.currentActive !== "hidden") return;
        if (!MorphController.enabled) return;

        let targetScreen = resolveTargetScreen();
        if (targetScreen && masterWindow.screen !== targetScreen) masterWindow.screen = targetScreen;

        let t = getLayout(name);
        if (!t || !t.w || !t.h || t.w < 10 || t.h < 10) return;

        let item = ensureWidgetItem(name, t);
        if (!item) return;

        let origin = masterWindow._morphOriginFor(name);
        if (!origin) return;

        if (item.targetMasterWidth !== undefined) item.targetMasterWidth = t.w;
        if (item.targetMasterHeight !== undefined) item.targetMasterHeight = t.h;
        if (item.morphIntro !== undefined) item.morphIntro = true;

        let w = (typeof item.targetMasterWidth === "number" && item.targetMasterWidth >= 50) ? item.targetMasterWidth : t.w;
        let h = (typeof item.targetMasterHeight === "number" && item.targetMasterHeight >= 50) ? item.targetMasterHeight : t.h;

        masterWindow.disableMorph = true;
        masterWindow._animX = (w !== t.w) ? recenterX(t, w) : t.rx;
        masterWindow._animY = t.ry;
        masterWindow._animW = w;
        masterWindow._animH = h;
        masterWindow._stageW = w;
        masterWindow._stageH = h;

        if (widgetStack.currentItem !== item) widgetStack.replace(item, {}, StackView.Immediate);

        masterWindow.morphOrigin = origin;
        masterWindow._applyOriginFrame(origin);
        masterWindow.morphT = 0.0;
        masterWindow.frameReveal = 0.0;
        masterWindow.morphRunning = true;
        // invisible, but enough to make the scene graph actually render the
        // panel into the mask layer instead of skipping it
        masterWindow.contentReveal = 0.01;
        masterWindow.prewarming = true;
        prewarmTimeout.restart();
    }

    function cancelPrewarm() {
        prewarmTimeout.stop();
        if (!masterWindow.prewarming) return;
        masterWindow.prewarming = false;
        if (!masterWindow.isVisible && !masterWindow.morphClosing) {
            masterWindow.morphRunning = false;
            masterWindow.morphOrigin = null;
            masterWindow.contentReveal = 0.0;
        }
    }

    // the toggle never arrived (the click closed something else, qs_manager
    // failed, ...) - drop the surface again
    Timer {
        id: prewarmTimeout
        interval: 900
        onTriggered: masterWindow.cancelPrewarm()
    }

    // frame the morphing container ends on. Panels are 1px surface0 cards by
    // default and can say otherwise (MusicPopup's ring is thicker and tinted)
    readonly property var _panelItem: widgetStack.currentItem
    readonly property real panelFrameWidth: (_panelItem && _panelItem.morphFrameWidth !== undefined) ? _panelItem.morphFrameWidth : 1
    readonly property color panelFrameColor: (_panelItem && _panelItem.morphFrameColor !== undefined) ? _panelItem.morphFrameColor : ThemeBackend.surface0
    readonly property real panelRadius: (_panelItem && _panelItem.morphCornerRadius !== undefined) ? _panelItem.morphCornerRadius : ThemeBackend.borderRadius

    // frame the container starts from, i.e. the bar pill's own border
    property real originFrameWidth: 0
    property color originFrameColor: "transparent"

    readonly property bool morphMasking: morphRunning && morphOrigin !== null
    readonly property var _morphRect: morphRunning ? morphOrigin : null
    readonly property real _morphT: morphRunning ? morphT : 1.0

    // plate geometry, in animContainer coordinates
    readonly property real plateX: _morphRect ? (_morphRect.x - animContainer.x) * (1.0 - _morphT) : 0
    readonly property real plateY: _morphRect ? (_morphRect.y - animContainer.y) * (1.0 - _morphT) : 0
    readonly property real plateW: _morphRect ? _morphRect.w + (animContainer.width  - _morphRect.w) * _morphT : animContainer.width
    readonly property real plateH: _morphRect ? _morphRect.h + (animContainer.height - _morphRect.h) * _morphT : animContainer.height
    readonly property real plateRadius: _morphRect ? _morphRect.radius + (panelRadius - _morphRect.radius) * _morphT : panelRadius
    // hides the hand-off frame where the real bar pill is still underneath
    readonly property real plateOpacity: _morphRect ? Math.min(1.0, _morphT * 9.0) : 0.0

    // The frame is drawn over the panel, so the container always has a crisp
    // edge: it covers the seam where the mask cuts the panel, and it takes the
    // destination's look early (twice the shape's rate) so the box reads as the
    // card it is turning into rather than a bare slab.
    readonly property real _frameT: Math.min(1.0, _morphT * 2.0)
    readonly property real frameWidth: _morphRect ? (originFrameWidth + (panelFrameWidth - originFrameWidth) * _frameT) : panelFrameWidth
    readonly property color frameColor: _morphRect ? Qt.rgba(
            originFrameColor.r + (panelFrameColor.r - originFrameColor.r) * _frameT,
            originFrameColor.g + (panelFrameColor.g - originFrameColor.g) * _frameT,
            originFrameColor.b + (panelFrameColor.b - originFrameColor.b) * _frameT,
            originFrameColor.a + (panelFrameColor.a - originFrameColor.a) * _frameT
        ) : panelFrameColor
    // Driven on its own timeline rather than off the shape's progress: the
    // shape curve is front loaded, so anything keyed to it would snap in on
    // the first frame. The border instead blooms in and dissolves out over
    // real time - out of the pill's edge at the start, into the panel's own
    // border (which by then sits exactly underneath) at the end.
    property real frameReveal: 0.0
    readonly property real frameOpacity: _morphRect ? frameReveal : 0.0

    function _applyOriginFrame(origin) {
        if (!origin) {
            masterWindow.originFrameWidth = 0;
            return;
        }
        masterWindow.originFrameWidth = origin.borderWidth || 0;
        // a pill without a frame has no meaningful border colour to start from
        masterWindow.originFrameColor = (origin.borderWidth > 0 && origin.borderColor)
            ? origin.borderColor
            : masterWindow.panelFrameColor;
    }

    function _morphOriginFor(widgetName) {
        if (widgetName === "" || widgetName === "hidden") return null;
        let scr = masterWindow.screen;
        let origin = MorphController.originFor(widgetName, scr);
        if (!origin) return null;
        // ignore nonsense (bar off screen, stale geometry, ...)
        if (origin.w < 8 || origin.h < 8) return null;
        if (origin.x < -origin.w || origin.y < -origin.h) return null;
        if (origin.x > masterWindow.width || origin.y > masterWindow.height) return null;
        return origin;
    }

    function startOpenAnimation(origin) {
        openWarmup.running = false;
        morphCloseAnim.stop();
        morphOpenAnim.stop();

        masterWindow.morphClosing = false;
        masterWindow.morphOrigin = origin;
        masterWindow._applyOriginFrame(origin);

        if (origin) {
            if (!masterWindow.morphRunning) {
                masterWindow.morphT = 0.0;
                masterWindow.frameReveal = 0.0;
            }
            masterWindow.morphRunning = true;
            masterWindow._openDuration = Math.max(140, Math.round(masterWindow.morphOpenDuration * (1.0 - masterWindow.morphT)));
        } else {
            masterWindow.morphRunning = false;
            masterWindow.morphT = 1.0;
            masterWindow._openDuration = masterWindow.fadeOpenDuration;
        }

        // Opening maps the layer surface and renders the panel for the first
        // time, which costs ~50 ms and used to be spent mid-motion, so the
        // first two frames of every open were dropped. Nothing is on screen
        // yet at this point (plate and content are still fully transparent),
        // so the animation just waits for the frame rate to settle first. The
        // sliver of content opacity is what forces that first render to
        // actually happen instead of being skipped.
        masterWindow.contentReveal = 0.01;
        openWarmup.restart();
    }

    FrameAnimation {
        id: openWarmup
        running: false
        property int waited: 0

        onRunningChanged: if (running) waited = 0

        onTriggered: {
            waited++;
            if (frameTime < 0.020 || waited >= 4) {
                running = false;
                morphOpenAnim.restart();
            }
        }
    }

    function startCloseAnimation(origin) {
        openWarmup.running = false;
        morphOpenAnim.stop();
        morphCloseAnim.stop();

        // nothing to collapse into: the window is dropped on the spot, exactly
        // as it was before there was a morph at all
        if (!origin) {
            masterWindow.morphRunning = false;
            masterWindow.morphClosing = false;
            masterWindow.morphOrigin = null;
            masterWindow.contentReveal = 0.0;
            return;
        }

        masterWindow.morphClosing = true;
        masterWindow.morphOrigin = origin;
        masterWindow._applyOriginFrame(origin);
        masterWindow.morphRunning = true;
        masterWindow.frameReveal = 1.0;
        masterWindow._closeDuration = Math.max(140, Math.round(masterWindow.morphCloseDuration * masterWindow.morphT));

        morphCloseAnim.restart();
    }

    SequentialAnimation {
        id: morphOpenAnim

        ParallelAnimation {
            NumberAnimation {
                target: masterWindow
                property: "morphT"
                to: 1.0
                duration: masterWindow._openDuration
                // material "emphasized decelerate": the box shoots out and settles
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.1, 0.8, 0.2, 1.0, 1.0, 1.0]
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: masterWindow.morphRunning ? Math.round(masterWindow._openDuration * 0.24) : 0
                }
                NumberAnimation {
                    target: masterWindow
                    property: "contentReveal"
                    to: 1.0
                    duration: masterWindow.morphRunning ? Math.round(masterWindow._openDuration * 0.62) : masterWindow._openDuration
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                NumberAnimation {
                    target: masterWindow
                    property: "frameReveal"
                    to: 1.0
                    duration: Math.round(masterWindow._openDuration * 0.40)
                    easing.type: Easing.OutCubic
                }
                PauseAnimation { duration: Math.round(masterWindow._openDuration * 0.28) }
                NumberAnimation {
                    target: masterWindow
                    property: "frameReveal"
                    to: 0.0
                    duration: Math.round(masterWindow._openDuration * 0.32)
                    easing.type: Easing.InOutSine
                }
            }
        }

        ScriptAction {
            script: {
                masterWindow.morphRunning = false;
                masterWindow.morphOrigin = null;
            }
        }
    }

    SequentialAnimation {
        id: morphCloseAnim

        ParallelAnimation {
            NumberAnimation {
                target: masterWindow
                property: "morphT"
                to: 0.0
                duration: masterWindow._closeDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.3, 0.0, 0.7, 0.2, 1.0, 1.0]
            }
            NumberAnimation {
                target: masterWindow
                property: "contentReveal"
                to: 0.0
                duration: Math.round(masterWindow._closeDuration * 0.55)
                easing.type: Easing.InCubic
            }

            SequentialAnimation {
                PauseAnimation { duration: Math.round(masterWindow._closeDuration * 0.45) }
                NumberAnimation {
                    target: masterWindow
                    property: "frameReveal"
                    to: 0.0
                    duration: Math.round(masterWindow._closeDuration * 0.55)
                    easing.type: Easing.InOutSine
                }
            }
        }

        ScriptAction {
            script: {
                masterWindow.morphRunning = false;
                masterWindow.morphOrigin = null;
                masterWindow.morphClosing = false;
                if (masterWindow.currentActive === "hidden") masterWindow.isVisible = false;
            }
        }
    }

    Notifs.NotificationPopups {
        id: osdPopups
    }

    Process {
        id: settingsReader
        command: ["bash", "-c", `cat "${Config.settingsJsonPath}" 2>/devnull || echo '{}'`]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                        let parsed = JSON.parse(this.text);
                        let sName = masterWindow.screen ? masterWindow.screen.name : "";
                        let sVal = undefined;

                        if (sName !== "" && parsed.display && parsed.display.monitors && parsed.display.monitors[sName] && parsed.display.monitors[sName].scale !== undefined) {
                            sVal = parsed.display.monitors[sName].scale;
                        } else if (parsed.general && parsed.general.uiScale !== undefined) {
                            sVal = parsed.general.uiScale;
                        } else if (parsed.uiScale !== undefined) {
                            sVal = parsed.uiScale;
                        }

                        if (sVal !== undefined && masterWindow.globalUiScale !== sVal) {
                            masterWindow.globalUiScale = sVal;
                        }

                        if (parsed.bar) {
                            masterWindow.rawBarSettings = parsed.bar;
                            if (parsed.bar.position !== undefined) masterWindow.barPosition = parsed.bar.position;
                            if (parsed.bar.autohide !== undefined) masterWindow.barAutohide = Boolean(parsed.bar.autohide);
                        }
                    }
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: settingsWatcher
        command: ["bash", "-c", `while [ ! -f "${Config.settingsJsonPath}" ]; do sleep 1; done; inotifywait -qq -e modify,close_write "${Config.settingsJsonPath}"`]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                settingsReader.running = false;
                settingsReader.running = true;
                settingsWatcher.running = false;
                settingsWatcher.running = true;
            }
        }
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            let b = (Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : {};
            masterWindow.rawBarSettings = b;
            masterWindow.barPosition = (b && b.position !== undefined) ? b.position : "top";
            masterWindow.barAutohide = (b && b.autohide !== undefined) ? Boolean(b.autohide) : false;
        }
    }

    function getLayout(name) {
        let bp = masterWindow.barPosition;
        let effHidden = masterWindow.isBarEffectivelyHidden;
        let scrW = masterWindow.screen ? masterWindow.screen.width : masterWindow.width;
        let scrH = masterWindow.screen ? masterWindow.screen.height : masterWindow.height;

        let result = Registry.getLayout(name, 0, 0, scrW, scrH, masterWindow.globalUiScale, bp);
        if (!result) return null;

        let scale = masterWindow.globalUiScale || 1.0;
        let isFixed = (name === "guide" || name === "wallpaper" || name === "notifications" || name === "system" || name === "hidden");

        if (effHidden && !isFixed) {
            let offsetAdjustment = Math.round(46 * scale);
            let adjusted = {
                w: result.w,
                h: result.h,
                rx: result.rx,
                ry: result.ry,
                comp: result.comp,
                draggable: result.draggable
            };

            if (bp === "top") {
                adjusted.ry = Math.max(Math.round(6 * scale), result.ry - offsetAdjustment);
            } else if (bp === "bottom") {
                adjusted.ry = Math.min(masterWindow.height - result.h - Math.round(6 * scale), result.ry + offsetAdjustment);
            } else if (bp === "left" && name !== "calendar") {
                adjusted.rx = Math.max(Math.round(6 * scale), result.rx - offsetAdjustment);
            } else if (bp === "right" && name !== "calendar") {
                adjusted.rx = Math.min(masterWindow.width - result.w - Math.round(6 * scale), result.rx + offsetAdjustment);
            }

            return adjusted;
        }

        return result;
    }

    function recenterX(t, dynW) {
        let originalCenterX = t.rx + Math.floor(t.w / 2);
        return Math.floor(originalCenterX - (dynW / 2));
    }

    readonly property var targetLayout: {
        if (currentActive === "hidden" || currentActive === "") return null;
        if (!screenReady) return null;

        let t = getLayout(currentActive);
        if (!t || !t.w || !t.h || t.w < 10 || t.h < 10) return null;

        if (t.rx < -t.w - 50 || t.ry < -t.h - 50 ||
            t.rx > masterWindow.width + 50 || t.ry > masterWindow.height + 50) {
            return null;
        }

        let item = widgetCache[currentActive];
        let tw = t.w, th = t.h;
        if (item) {
            if (typeof item.targetMasterWidth === "number" && !isNaN(item.targetMasterWidth) && item.targetMasterWidth >= 50) {
                tw = item.targetMasterWidth;
            }
            if (typeof item.targetMasterHeight === "number" && !isNaN(item.targetMasterHeight) && item.targetMasterHeight >= 50) {
                th = item.targetMasterHeight;
            }
        }

        let x = (tw !== t.w) ? recenterX(t, tw) : t.rx;
        return { x: x, y: t.ry, w: tw, h: th };
    }

    onTargetLayoutChanged: {
        if (!targetLayout || masterWindow.currentActive === "hidden" || !masterWindow.isVisible) return;
        if (!masterWindow.userMoved || !masterWindow.isCurrentDraggable) {
            masterWindow._animX = targetLayout.x;
            masterWindow._animY = targetLayout.y;
        }
        masterWindow._animW = targetLayout.w;
        masterWindow._animH = targetLayout.h;
        masterWindow._stageW = targetLayout.w;
        masterWindow._stageH = targetLayout.h;
    }

    onIsVisibleChanged: {
        if (isVisible) widgetStack.forceActiveFocus();
    }

    Item {
        id: animContainer
        x: masterWindow._animX
        y: masterWindow._animY
        width: masterWindow._animW
        height: masterWindow._animH

        // the morphing container itself: sits under the panel and carries the
        // shape from the bar pill to the panel bounds
        Rectangle {
            id: morphPlate
            x: masterWindow.plateX
            y: masterWindow.plateY
            width: masterWindow.plateW
            height: masterWindow.plateH
            radius: masterWindow.plateRadius
            color: ThemeBackend.base
            opacity: masterWindow.plateOpacity
            visible: masterWindow.morphMasking
        }

        // mask used to keep the panel inside the morphing container
        Item {
            id: morphMaskSource
            anchors.fill: parent
            visible: false
            layer.enabled: masterWindow.morphMasking

            Rectangle {
                x: masterWindow.plateX
                y: masterWindow.plateY
                width: masterWindow.plateW
                height: masterWindow.plateH
                radius: masterWindow.plateRadius
                color: "black"
            }
        }

        DragHandler {
            id: windowDragHandler
            target: null
            acceptedButtons: Qt.LeftButton
            enabled: masterWindow.isCurrentDraggable

            property real startX: 0
            property real startY: 0

            onActiveChanged: {
                if (active) {
                    masterWindow.disableMorph = true;
                    startX = masterWindow._animX;
                    startY = masterWindow._animY;
                } else {
                    masterWindow.disableMorph = false;
                }
            }

            onTranslationChanged: {
                if (active) {
                    masterWindow.userMoved = true;
                    masterWindow._animX = startX + translation.x;
                    masterWindow._animY = startY + translation.y;
                }
            }
        }

        Item {
            id: stageHost
            anchors.fill: parent
            clip: true

            layer.enabled: masterWindow.morphMasking
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: morphMaskSource
            }

            Item {
                id: contentStage
                width: masterWindow._stageW
                height: masterWindow._stageH
                // during a morph the panel drifts out of the pill instead of
                // being pinned to its final spot
                x: (animContainer.width - width) / 2
                    + (masterWindow._morphRect
                        ? (masterWindow.plateX + masterWindow.plateW / 2 - animContainer.width / 2) * (1.0 - masterWindow._morphT) * 0.55
                        : 0)
                y: (animContainer.height - height) / 2
                    + (masterWindow._morphRect
                        ? (masterWindow.plateY + masterWindow.plateH / 2 - animContainer.height / 2) * (1.0 - masterWindow._morphT) * 0.55
                        : 0)
                transformOrigin: Item.Center

                scale: 0.96 + 0.04 * masterWindow.contentReveal
                opacity: masterWindow.contentReveal

                MouseArea { anchors.fill: parent }

                StackView {
                    id: widgetStack
                    anchors.fill: parent
                    focus: true

                    replaceEnter: null
                    replaceExit: null
                    pushEnter: null
                    pushExit: null
                    popEnter: null
                    popExit: null

                    Keys.onEscapePressed: (event) => {
                        switchWidget("hidden", "");
                        event.accepted = true;
                    }

                    onCurrentItemChanged: {
                        if (currentItem) currentItem.forceActiveFocus();
                    }
                }
            }
        }

        // drawn over the panel: the container's edge during the whole morph
        Rectangle {
            id: morphFrame
            x: masterWindow.plateX
            y: masterWindow.plateY
            width: masterWindow.plateW
            height: masterWindow.plateH
            radius: masterWindow.plateRadius
            color: "transparent"
            antialiasing: true
            border.width: masterWindow.frameWidth
            border.color: masterWindow.frameColor
            opacity: masterWindow.frameOpacity
            visible: masterWindow.morphMasking && masterWindow.frameWidth > 0 && opacity > 0
        }

        Behavior on x {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
    }

    function switchWidget(newWidget, arg) {
        masterWindow.switchGeneration++;
        let gen = masterWindow.switchGeneration;
        masterWindow.targetActive = newWidget;

        if (newWidget !== "guide") {
            masterWindow.userMoved = false;
        }

        if (delayedClear.running) {
            delayedClear.stop();
        }

        if (newWidget === "hidden") {
            masterWindow.cancelPrewarm();

            if (currentActive !== "hidden") {
                let closingWidget = masterWindow.currentActive;
                let origin = masterWindow._morphOriginFor(closingWidget) || masterWindow.morphOrigin;

                masterWindow.currentActive = "hidden";
                masterWindow.morphDuration = masterWindow.exitDuration;
                masterWindow.disableMorph = true;

                // must come first: it raises morphClosing, which is what keeps
                // the window mapped once isVisible drops
                masterWindow.startCloseAnimation(origin);
                masterWindow.isVisible = false;

                delayedClear.scheduledGeneration = gen;
                delayedClear.restart();
            }
        } else {
            let targetScreen = resolveTargetScreen();
            if (targetScreen && masterWindow.screen !== targetScreen) {
                masterWindow.screen = targetScreen;
            }
            executeSwitch(newWidget, arg, gen);
        }
    }

    function executeSwitch(newWidget, arg, gen) {
        if (gen !== masterWindow.switchGeneration || newWidget === "hidden") return;

        let targetScreen = resolveTargetScreen();
        if (targetScreen && masterWindow.screen !== targetScreen) {
            masterWindow.screen = targetScreen;
        }

        let t = getLayout(newWidget);
        if (!t || !t.w || !t.h || t.w < 10 || t.h < 10) {
            Qt.callLater(function() {
                if (gen === masterWindow.switchGeneration) {
                    executeSwitch(newWidget, arg, gen);
                }
            });
            return;
        }

        let cachedItem = ensureWidgetItem(newWidget, t);
        if (!cachedItem) {
            Qt.callLater(function() {
                if (gen === masterWindow.switchGeneration) {
                    executeSwitch(newWidget, arg, gen);
                }
            });
            return;
        }

        if (gen !== masterWindow.switchGeneration) return;

        if (cachedItem.targetMasterWidth !== undefined)  cachedItem.targetMasterWidth  = t.w;
        if (cachedItem.targetMasterHeight !== undefined) cachedItem.targetMasterHeight = t.h;

        let isComingFromHidden = (!masterWindow.isVisible || widgetStack.currentItem === null || masterWindow.currentActive === "hidden");

        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;

        let finalW = (typeof cachedItem.targetMasterWidth === "number" && cachedItem.targetMasterWidth >= 50) ? cachedItem.targetMasterWidth : t.w;
        let finalH = (typeof cachedItem.targetMasterHeight === "number" && cachedItem.targetMasterHeight >= 50) ? cachedItem.targetMasterHeight : t.h;
        let finalX = (finalW !== t.w) ? recenterX(t, finalW) : t.rx;
        let finalY = t.ry;

        if (!masterWindow.userMoved || !masterWindow.isCurrentDraggable) {
            masterWindow._animX = finalX;
            masterWindow._animY = finalY;
        }
        masterWindow._animW = finalW;
        masterWindow._animH = finalH;
        masterWindow._stageW = finalW;
        masterWindow._stageH = finalH;

        if (isComingFromHidden) {
            masterWindow.disableMorph = true;
        } else {
            masterWindow.morphDuration = masterWindow.morphDurationSwitch;
            masterWindow.disableMorph = false;
        }

        if (newWidget === "wallpaper" && cachedItem.widgetArg !== undefined) cachedItem.widgetArg = arg;
        if (newWidget === "wallpaper" && cachedItem.refreshForDisplay !== undefined) cachedItem.refreshForDisplay();
        if (arg !== "" && cachedItem.activeMode !== undefined) cachedItem.activeMode = arg;
        if (arg !== "" && cachedItem.gotoTab !== undefined) cachedItem.gotoTab(arg);

        let openOrigin = isComingFromHidden ? masterWindow._morphOriginFor(newWidget) : null;
        if (isComingFromHidden && cachedItem.morphIntro !== undefined) {
            cachedItem.morphIntro = (openOrigin !== null);
        }

        if (widgetStack.currentItem !== cachedItem) {
            widgetStack.replace(cachedItem, {}, StackView.Immediate);
        }

        masterWindow.isVisible = true;
        prewarmTimeout.stop();
        masterWindow.prewarming = false;

        if (isComingFromHidden) {
            masterWindow.startOpenAnimation(openOrigin);
            // the stack keeps the item alive between opens, so the widget's own
            // intro has to be asked for explicitly
            if (typeof cachedItem.replayIntro === "function") cachedItem.replayIntro();
        }

        if (isComingFromHidden) {
            Qt.callLater(function() {
                if (gen === masterWindow.switchGeneration && masterWindow.isVisible && masterWindow.currentActive === newWidget) {
                    masterWindow.disableMorph = false;
                }
            });
        }
    }

    Timer {
        id: delayedClear
        interval: 200
        property int scheduledGeneration: -1
        onTriggered: {
            if (masterWindow.currentActive === "hidden" && scheduledGeneration === masterWindow.switchGeneration) {
                masterWindow.disableMorph = true;
            }
        }
    }
}
