import QtQuick 2.15
import QtQuick.Window 2.15
import "Shared.js" as Shared

// Plasma 5 wallpaper: the aquarium (Tank.qml) with up to eight fish, one per slot: CPU, Memory,
// GPU 1-2, Disk 1-2, Network 1-2. Each slot's fish (CpuFish.qml …) brings its own readings and is
// loaded only while the slot is switched on, so an unused slot costs nothing.
Item {
    id: root
    // Read once and kept, as in the widget hosts.
    property var cfg: wallpaper.configuration

    // One tank across all screens (Shared.js): the first copy leads, with the real fish, and the
    // copies on other screens show mirrors of them. All screens share one set of settings.
    property var entry: null
    property bool leading: false                // set once registered, so a follower never loads real fish
    property bool anyShown: !cover.covered      // the tank stops only when every screen is covered
    property var sources: []                    // a follower's: the leader's fish, one mirror each
    property point view: Qt.point(0, 0)         // this window's place on the desktop
    property rect world: Qt.rect(view.x, view.y, width, height)

    // called by Shared.js whenever a copy comes, goes, moves or is covered, or the fish change
    function refreshWorld() {
        if (!entry) return;
        leading = Shared.isLeader(entry);
        var w = Shared.world();
        world = w ? Qt.rect(w.x, w.y, w.width, w.height) : Qt.rect(view.x, view.y, width, height);
        anyShown = Shared.anyShown();
        var f = leading ? [] : Shared.fishes();
        if (!Shared.sameList(f, sources)) sources = f;
    }
    function follow(dt, time) { tank.follow(dt, time); }
    // `Screen` names the first screen in every copy, so the window's own position says where it is
    readonly property var placement: [Window.window ? Window.window.x : 0, Window.window ? Window.window.y : 0, width, height]
    onPlacementChanged: report()
    function report() {
        if (!entry) return;
        var p = root.mapToGlobal(0, 0);
        view = Qt.point(p.x, p.y);
        Shared.update(entry, Qt.rect(p.x, p.y, width, height), cover.covered);
    }
    Component.onCompleted: {
        cfg = cfg;
        entry = Shared.register(root, cfg);
        report();
    }
    Component.onDestruction: if (entry) Shared.unregister(entry)
    Connections {
        target: root.cfg
        function onValueChanged(key, value) { if (root.entry) Shared.shareSetting(root.entry, key, value); }
    }

    // Under maximised windows on every screen the tank stops (no frames at all) and readings slow
    // to one every 10 s, so a fish in trouble is still in trouble when it's uncovered.
    CoverWatch {
        id: cover
        area: Qt.rect(root.view.x, root.view.y, root.width, root.height)
        onCoveredChanged: root.report()
    }
    readonly property int interval: (root.anyShown ? Math.max(1, root.cfg.refreshSeconds) : 10) * 1000

    // the desktop's own GPU use, shown under the GPU fish's tags; only measured while shown
    DesktopGpuUse {
        id: desktopGpu
        active: root.leading && root.anyShown && root.cfg.showDesktopGpu && (root.cfg.gpu1On || root.cfg.gpu2On)
    }

    Component { id: cpuFish; CpuFish { cfg: root.cfg; interval: root.interval } }
    Component { id: memoryFish; MemoryFish { cfg: root.cfg; interval: root.interval } }
    Component { id: gpu1Fish; GpuFish { cfg: root.cfg; slot: "gpu1"; interval: root.interval; desktopUse: desktopGpu } }
    Component { id: gpu2Fish; GpuFish { cfg: root.cfg; slot: "gpu2"; interval: root.interval; desktopUse: desktopGpu } }
    Component { id: disk1Fish; DiskFish { cfg: root.cfg; slot: "disk1"; interval: root.interval } }
    Component { id: disk2Fish; DiskFish { cfg: root.cfg; slot: "disk2"; interval: root.interval } }
    Component { id: network1Fish; NetworkFish { cfg: root.cfg; slot: "network1"; interval: root.interval } }
    Component { id: network2Fish; NetworkFish { cfg: root.cfg; slot: "network2"; interval: root.interval } }

    Tank {
        id: tank
        anchors.fill: parent
        leading: root.leading
        running: root.anyShown
        fps: root.cfg.fps
        waterSpeed: root.cfg.waterSpeed / 100
        worldX: root.world.x
        worldY: root.world.y
        worldWidth: root.world.width
        worldHeight: root.world.height
        viewX: root.view.x
        viewY: root.view.y
        onFrame: {
            Shared.publish(root.entry, tank.fishes(true));
            Shared.followFrame(root.entry, dt, time);
        }

        // a Loader's z follows its fish's depth, so nearer fish are drawn over farther ones
        Loader { active: root.leading && root.cfg.cpuOn; sourceComponent: cpuFish; z: item ? item.z : 0 }
        Loader { active: root.leading && root.cfg.memoryOn; sourceComponent: memoryFish; z: item ? item.z : 0 }
        Loader { active: root.leading && root.cfg.gpu1On; sourceComponent: gpu1Fish; z: item ? item.z : 0 }
        Loader { active: root.leading && root.cfg.gpu2On; sourceComponent: gpu2Fish; z: item ? item.z : 0 }
        Loader { active: root.leading && root.cfg.disk1On; sourceComponent: disk1Fish; z: item ? item.z : 0 }
        Loader { active: root.leading && root.cfg.disk2On; sourceComponent: disk2Fish; z: item ? item.z : 0 }
        Loader { active: root.leading && root.cfg.network1On; sourceComponent: network1Fish; z: item ? item.z : 0 }
        Loader { active: root.leading && root.cfg.network2On; sourceComponent: network2Fish; z: item ? item.z : 0 }
        // on the other screens
        Repeater {
            model: root.sources
            Mirror { source: modelData }
        }
    }
}
