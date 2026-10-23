import QtQuick 2.15
import QtQuick.Window 2.15
import org.kde.taskmanager 0.1 as TaskManager
import org.kde.kwindowsystem 1.0

// Is this item's screen covered by a maximised or fullscreen window? A wallpaper keeps drawing
// under such a window (measured 2026-10-17: no slowdown at all), so the host pauses instead.
//
// Covered = a window on the current virtual desktop and activity, not minimised, maximised or
// fullscreen, whose centre is on this screen. Not covered while the desktop itself has focus
// (clicked) or Show Desktop is on, since then the wallpaper is what you're looking at.
// Translucent windows count as covering: the fish would show through them, but only faintly.
// Plasma 6 version of providers/CoverWatch.qml: Show Desktop is read from KWindowSystem, since
// Plasma 6 dropped the Show Desktop applet's QML module (it's compiled into the applet now).
Item {
    id: watch

    readonly property alias covered: watch.isCovered
    property bool isCovered: false
    // The screen, on the desktop. Inside a wallpaper `Screen` names the first screen for every
    // copy (2026-10-17), so a host on several screens passes its window's place; empty = Screen.
    property rect area: Qt.rect(0, 0, 0, 0)
    onAreaChanged: check.restart()

    // the desktop window has focus: it was clicked, so it's on show whatever is maximised
    readonly property bool desktopFocused: Window.active
    onDesktopFocusedChanged: check.restart()

    Connections {
        target: KWindowSystem
        function onShowingDesktopChanged() { check.restart(); }
    }
    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        virtualDesktop: desktops.currentDesktop
        activity: activities.currentActivity
        filterByVirtualDesktop: true
        filterByActivity: true
        filterMinimized: true
        onDataChanged: check.restart()
        onCountChanged: check.restart()
        onModelReset: check.restart()
    }

    function onThisScreen(g) {
        var cx = g.x + g.width / 2, cy = g.y + g.height / 2;
        var a = watch.area.width > 0 ? watch.area
                : Qt.rect(watch.Screen.virtualX, watch.Screen.virtualY, watch.Screen.width, watch.Screen.height);
        return cx >= a.x && cx < a.x + a.width && cy >= a.y && cy < a.y + a.height;
    }

    // window changes come in bursts (a maximise is several updates); look once they settle
    Timer {
        id: check
        interval: 150
        onTriggered: {
            if (KWindowSystem.showingDesktop || watch.desktopFocused) {
                watch.isCovered = false;
                return;
            }
            var found = false;
            for (var i = 0; i < tasks.count && !found; i++) {
                var idx = tasks.makeModelIndex(i);
                if (!tasks.data(idx, TaskManager.AbstractTasksModel.IsMaximized)
                        && !tasks.data(idx, TaskManager.AbstractTasksModel.IsFullScreen)) continue;
                found = watch.onThisScreen(tasks.data(idx, TaskManager.AbstractTasksModel.Geometry));
            }
            watch.isCovered = found;
        }
    }
    Component.onCompleted: check.start()
}
