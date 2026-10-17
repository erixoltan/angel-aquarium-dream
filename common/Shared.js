.pragma library
// One tank across every screen. Plasma 5 makes one copy of the wallpaper per screen, all in one
// QML engine (verified 2026-10-17), and a `.pragma library` module is loaded once per engine, so
// every copy sees the same variables here.
//
// The first copy still alive leads: it has the real fish, with their readings, and moves them in
// a tank the size of all the screens together. The others show mirrors of its fish, copied on
// every one of its frames. Each copy draws the slice of the tank that is its own screen. Copies
// hear about changes through their root's refreshWorld() and frames through follow(dt, time).
//
// Each copy also has its own settings, which are kept the same: a copy that joins takes the
// leader's, and a change on any screen's settings page is written into all the others.

var copies = [];        // { root, cfg, rect: {x, y, width, height} on the desktop, covered }
var fish = [];          // the leader's swimmers

function register(root, cfg) {
    var entry = { root: root, cfg: cfg, rect: null, covered: false };
    copies.push(entry);
    if (copies[0] !== entry && copies[0].cfg) {
        var from = copies[0].cfg, keys = from.keys();
        for (var i = 0; i < keys.length; i++) shareSetting(copies[0], keys[i], from[keys[i]]);
    }
    refreshAll();
    return entry;
}
function unregister(entry) {
    var i = copies.indexOf(entry);
    if (i < 0) return;
    copies.splice(i, 1);
    if (i === 0) fish = [];
    refreshAll();
}
// a copy's window moved or changed size, or its screen was covered or uncovered
function update(entry, rect, covered) {
    var r = entry.rect;
    if (r && r.x === rect.x && r.y === rect.y && r.width === rect.width && r.height === rect.height
            && entry.covered === covered) return;
    entry.rect = { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
    entry.covered = covered;
    refreshAll();
}
// a setting changed in one copy; writing it into the others makes them report it too, so equal
// values are skipped
function shareSetting(entry, key, value) {
    for (var i = 0; i < copies.length; i++) {
        var c = copies[i].cfg;
        if (copies[i] === entry || !c) continue;
        try { if (c[key] !== value) c[key] = value; } catch (e) { }
    }
}
function isLeader(entry) { return copies.length > 0 && copies[0] === entry; }

// the box around every screen, or null before any copy knows where it is
function world() {
    var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (var i = 0; i < copies.length; i++) {
        var r = copies[i].rect;
        if (!r || r.width <= 0 || r.height <= 0) continue;
        x0 = Math.min(x0, r.x); y0 = Math.min(y0, r.y);
        x1 = Math.max(x1, r.x + r.width); y1 = Math.max(y1, r.y + r.height);
    }
    return x0 === Infinity ? null : { x: x0, y: y0, width: x1 - x0, height: y1 - y0 };
}
// is any screen of the tank on show? Only when all are covered does the tank stop.
function anyShown() {
    for (var i = 0; i < copies.length; i++)
        if (!copies[i].covered) return true;
    return copies.length === 0;
}

function sameList(a, b) {
    if (a.length !== b.length) return false;
    for (var i = 0; i < a.length; i++)
        if (a[i] !== b[i]) return false;
    return true;
}
// the leader's fish, after each of its frames; the others hear only when the list changes
function publish(entry, list) {
    if (!isLeader(entry) || sameList(list, fish)) return;
    fish = list.slice();
    refreshAll();
}
function fishes() { return fish.slice(); }

// the leader has moved everything on by dt; the others copy it
function followFrame(entry, dt, time) {
    for (var i = 0; i < copies.length; i++) {
        if (copies[i] === entry) continue;
        try { copies[i].root.follow(dt, time); } catch (e) { }   // a copy being destroyed
    }
}
function refreshAll() {
    for (var i = 0; i < copies.length; i++) {
        try { copies[i].root.refreshWorld(); } catch (e) { }
    }
}
