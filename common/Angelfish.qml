import QtQuick 2.15
import QtQuick.Shapes 1.15
import "AngelfishArt.js" as Art
import "Palettes.js" as Palettes

// A hardware component as an angelfish in a striped sweater. Pure QtQuick: it knows nothing about
// Plasma or where its numbers come from. Every input is a plain 0..1 value, so a host maps real
// readings (and their limits) onto that range, and a preview can drive it with sliders.
//
//   stripes      how full or busy: one band per unit (CPU threads), or a gauge filling from
//                the collar towards the tail (GPU utilisation)
//   collar       a second gauge on collar, cuffs and sleeve (e.g. VRAM)
//   body colour  temperature: blue when cold, red when hot, neutral when there is no reading
//   lightness    clock frequency: dark when slow, light when fast
//   motion       activity: tail beat, bobbing, and how wide the eye is open
//   halo, wings  distress: the halo fades in as things get bad, the wings arrive when it's dire
//   food, bubbles  flow: flakes swim into the mouth (intake), bubbles rise from it (outflow)
//   split        filled bands nearest the collar in the food colour, the rest in the stripe
//                colour: how much of the flow is in rather than out
//   asleep       eyes shut, z's instead of bubbles, a dark body (e.g. a network fish when offline)
//   colours      kind: stripe colour and matching dark outlines say which component this is
Item {
    id: fish

    property string kind: "cpu"         // cpu, gpu, memory, disk, network, or a mood (Palettes.js)
    property var stripes: []            // per unit, each 0..1; empty = the bands are a gauge of `fill`
    property real fill: average(stripes)    // overall fullness, 0..1
    property real secondaryFill: -1     // collar gauge 0..1; -1 = follow `fill`
    property real activity: fill        // 0 = idle, 1 = flat out
    property real heat: 0.3             // 0 = cold, 1 = at the chip's limit; -1 = no temperature
    property real speed: 0.5            // clock frequency, 0 = slowest, 1 = fastest
    property real distress: 0           // 0 = fine, 1 = this will hurt the hardware or the system
    property bool sortStripes: true     // busiest unit nearest the head, whichever unit it is
    property real intake: -1            // flow in, 0..1: food flakes; -1 = this fish doesn't eat
    property real outflow: -1           // flow out, 0..1: bubbles; -1 = this fish doesn't blow any
    property bool asleep: false
    property real split: -1             // share of the filled bands in foodColor (flow in); -1 = none
    property color foodColor: "#dca024"
    property bool animate: true
    property int fps: 20            // motion frame rate; each frame is a full redraw
    // Every moving part, blinks and colour easing included, steps on one clock, so a fish adds
    // `fps` frames and no more. Its own clock ticks on the wall clock's beat (every 1000/fps ms,
    // on the boundary), so fish in different widgets on one desktop land in the same frames.
    // true: a host (Tank) calls advance(dt) on its clock instead, for fish that share a tank.
    property bool externalClock: false
    // true: a copy of a fish in another window (Mirror.qml), which sets its motion and eased
    // colours; advance(dt) then only moves its food and bubbles
    property bool mirrored: false
    // true while a host draws the fish flipped (facing right): text, the snoring z's, is flipped
    // back so it doesn't read mirrored
    property bool drawnFlipped: false

    readonly property var palette: Palettes.of(kind)
    property color sweaterColor: palette.base || "#f6f1e4"  // the sweater's base, on idle bands: cream, or a character's own
    property color stripeColor: palette.stripe      // busy bands
    property color inkColor: palette.ink            // outlines of body and tail

    function clamp(v) { return Math.max(0, Math.min(1, v)); }
    function average(a) {
        if (!a || a.length === 0) return 0;
        var sum = 0;
        for (var i = 0; i < a.length; i++) sum += a[i];
        return clamp(sum / a.length);
    }
    readonly property real collar: secondaryFill >= 0 ? clamp(secondaryFill) : 0.15 + 0.6 * clamp(fill)

    // Per-unit loads spread over the sweater's bands. With more units than bands a band shows the
    // average of a few neighbours; with fewer, a unit spans several bands. Without units the bands
    // fill in order from the collar, the edge band partly.
    readonly property var ringLoads: {
        var rings = Art.art.bandRings, out = [], n = stripes ? stripes.length : 0;
        if (n === 0) {
            for (var g = 0; g < rings; g++) out.push(clamp(clamp(fill) * rings - g));
            return out;
        }
        var loads = stripes.slice();
        if (sortStripes) loads.sort(function(a, b) { return b - a; });
        for (var r = 0; r < rings; r++) {
            if (n === 0) { out.push(0); continue; }
            var from = r * n / rings, to = (r + 1) * n / rings, sum = 0;
            for (var c = Math.floor(from); c < to && c < n; c++)
                sum += loads[c] * (Math.min(to, c + 1) - Math.max(from, c));
            out.push(Math.max(0, Math.min(1, sum / (to - from))));
        }
        return out;
    }

    // Colours follow eased copies of the inputs, so a load spike fades in instead of flashing.
    // The easing steps five times a second and stops once it has caught up.
    property var shownRings: []
    property real shownHeat: Math.max(0, heat)
    property real shownSpeed: speed
    property real shownCollar: collar
    property real shownSplit: Math.max(0, split)
    onRingLoadsChanged: startEasing()
    onHeatChanged: startEasing()
    onSpeedChanged: startEasing()
    onCollarChanged: startEasing()
    onSplitChanged: startEasing()
    Timer {
        id: easer
        interval: 200
        repeat: true
        running: false
        onTriggered: if (fish.easeStep()) stop()
    }
    property bool easing: false
    // a still fish (animate false, e.g. the icon renderer) has no clock, so it eases on a timer
    function startEasing() { if (externalClock || animate) easing = true; else easer.start(); }
    // One easing step; returns true once the shown values have caught up. Values move in steps
    // of 1/48: finer changes can't be seen, and each change repaints the fish's canvases (the
    // biggest cost of a fish, measured 2026-10-17), so easing stops as soon as it looks done.
    function easeStep() {
        var k = 0.4, done = true, target = fish.ringLoads, rings = [];
        function step(from, to) {
            var q = Math.round(to * 48) / 48;
            var next = Math.round((from + (q - from) * k) * 48) / 48;
            if (next === from && from !== q) next = from + (q > from ? 1 : -1) / 48;   // always move
            if (next !== q) done = false;
            return next;
        }
        for (var i = 0; i < target.length; i++)
            rings.push(step(i < fish.shownRings.length ? fish.shownRings[i] : 0, target[i]));
        fish.shownRings = rings;
        fish.shownHeat = step(fish.shownHeat, Math.max(0, fish.heat));
        fish.shownSpeed = step(fish.shownSpeed, fish.speed);
        fish.shownCollar = step(fish.shownCollar, fish.collar);
        fish.shownSplit = step(fish.shownSplit, Math.max(0, fish.split));
        return done;
    }

    readonly property color bodyColor: {
        var stops = [[0.0, "#4a8fe0"], [0.35, "#86cfd0"], [0.6, "#f3dc8f"], [0.8, "#f39a4a"], [1.0, "#e2412f"]];
        var h = clamp(shownHeat), c = Qt.rgba(0, 0, 0, 1);
        if (heat < 0) c = Qt.lighter("#b4bcc4", 1);       // no temperature reading
        else for (var i = 1; i < stops.length; i++) {
            if (h <= stops[i][0]) {
                c = mix(stops[i - 1][1], stops[i][1], (h - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]));
                break;
            }
        }
        // frequency: dim when the clock is slow
        c = mix("#1a1d2b", c, 0.55 + 0.45 * clamp(shownSpeed));
        return asleep ? mix(c, "#22262e", 0.7) : c;
    }
    readonly property color finColor: mix(bodyColor, "#ffffff", 0.35)

    function mix(a, b, t) {
        var ca = Qt.lighter(a, 1), cb = Qt.lighter(b, 1);
        return Qt.rgba(ca.r + (cb.r - ca.r) * t, ca.g + (cb.g - ca.g) * t, ca.b + (cb.b - ca.b) * t, 1);
    }
    // with a split, the filled bands nearest the collar take the food colour
    readonly property real splitRings: {
        var sum = 0;
        for (var i = 0; i < shownRings.length; i++) sum += shownRings[i];
        return split < 0 ? 0 : sum * shownSplit;
    }
    // a band's own colour: the stripe colour, or the palette's colour for that band (Bling's)
    function bandColor(ring) {
        var bands = palette.bands, own = bands ? bands[ring % bands.length] : stripeColor;
        return mix(own, foodColor, clamp(splitRings - ring));
    }
    function regionColor(region) {
        switch (region.role) {
        case "band":   return mix(sweaterColor, bandColor(region.ring), region.ring < shownRings.length ? shownRings[region.ring] : 0);
        case "rib":
        case "sleeve": return mix(sweaterColor, stripeColor, shownCollar);
        case "body":
        case "base":   return bodyColor;
        default:       return finColor;         // fins and tail
        }
    }

    // room left of the mouth for food and bubbles, only for fish that eat or blow bubbles
    readonly property real room: intake >= 0 || outflow >= 0 ? 170 : 0
    implicitWidth: Art.art.width + room
    implicitHeight: Art.art.height

    // ---- motion ----
    // Phases advance at a rate that follows the activity, so speeding up never makes the tail jump.
    property real beat: 0               // tail and fins
    property real drift: 0              // slow bobbing
    property real lidDrop: 0.5          // how far the eyelid hangs down, 0..1
    property real blink: 0
    readonly property real lidRest: asleep ? 1 : 0.52 - 0.5 * Math.min(1, clamp(activity) * 1.4)
    property double lastTick: 0
    Timer {
        id: clock
        readonly property real period: 1000 / Math.max(1, fish.fps)
        interval: period
        running: fish.animate && fish.visible && !fish.externalClock
        repeat: true
        onRunningChanged: fish.lastTick = 0
        onTriggered: {
            var now = Date.now();
            var dt = fish.lastTick > 0 ? Math.min(0.2, (now - fish.lastTick) / 1000) : 0;
            fish.lastTick = now;
            fish.advance(dt);
            // next tick on the beat (setting the interval restarts the timer)
            interval = Math.max(1, Math.round(period - now % period));
        }
    }
    // Move every animated part on by dt seconds: tail, bobbing, food and bubbles, blinks, the
    // eyelid and the colour easing.
    property real nextBlink: 2.6 + Math.random() * 3
    property real blinkAge: -1
    property real easeDue: 0
    property bool lidMoving: false
    function advance(dt) {
        if (mirrored) { if (room > 0) flow.advance(dt); return; }
        beat += dt * 2 * Math.PI * (0.35 + 2.4 * clamp(activity));
        drift += dt * 2 * Math.PI * 0.22;
        if (room > 0) flow.advance(dt);
        // blink: shut over 70 ms, open over 130 ms
        nextBlink -= dt;
        if (nextBlink <= 0) {
            nextBlink = 2.6 + Math.random() * 3;
            if (!asleep) blinkAge = 0;
        }
        if (blinkAge >= 0) {
            blinkAge += dt;
            blink = blinkAge < 0.07 ? blinkAge / 0.07 : Math.max(0, 1 - (blinkAge - 0.07) / 0.13);
            if (blinkAge > 0.2) { blinkAge = -1; blink = 0; }
        }
        // The eyelid drifts towards its rest position over a few seconds, and only once the
        // difference is worth showing: following every reading made it flicker (Erik, 2026-10-17).
        var gap = lidRest - lidDrop;
        if (Math.abs(gap) > 0.06) lidMoving = true;
        if (lidMoving) {
            lidDrop += gap * Math.min(1, dt * 1.2);
            if (Math.abs(gap) < 0.005) lidMoving = false;
        }
        // colour easing, five steps a second like the widget's
        if (easing) {
            easeDue += dt;
            if (easeDue >= 0.2) { easeDue = 0; if (easeStep()) easing = false; }
        }
    }
    onLidRestChanged: if (!animate) lidDrop = lidRest        // a still fish has no clock
    Component.onCompleted: { lidDrop = lidRest; shownRings = ringLoads; }

    // The scene is the drawing plus the room in front of the mouth, scaled to fit the fish item.
    Item {
        id: scene
        width: Art.art.width + fish.room
        height: Art.art.height
        anchors.centerIn: parent
        scale: Math.min(fish.width / width, fish.height / height)

    Item {
        id: stage
        x: fish.room
        width: Art.art.width
        height: Art.art.height
        transform: [
            Translate { y: Math.sin(fish.drift) * 5 },
            Rotation { origin.x: stage.width * 0.45; origin.y: stage.height * 0.6; angle: Math.sin(fish.drift * 0.5) * 1.5 }
        ]

        // Wings: only when things are dire. One wing drawn twice, both flapping from their base:
        // a shaded one behind the fish, raised a little, and a white one in front, half a beat behind.
        property real wingBeat: fish.drift * 5
        property real wingAmount: Math.max(0, Math.min(1, (fish.distress - 0.65) / 0.25))
        AngelfishWing { source: "images/wing-back.png"; raise: -16; lag: 0; amount: stage.wingAmount; beat: stage.wingBeat }

        // tail: hinged where it comes out of the sweater's cuff, and drawn behind the body
        Item {
            anchors.fill: parent
            transform: Rotation {
                origin.x: Art.art.tailPivot.x
                origin.y: Art.art.tailPivot.y
                angle: Math.sin(fish.beat) * (4 + 11 * fish.clamp(fish.activity))
            }
            RegionCanvas {
                width: stage.width; height: stage.height
                regions: Art.art.tailRegions
                colors: Art.art.tailRegions.map(function (r) { return fish.regionColor(r); })
            }
            InkCanvas { source: "images/tail-ink.png"; width: stage.width; height: stage.height; color: fish.inkColor }
        }

        RegionCanvas {
            width: stage.width; height: stage.height
            regions: Art.art.regions
            colors: Art.art.regions.map(function (r) { return fish.regionColor(r); })
        }

        // eye: white, a pupil, and a lid that hangs lower the less there is to do
        Item {
            id: eye
            x: Art.art.eye.x
            y: Art.art.eye.y
            width: Art.art.eye.w
            height: Art.art.eye.h
            readonly property real drop: Math.max(fish.lidDrop, fish.blink)
            Shape {
                x: -eye.x; y: -eye.y
                ShapePath { fillColor: "white"; strokeColor: "transparent"; PathSvg { path: Art.art.eye.d } }
            }
            Rectangle {
                width: eye.height * (0.3 - 0.08 * fish.distress)
                height: width
                radius: width / 2
                color: fish.inkColor
                x: eye.width * 0.36 - width / 2
                y: eye.height * 0.56 - height / 2
            }
            // the lid's arc can stray past the hand-drawn eye outline, so only its lower edge is drawn
            Shape {
                id: lid
                visible: eye.drop > 0.03
                readonly property real yc: Math.min(eye.drop, 0.999) * eye.height
                readonly property real hw: {
                    var u = Math.max(-1, Math.min(1, (yc - eye.height / 2) / (eye.height / 2)));
                    return (eye.width / 2) * Math.sqrt(1 - u * u);
                }
                ShapePath {
                    fillColor: fish.bodyColor
                    strokeColor: "transparent"
                    PathSvg {
                        path: {
                            var rx = eye.width / 2 + 2, ry = eye.height / 2 + 2, cx = eye.width / 2, cy = eye.height / 2;
                            var yc = Math.min(eye.drop, 0.999) * eye.height, u = Math.max(-1, Math.min(1, (yc - cy) / ry));
                            var hw = rx * Math.sqrt(1 - u * u);
                            return "M" + (cx - hw) + " " + yc + " A" + rx + " " + ry + " 0 " + (yc > cy ? 1 : 0) + " 1 "
                                    + (cx + hw) + " " + yc + " Z";
                        }
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: fish.inkColor
                    strokeWidth: 3.5
                    capStyle: ShapePath.RoundCap
                    startX: eye.width / 2 - lid.hw; startY: lid.yc
                    PathLine { x: eye.width / 2 + lid.hw; y: lid.yc }
                }
            }
        }

        InkCanvas { source: "images/fish-ink.png"; width: stage.width; height: stage.height; color: fish.inkColor }

        AngelfishWing { source: "images/wing-front.png"; raise: 0; lag: 0.6; amount: stage.wingAmount; beat: stage.wingBeat }

        // halo: fades in with distress, so a faint one is an early warning
        Image {
            source: "images/halo.png"
            // bobs only while shown (bindings that read drift re-run every frame)
            x: Art.art.pieces.halo.x; y: Art.art.pieces.halo.y + (visible ? Math.sin(fish.drift * 2) * 3 : 0)
            width: Art.art.pieces.halo.w; height: Art.art.pieces.halo.h
            mipmap: true
            opacity: Math.max(0, Math.min(1, fish.distress * 1.5))
            visible: opacity > 0
        }
        Image {
            source: "images/sparkles.png"
            x: Art.art.pieces.sparkles.x; y: Art.art.pieces.sparkles.y
            width: Art.art.pieces.sparkles.w; height: Art.art.pieces.sparkles.h
            mipmap: true
            readonly property real amount: Math.max(0, Math.min(1, (fish.distress - 0.5) / 0.3))
            opacity: amount > 0 ? amount * (0.65 + 0.35 * Math.sin(fish.drift * 5)) : 0
            visible: amount > 0
        }
    }

    // Food and bubbles, outside the stage so they don't bob with the fish. Each flake or bubble
    // is a pooled item with an age from 0 to 1; idle ones have age -1.
    Item {
        id: flow
        anchors.fill: parent
        visible: fish.room > 0
        readonly property real mouthX: fish.room + Art.art.mouth.x
        readonly property real mouthY: Art.art.mouth.y + Math.sin(fish.drift) * 5
        property real foodDue: 0
        property real bubbleDue: 0

        function rate(v) { return v > 0.01 ? 0.4 + 4.6 * v : 0; }      // per second
        function spawn(pool, setup) {
            for (var i = 0; i < pool.count; i++) {
                var p = pool.itemAt(i);
                if (p && p.age < 0) { setup(p); p.age = 0; return; }
            }
        }
        function advance(dt) {
            var eat = fish.clamp(fish.intake), blow = fish.clamp(fish.outflow);
            foodDue = Math.min(2, foodDue + dt * (fish.asleep ? 0 : rate(eat)));
            bubbleDue = Math.min(2, bubbleDue + dt * (fish.asleep ? 0.6 : rate(blow)));
            for (; foodDue >= 1; foodDue--)
                spawn(food, function (p) {
                    p.from = (Math.random() - 0.5) * 220;
                    p.spin = (Math.random() - 0.5) * 300;
                    p.life = 2.8 - 1.5 * eat;
                });
            for (; bubbleDue >= 1; bubbleDue--)
                spawn(bubbles, function (p) {
                    p.snore = fish.asleep;
                    p.phase = Math.random() * 6.3;
                    p.big = 0.7 + Math.random() * 0.6;
                    p.life = p.snore ? 4 : 3.2 - 1.4 * blow;
                });
            [food, bubbles].forEach(function (pool) {
                for (var i = 0; i < pool.count; i++) {
                    var p = pool.itemAt(i);
                    if (p && p.age >= 0) p.age = p.age + dt / p.life > 1 ? -1 : p.age + dt / p.life;
                }
            });
        }

        // food flakes drift in from the left and are swallowed at the mouth
        Repeater {
            id: food
            model: 10
            Rectangle {
                property real age: -1
                property real from: 0           // starting height relative to the mouth
                property real spin: 0
                property real life: 2
                readonly property real e: age < 0 ? 0 : age
                // an idle flake reads nothing that changes per frame (mouthY bobs)
                visible: age >= 0
                width: 26; height: 17; radius: 7
                x: visible ? (flow.mouthX - 10) * e - width / 2 : 0
                y: visible ? flow.mouthY + from * (1 - e) * (1 - e) + Math.sin(e * 9 + from) * 6 - height / 2 : 0
                rotation: spin * e
                scale: e > 0.88 ? (1 - e) / 0.12 : 1
                opacity: Math.min(1, e / 0.12)
                color: fish.foodColor
                border.color: fish.inkColor
                border.width: 3
            }
        }

        // bubbles rise from the mouth (z's when asleep)
        Repeater {
            id: bubbles
            model: 10
            Item {
                id: bubble
                property real age: -1
                property bool snore: false   // a z instead of a bubble
                property real phase: 0
                property real big: 1
                property real life: 3
                readonly property real e: age < 0 ? 0 : age
                readonly property real size: (16 + 20 * e) * big
                visible: age >= 0
                x: visible ? flow.mouthX - 14 - 70 * e + Math.sin(phase + e * 8) * 8 - size / 2 : 0
                y: visible ? flow.mouthY - 12 - 330 * e - size / 2 : 0
                width: size; height: size
                opacity: e > 0.7 ? (1 - e) / 0.3 : 1
                // a white rim inside a thin dark one, so it shows on light and dark backgrounds
                Rectangle {
                    visible: !bubble.snore
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: fish.inkColor
                    border.width: 1.5
                }
                Rectangle {
                    visible: !bubble.snore
                    anchors.fill: parent
                    anchors.margins: 1.5
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.22)
                    border.color: Qt.rgba(1, 1, 1, 0.85)
                    border.width: 2.5
                    Rectangle {
                        width: parent.width * 0.25; height: width; radius: width / 2
                        x: parent.width * 0.22; y: parent.height * 0.2
                        color: "white"
                    }
                }
                Text {
                    visible: bubble.snore
                    anchors.centerIn: parent
                    transform: Scale { origin.x: width / 2; xScale: fish.drawnFlipped ? -1 : 1 }
                    text: "z"
                    font.pixelSize: bubble.size * 2
                    font.bold: true
                    color: "#f6f1e4"
                    style: Text.Outline
                    styleColor: fish.inkColor
                }
            }
        }
    }
    }
}
