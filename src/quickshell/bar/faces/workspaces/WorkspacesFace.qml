import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../../reusables"
import "../../../"
import "../../"

Item {
    id: root

    property var module: null
    property var widget: root

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool moduleActive: module ? module.moduleActive : true

    property bool isNiri: false
    property bool isSway: false
    property int niriActiveIndex: 0
    property var niriOccupiedMap: ({})
    property var niriExistingMap: ({})
    property int niriMaxWorkspaceIndex: 0
    property var lastNiriWorkspaces: []
    property var lastNiriWindows: []
    property int swayActiveIndex: 0
    property var swayOccupiedMap: ({})

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property string workspacesStyle: {
        let dummy = configRevision;
        if (module && module.variant) return module.variant;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.workspacesStyle) return Config.rawSettings.bar.workspacesStyle;
            if (Config.rawSettings.bar.workspaces && Config.rawSettings.bar.workspaces.style) return Config.rawSettings.bar.workspaces.style;
        }
        return "pills";
    }

    property int baseWorkspaceCount: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            if (Config.rawSettings.bar && Config.rawSettings.bar.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.bar.workspaceCount));
            }
            if (Config.rawSettings.general && Config.rawSettings.general.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.general.workspaceCount));
            }
            if (Config.rawSettings.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.workspaceCount));
            }
        }
        return 8;
    }

    // The block size, shared by every bar and by qs_manager.sh. Deliberately not
    // baseWorkspaceCount: that one is per-bar and purely visual (the side bar has
    // its own sideWorkspaceCount), so using it as the stride would let a vertical
    // bar address a different block than the keybinds and the horizontal bar.
    readonly property int groupSize: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            if (Config.rawSettings.bar && Config.rawSettings.bar.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.bar.workspaceCount));
            }
            if (Config.rawSettings.general && Config.rawSettings.general.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.general.workspaceCount));
            }
            if (Config.rawSettings.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.workspaceCount));
            }
        }
        return 8;
    }

    // Workspaces split into one block of baseWorkspaceCount per monitor (1-N,
    // N+1-2N, ...). Without this, a bar on the second monitor never lights up and
    // switching on the primary makes both bars look like they moved.
    property bool workspaceGroupsPerMonitor: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar)
            ? (Config.rawSettings.bar.workspaceGroupsPerMonitor === true) : false;
    }

    // The stride is the configured count, not the grown one: workspaceCount can
    // expand past it to show an out-of-range workspace, and a moving stride would
    // shift every other monitor's block along with it.
    readonly property int groupOffset: {
        if (!workspaceGroupsPerMonitor) return 0;
        // Hyprland only: the niri and sway paths track their own active index and
        // dispatch plain numbers, so an offset would desync the pills from focus.
        if (isNiri || isSway) return 0;
        if (!barWindow || !barWindow.screen) return 0;
        // Ordered left to right, y breaking ties so stacked screens keep a stable
        // order. Matched by name rather than by x, because two screens can sit at
        // the same coordinate and would otherwise both claim the first group.
        let ordered = Quickshell.screens.map(sc => sc).sort((a, b) => (a.x - b.x) || (a.y - b.y));
        let i = ordered.findIndex(sc => sc.name === barWindow.screen.name);
        return (i < 0 ? 0 : i) * groupSize;
    }

    // Index inside this bar's own group, or -1 when another monitor is focused.
    readonly property int hlLocalIndex: {
        const fw = Hyprland.focusedWorkspace;
        if (!fw) return -1;
        const l = fw.id - groupOffset - 1;
        return (l >= 0 && l < groupSize) ? l : -1;
    }
    // When focus is on the other screen we keep the last local one, so an unfocused
    // monitor's bar still shows where that monitor stands instead of going blank.
    property int lastLocalIndex: -1
    onHlLocalIndexChanged: if (hlLocalIndex >= 0) lastLocalIndex = hlLocalIndex;

    // Growth is capped at the group with per-monitor groups on: a workspace past
    // it belongs to another monitor, so growing further would render that
    // monitor's ids here. Inside the group it still grows, which is what lets a
    // bar display fewer workspaces than the block actually spans.
    property int workspaceCount: {
        let base = baseWorkspaceCount;
        let act = activeIndex;
        let count = base;
        if (act >= count) count = act + 1;
        if (isNiri && niriMaxWorkspaceIndex >= count) count = niriMaxWorkspaceIndex + 1;
        if (workspaceGroupsPerMonitor) count = Math.min(count, groupSize);
        return Math.max(2, count);
    }

    property bool hideEmptyWorkspaces: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.hideEmptyWorkspaces !== undefined)
                return Boolean(Config.rawSettings.bar.hideEmptyWorkspaces);
        }
        return false;
    }

    ListModel {
        id: workspaceListModel
    }

    function syncModel() {
        let target = workspaceCount;
        while (workspaceListModel.count < target) {
            workspaceListModel.append({ "modelData": workspaceListModel.count });
        }
        while (workspaceListModel.count > target) {
            workspaceListModel.remove(workspaceListModel.count - 1);
        }
    }

    onWorkspaceCountChanged: syncModel()

    function findRepeater(obj) {
        if (!obj) return null;
        if (obj.model !== undefined && obj.count !== undefined && typeof obj.itemAt === "function") {
            return obj;
        }
        if (obj.children) {
            for (let i = 0; i < obj.children.length; i++) {
                let res = findRepeater(obj.children[i]);
                if (res) return res;
            }
        }
        if (obj.data) {
            for (let j = 0; j < obj.data.length; j++) {
                let res = findRepeater(obj.data[j]);
                if (res) return res;
            }
        }
        return null;
    }

    function attachModel() {
        if (faceLoader.item) {
            faceLoader.item.widget = root;
            let rep = findRepeater(faceLoader.item);
            if (rep && rep.model !== workspaceListModel) {
                rep.model = workspaceListModel;
            }
        }
    }

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    function wsForId(id) {
        if (isNiri || isSway) return null;
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function isOccupied(index) {
        if (isNiri) return !!(niriExistingMap[index] && niriOccupiedMap[index]);
        if (isSway) return !!swayOccupiedMap[index];
        let ws = wsForId(index + 1 + groupOffset);
        return ws !== null && ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0;
    }

    function isShown(index) {
        if (!hideEmptyWorkspaces) return true;
        return index === activeIndex || isOccupied(index);
    }

    function focusWorkspace(index) {
        let wsId = index + 1;
        if (isNiri) {
            if (niriExistingMap[index] || Object.keys(niriExistingMap).length === 0) {
                niriActiveIndex = index;
            }
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", wsId.toString()]);
        } else if (isSway) {
            swayActiveIndex = index;
            Quickshell.execDetached(["swaymsg", "workspace", "number", wsId.toString()]);
        } else {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + (wsId + groupOffset) + " })");
        }
    }

    property int activeIndex: {
        let idx = -1;
        if (isNiri) {
            idx = (niriExistingMap[niriActiveIndex] || Object.keys(niriExistingMap).length === 0) ? niriActiveIndex : -1;
        } else if (isSway) {
            idx = swayActiveIndex;
        } else {
            // Sticky only makes sense with per-monitor groups; without them the
            // index stays absolute so the list can grow past the configured count.
            if (workspaceGroupsPerMonitor) return lastLocalIndex;
            const fw = Hyprland.focusedWorkspace;
            if (!fw) return -1;
            idx = fw.id - 1;
        }
        return idx >= 0 ? idx : -1;
    }

    function processNiriData(wsList, winList) {
        if (!Array.isArray(wsList)) wsList = [];
        if (!Array.isArray(winList)) winList = [];

        let wsIdsWithWindows = {};
        for (let i = 0; i < winList.length; i++) {
            let win = winList[i];
            if (win && win.workspace_id !== undefined && win.workspace_id !== null) {
                wsIdsWithWindows[win.workspace_id] = true;
            }
        }

        let occ = {};
        let existing = {};
        let maxIdx = 0;
        for (let j = 0; j < wsList.length; j++) {
            let w = wsList[j];
            if (!w) continue;
            let idx = (w.idx !== undefined ? w.idx : 1) - 1;
            if (idx >= 0) {
                existing[idx] = true;
                if (idx > maxIdx) maxIdx = idx;
                if ((w.active_window_id !== null && w.active_window_id !== undefined) || wsIdsWithWindows[w.id]) {
                    occ[idx] = true;
                }
            }
        }

        let myOutput = (barWindow && barWindow.screen && barWindow.screen.name) ? barWindow.screen.name : "";
        let activeIdx = -1;

        if (myOutput) {
            for (let j = 0; j < wsList.length; j++) {
                let w = wsList[j];
                if (w && w.output === myOutput && w.is_focused) {
                    activeIdx = (w.idx !== undefined ? w.idx : 1) - 1;
                    break;
                }
            }
            if (activeIdx < 0) {
                for (let j = 0; j < wsList.length; j++) {
                    let w = wsList[j];
                    if (w && w.output === myOutput && w.is_active) {
                        activeIdx = (w.idx !== undefined ? w.idx : 1) - 1;
                        break;
                    }
                }
            }
        }

        if (activeIdx < 0) {
            for (let j = 0; j < wsList.length; j++) {
                let w = wsList[j];
                if (w && w.is_focused) {
                    activeIdx = (w.idx !== undefined ? w.idx : 1) - 1;
                    break;
                }
            }
        }

        if (activeIdx < 0) {
            for (let j = 0; j < wsList.length; j++) {
                let w = wsList[j];
                if (w && w.is_active) {
                    activeIdx = (w.idx !== undefined ? w.idx : 1) - 1;
                    break;
                }
            }
        }

        if (activeIdx < 0 && wsList.length > 0) {
            activeIdx = (wsList[0].idx !== undefined ? wsList[0].idx : 1) - 1;
        }

        root.niriMaxWorkspaceIndex = maxIdx;
        root.niriExistingMap = existing;
        root.niriOccupiedMap = occ;
        if (activeIdx >= 0) {
            root.niriActiveIndex = activeIdx;
        }
    }

    function handleNiriEvent(rawJson) {
        try {
            let ev = JSON.parse(rawJson);
            if (ev.WorkspacesChanged && ev.WorkspacesChanged.workspaces) {
                lastNiriWorkspaces = ev.WorkspacesChanged.workspaces;
                processNiriData(lastNiriWorkspaces, lastNiriWindows);
            } else if (ev.WindowsChanged && ev.WindowsChanged.windows) {
                lastNiriWindows = ev.WindowsChanged.windows;
                processNiriData(lastNiriWorkspaces, lastNiriWindows);
            } else if (ev.WorkspaceActivated) {
                let actId = ev.WorkspaceActivated.id;
                let isFoc = ev.WorkspaceActivated.focused !== false;
                for (let i = 0; i < lastNiriWorkspaces.length; i++) {
                    let w = lastNiriWorkspaces[i];
                    if (w.id === actId) {
                        w.is_active = true;
                        if (isFoc) w.is_focused = true;
                    } else if (w.output === ev.WorkspaceActivated.output) {
                        w.is_active = false;
                        w.is_focused = false;
                    }
                }
                processNiriData(lastNiriWorkspaces, lastNiriWindows);
            } else if (ev.WindowOpenedOrChanged || ev.WindowClosed || ev.WindowFocusChanged) {
                niriDebounceTimer.restart();
            }
        } catch (e) {
            niriDebounceTimer.restart();
        }
    }

    Component.onCompleted: {
        let de = SystemInfo.desktopEnv ? SystemInfo.desktopEnv.toLowerCase() : "";
        root.isNiri = de.indexOf("niri") !== -1;
        root.isSway = de.indexOf("sway") !== -1;
        if (root.isNiri && root.moduleActive) {
            niriPoller.running = true;
            niriEventStream.running = true;
        }
        if (root.isSway && root.moduleActive) {
            swayPoller.running = true;
        }
        syncModel();
    }

    onModuleActiveChanged: {
        if (!moduleActive) {
            if (isNiri) {
                niriPoller.running = false;
                niriDebounceTimer.stop();
                niriRestartTimer.stop();
                niriEventStream.running = false;
            }
            if (isSway) {
                swayPoller.running = false;
                swayWaiter.running = false;
            }
        } else {
            if (isNiri) {
                niriPoller.running = false;
                niriPoller.running = true;
                niriEventStream.running = false;
                niriEventStream.running = true;
            }
            if (isSway) {
                swayPoller.running = false;
                swayPoller.running = true;
            }
        }
    }

    Timer {
        id: niriDebounceTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root.moduleActive && root.isNiri) {
                if (!niriPoller.running) {
                    niriPoller.running = true;
                }
            }
        }
    }

    Timer {
        id: niriRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.moduleActive && root.isNiri) {
                niriEventStream.running = false;
                niriEventStream.running = true;
            }
        }
    }

    Process {
        id: niriEventStream
        running: false
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let trimmed = data.trim();
                if (trimmed.length > 0) {
                    root.handleNiriEvent(trimmed);
                }
            }
        }
        onExited: {
            if (root.moduleActive && root.isNiri) {
                niriRestartTimer.restart();
            }
        }
    }

    Process {
        id: niriPoller
        running: false
        command: [
            "bash",
            "-c",
            "workspaces=$(niri msg -j workspaces 2>/dev/null || echo '[]'); windows=$(niri msg -j windows 2>/dev/null || echo '[]'); echo \"{\\\"workspaces\\\": $workspaces, \\\"windows\\\": $windows}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    root.lastNiriWorkspaces = data.workspaces || [];
                    root.lastNiriWindows = data.windows || [];
                    root.processNiriData(root.lastNiriWorkspaces, root.lastNiriWindows);
                } catch (e) {}
            }
        }
        onExited: {
            if (root.moduleActive && root.isNiri && niriDebounceTimer.running) {
                niriPoller.running = true;
            }
        }
    }

    Process {
        id: swayPoller
        running: false
        command: [
            "bash",
            "-c",
            "swaymsg -t get_workspaces -r 2>/dev/null || echo '[]'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let wsList = JSON.parse(this.text) || [];
                    let occ = {};
                    let activeIdx = 0;
                    for (let i = 0; i < wsList.length; i++) {
                        let w = wsList[i];
                        let num = (w.num !== undefined && w.num > 0) ? w.num : parseInt(w.name);
                        let idx = (!isNaN(num) && num > 0) ? num - 1 : i;
                        if (w.focused) {
                            activeIdx = idx;
                        }
                        occ[idx] = true;
                    }
                    root.swayActiveIndex = activeIdx;
                    root.swayOccupiedMap = occ;
                } catch (e) {}

                swayWaiter.running = false;
                if (root.moduleActive && root.isSway) {
                    swayWaiter.running = true;
                }
            }
        }
    }

    Process {
        id: swayWaiter
        running: false
        command: [
            "bash",
            "-c",
            "swaymsg -t subscribe -m '[\"workspace\", \"window\"]' 2>/dev/null | grep -m 1 -E '\"change\"'"
        ]
        onExited: {
            swayPoller.running = false;
            if (root.moduleActive && root.isSway) {
                swayPoller.running = true;
            }
        }
    }

    property real targetWidth: (moduleActive && workspaceCount > 0 && faceLoader.item) ? faceLoader.item.implicitWidth + s(isCompact ? 18 : 22) : 0
    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    property real wheelAccumulator: 0
    Timer {
        id: wsWheelTimer
        interval: 200
        onTriggered: root.wheelAccumulator = 0
    }

    MouseArea {
        id: wsScrollArea
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => {
            wsWheelTimer.restart();
            root.wheelAccumulator += wheel.angleDelta.y;
            const threshold = 120;
            if (Math.abs(root.wheelAccumulator) >= threshold) {
                let steps = Math.trunc(root.wheelAccumulator / threshold);
                root.wheelAccumulator = root.wheelAccumulator % threshold;

                if (root.workspaceCount > 1) {
                    if (root.isNiri) {
                        if (steps > 0) {
                            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-up"]);
                        } else if (steps < 0) {
                            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-down"]);
                        }
                    } else {
                        let cur = root.activeIndex;
                        let nextIndex = 0;
                        if (cur < 0) {
                            nextIndex = steps > 0 ? (root.workspaceCount - 1) : 0;
                        } else {
                            if (steps > 0) {
                                nextIndex = (cur - 1 + root.workspaceCount) % root.workspaceCount;
                            } else if (steps < 0) {
                                nextIndex = (cur + 1) % root.workspaceCount;
                            }
                        }
                        if (nextIndex !== root.activeIndex) {
                            root.focusWorkspace(nextIndex);
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: faceLoader
        z: 2
        anchors.left: parent.left
        anchors.leftMargin: s(isCompact ? 18 : 22) / 2
        anchors.verticalCenter: parent.verticalCenter
        source: BarModuleRegistry.variantFaceFile("workspaces", root.workspacesStyle, false)
        onLoaded: {
            attachModel();
            Qt.callLater(attachModel);
        }
    }

    Binding {
        target: faceLoader.item
        property: "widget"
        value: root
    }
}
