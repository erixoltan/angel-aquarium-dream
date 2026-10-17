import QtQuick 2.15

// An aquarium: the water, the sand, and the Swimmers placed inside it. Pure QtQuick. One clock
// drives everything: it advances the water's light and moves every fish, and the fish keep
// clear of each other. The fish run on it too (Angelfish.externalClock), so the whole tank
// redraws at `fps` and no more.
//
//   Tank { Swimmer { kind: "cpu"; fish.activity: … } Swimmer { … } }
//
// One tank can span several windows (a wallpaper on several screens): each window has a Tank that
// draws its slice (`view*` within `world*`, in desktop coordinates). One of them leads: its clock
// moves the real fish and it signals frame(dt, time); the others don't run a clock but are handed
// each frame through follow(dt, time), which syncs their Mirrors of the leader's fish.
Item {
    id: tank

    default property alias swimmers: school.data
    property bool running: true
    // Frames per second for everything in the tank. Each frame redraws the whole screen, and
    // X and KWin then copy it, so this is the main cost; nothing else in the tank adds frames.
    property int fps: 20
    property real waterSpeed: 0.4           // how fast the light patterns move (1 = lively)
    property real floorLevel: 0.9           // sand line, as a fraction of the height
    // fish size: a fraction of the tank's height, so the tank looks the same on any screen
    property real fishSize: 0.2
    // the whole tank and where this window is in it; alone, this window is the whole tank
    property real worldX: 0
    property real worldY: 0
    property real worldWidth: width
    property real worldHeight: height
    property real viewX: worldX
    property real viewY: worldY
    property bool leading: true
    signal frame(real dt, real time)
    readonly property real floorY: worldHeight * floorLevel

    Water {
        id: water
        anchors.fill: parent
        floorLevel: tank.floorLevel
        worldSize: Qt.size(tank.worldWidth, tank.worldHeight)
        offset: Qt.point(tank.viewX - tank.worldX, tank.viewY - tank.worldY)
    }

    Item {
        id: school
        x: tank.worldX - tank.viewX
        y: tank.worldY - tank.viewY
        width: tank.worldWidth
        height: tank.worldHeight
    }

    // The swimmers: direct children, or the item of a Loader (a host loads only the fish that are
    // switched on). Only visible ones unless `all`.
    function fishes(all) {
        var out = [];
        for (var i = 0; i < school.children.length; i++) {
            var c = school.children[i];
            if (typeof c.step !== "function") c = c.item;
            if (c && typeof c.step === "function" && (all || c.visible)) out.push(c);
        }
        return out;
    }

    // A fish is placed when it first appears: told about the tank, and put somewhere spread out
    // (by its order, so the first ones don't start on top of each other). Fish that appear later,
    // say when switched on in the settings, join without moving the others.
    function place(f, i, n) {
        f.tankWidth = Qt.binding(function () { return tank.worldWidth; });
        f.surface = 0;
        f.floor = Qt.binding(function () { return tank.floorY; });
        f.bodyWidth = Qt.binding(function () { return tank.worldHeight * tank.fishSize; });
        f.px = tank.worldWidth * (i + 0.5) / n;
        f.py = tank.floorY * (0.3 + 0.4 * ((i * 7) % 5) / 4);
        f.placed = true;
        f.pickTarget();
    }
    function placeNew() {
        var all = fishes(true);
        for (var i = 0; i < all.length; i++)
            if (!all[i].placed) place(all[i], i, all.length);
    }

    // Draw a fish only while some of it is in this window. The margin leaves room for bubbles,
    // which rise above the fish.
    function cull(f) {
        var x = f.x + school.x, y = f.y + school.y, m = f.height;
        f.onView = x + f.width > 0 && x < width && y + f.height + m > 0 && y - m < height;
    }
    // a follower: the leader has moved on by dt
    function follow(dt, time) {
        water.time = time;
        for (var i = 0; i < school.children.length; i++) {
            var c = school.children[i];
            if (typeof c.sync === "function") { c.sync(dt); cull(c); }
        }
    }

    Timer {
        id: clock
        property double last: 0
        interval: 1000 / Math.max(1, tank.fps)
        running: tank.leading && tank.running && tank.visible && tank.width > 0
        repeat: true
        onRunningChanged: last = 0
        onTriggered: {
            var now = Date.now(), dt = last > 0 ? Math.min(0.2, (now - last) / 1000) : 0;
            last = now;
            water.time += dt * tank.waterSpeed;
            tank.placeNew();
            var all = tank.fishes();
            for (var i = 0; i < all.length; i++) {
                var a = all[i], ax = 0, ay = 0;
                // Keep clear of fish at about the same depth; fish at other depths pass in front
                // or behind. Make way mostly up or down and by changing depth, not by being pushed
                // backwards (that turned fish round).
                for (var j = 0; j < all.length; j++) {
                    if (j === i) continue;
                    var b = all[j], dz = a.depth - b.depth;
                    var near = 1 - Math.abs(dz) / 0.2;
                    if (near <= 0) continue;
                    var dx = a.px - b.px, dy = a.py - b.py;
                    var reach = (a.size + b.size) * 0.45, d2 = dx * dx + dy * dy;
                    if (d2 < reach * reach && d2 > 0.01) {
                        var d = Math.sqrt(d2), push = (reach - d) / reach * a.size * 1.5 * near;
                        ax += dx / d * push * 0.25;
                        ay += (dy >= 0 ? 1 : -1) * push;
                        // the farther one moves back, the nearer one forward (ties: by order)
                        a.makeWay((dz > 0 || (dz === 0 && i > j) ? 1 : -1) * dt * 0.6 * near);
                    }
                }
                a.step(dt, ax, ay);
                tank.cull(a);
            }
            tank.frame(dt, water.time);
        }
    }
}
