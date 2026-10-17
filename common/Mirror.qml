import QtQuick 2.15

// A copy of another Swimmer, for a tank that spans several windows (one per screen): the fish
// lives, reads its sensors and moves in one window, and every other window shows a Mirror of it.
// The tank calls sync(dt) after each of the real fish's frames; the Mirror copies where the fish
// is, its inputs, its tail and eye, and its eased colours, so a fish half on each screen matches.
// Only food and bubbles run on their own (same rates, different flakes).
Swimmer {
    id: mirror
    property var source: null

    fish.mirrored: true

    readonly property var copied: ["stripes", "fill", "secondaryFill", "activity", "heat", "speed",
        "distress", "intake", "outflow", "asleep", "split", "beat", "drift", "blink", "lidDrop",
        "shownRings", "shownHeat", "shownSpeed", "shownCollar", "shownSplit"]
    function sync(dt) {
        var s = source;
        if (!s || !s.fish) return;
        kind = s.kind;
        caption = s.caption;
        note = s.note;
        showCaption = s.showCaption;
        bodyWidth = s.bodyWidth;
        depth = s.depth;
        px = s.px;
        py = s.py;
        facing = s.facing;
        flip = s.flip;
        tilt = s.tilt;
        var a = s.fish, b = mirror.fish;
        for (var i = 0; i < copied.length; i++) {
            var n = copied[i];
            if (b[n] !== a[n]) b[n] = a[n];
        }
        if (String(b.foodColor) !== String(a.foodColor)) b.foodColor = a.foodColor;
        b.advance(dt);
    }
    Component.onCompleted: sync(0)
}
