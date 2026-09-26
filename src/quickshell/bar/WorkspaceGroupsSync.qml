import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../"

Item {
    id: workspaceGroupsSyncRoot

    // With per-monitor groups every monitor owns a block of workspaces, but
    // Hyprland knows nothing about that: at startup (and when a screen is
    // plugged in) it gives each monitor the first free workspace. On two
    // screens that is 1 and 2 - and 2 belongs to the first monitor's block. The
    // second bar then has nothing to light up, and switching to workspace 2 on
    // the first monitor jumps to the other screen instead, until something
    // moves the second monitor into its own block by hand.
    //
    // So once the monitors are known, every monitor showing a workspace outside
    // its block is moved to the first workspace of that block. Only at startup,
    // when the screens change and when the setting is turned on - never on a
    // regular workspace switch, which is the user's to make.

    readonly property bool workspaceGroupsPerMonitor: {
        let s = (typeof Config !== "undefined") ? Config.rawSettings : null;
        return !!(s && s.bar && s.bar.workspaceGroupsPerMonitor === true);
    }

    // Same lookup and clamp as the workspace widgets' groupSize, so the block
    // this picks is the one the bars and the keybinds use.
    readonly property int groupSize: {
        let s = (typeof Config !== "undefined") ? Config.rawSettings : null;
        if (s) {
            if (s.bar && s.bar.workspaceCount !== undefined) return Math.max(2, Math.min(10, s.bar.workspaceCount));
            if (s.general && s.general.workspaceCount !== undefined) return Math.max(2, Math.min(10, s.general.workspaceCount));
            if (s.workspaceCount !== undefined) return Math.max(2, Math.min(10, s.workspaceCount));
        }
        return 8;
    }

    property bool isHyprland: false

    Component.onCompleted: {
        let de = SystemInfo.desktopEnv ? SystemInfo.desktopEnv.toLowerCase() : "";
        workspaceGroupsSyncRoot.isHyprland = de.indexOf("hyprland") !== -1;
        syncTimer.restart();
    }

    onWorkspaceGroupsPerMonitorChanged: syncTimer.restart()
    onGroupSizeChanged: syncTimer.restart()

    Connections {
        target: Quickshell
        function onScreensChanged() { syncTimer.restart(); }
    }

    // Debounced, and long enough for a freshly added monitor to get its first
    // workspace - otherwise there is nothing to correct yet.
    Timer {
        id: syncTimer
        interval: 1500
        repeat: false
        onTriggered: workspaceGroupsSyncRoot.sync()
    }

    function sync() {
        if (!workspaceGroupsPerMonitor || !isHyprland) return;

        // Ordered the way the widgets order them: left to right, y breaking ties.
        let names = Quickshell.screens.map(sc => sc)
            .sort((a, b) => (a.x - b.x) || (a.y - b.y))
            .map(sc => JSON.stringify(String(sc.name)));
        if (names.length === 0) return;

        // The check itself runs inside Hyprland, as one dispatch. The shell's own
        // view of the monitors follows events and can lag behind - right after a
        // reload it may still show a monitor on the workspace it just left - and
        // one dispatch also keeps the monitor focus and the workspace switch in
        // order. Focus goes back to the monitor that had it.
        //  - special and named workspaces (id below 1) are not ours to move
        //  - if the group's first workspace already lives on another monitor,
        //    focusing it would pull that screen along, so that monitor is skipped
        Hyprland.dispatch("function() "
            + "local names = { " + names.join(", ") + " }; "
            + "local size = " + groupSize + "; "
            + "local prev = hl.get_active_monitor(); "
            + "local moved = false; "
            + "for i, name in ipairs(names) do "
            +   "local m = hl.get_monitor(name); "
            +   "local ws = m and m.active_workspace; "
            +   "local first = (i - 1) * size + 1; "
            +   "if ws and ws.id >= 1 and (ws.id < first or ws.id >= first + size) then "
            +     "local other = hl.get_workspace(first); "
            +     "if not (other and other.monitor and other.monitor.name ~= name) then "
            +       "hl.dispatch(hl.dsp.focus({ monitor = name })); "
            +       "hl.dispatch(hl.dsp.focus({ workspace = tostring(first) })); "
            +       "moved = true; "
            +     "end "
            +   "end "
            + "end "
            + "if moved and prev then hl.dispatch(hl.dsp.focus({ monitor = prev.name })) end "
            + "end");
    }
}
