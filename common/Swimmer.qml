import QtQuick 2.15
import "AngelfishArt.js" as Art

// One angelfish swimming in a tank, with its name tag. Pure QtQuick. The host sets the fish's
// inputs (`fish.*`) from a provider; the tank calls step(dt) every frame and places it.
//
// Movement follows the same grammar as the looks:
//   speed       the tail beat: swimming speed is the beat rate times a fixed stride, so a fish
//               that works hard visibly hurries and an idle one drifts
//   height      distress raises the fish towards the surface; with wings it hovers there
//   asleep      the fish sinks to the sand and rests
//   depth       fish swim nearer and farther (smaller = farther), and only steer round fish at
//               about the same depth; the others pass in front or behind
// Moving only changes this item's position, so it costs nothing next to drawing the fish.
// Everything, the fish's own tail, blinks and easing included, steps on the tank's one clock, so
// the screen is redrawn at the tank's frame rate and no more.
Item {
    id: swimmer

    property alias fish: angelfish
    property alias caption: tag.text
    property string note: ""                // a small second line under the tag; empty = none
    property string kind: "cpu"
    property bool showCaption: true
    property bool onView: true              // false = outside this window, so nothing is drawn
    property real depth: 0                  // 0 = nearest the glass, 1 = farthest back; a host
                                            // sets where it starts, then it wanders
    property real tz: depth                 // the depth it's heading for

    // The tank (in this item's parent's coordinates): where the water is, and the sand line.
    property real tankWidth: 800
    property real surface: 0
    property real floor: 600
    property real bodyWidth: 220            // fish width at depth 0

    // size = the drawn fish's width; fish that eat or blow bubbles get their extra room in front
    // of the mouth on top, so every fish's body is the same size at the same depth
    readonly property real size: bodyWidth * (1 - 0.45 * depth)
    readonly property real fishWidth: size * angelfish.implicitWidth / Art.art.width
    readonly property real fishHeight: size * angelfish.implicitHeight / Art.art.width
    width: fishWidth
    height: fishHeight + (showCaption ? tag.height : 0) + (note !== "" ? noteLine.height : 0)
    z: -depth * 10

    // position of the fish's centre, velocity, and where it is heading
    property real px: tankWidth / 2
    property real py: (surface + floor) / 2
    property real vx: 0
    property real vy: 0
    property real tx: px
    property real ty: py
    property real retarget: 0               // seconds until a new height and depth are picked
    property int heading: 0                 // which way it's crossing the tank: -1 left, 1 right
    property bool placed: false             // set by the tank when it first places this fish
    property int facing: -1                 // -1 = left (the drawing's own direction), 1 = right
    property real flip: 1                   // the drawing's x scale, easing towards -facing
    property real tilt: 0
    x: px - width / 2
    y: py - fishHeight / 2

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
    // the same tail-beat rate Angelfish uses, in beats per second
    function beatRate() { return 0.35 + 2.4 * clamp(angelfish.activity, 0, 1); }
    // the band of water this fish keeps to, from its state
    function band() {
        var top = surface + fishHeight * 0.6, bottom = floor - fishHeight * 0.55;
        if (angelfish.asleep) return [bottom, bottom];
        var d = clamp(angelfish.distress, 0, 1), span = bottom - top;
        // calm: the middle of the tank; distressed: rising, until wings keep it near the top
        var centre = top + span * (0.55 - 0.47 * d), half = span * (0.35 - 0.3 * d);
        return [clamp(centre - half, top, bottom), clamp(centre + half, top, bottom)];
    }
    // A new destination: turn round and swim to the far wall, or now and then turn early,
    // somewhere on the way (Erik, 2026-10-17: fish that kept picking nearby spots stayed in the
    // middle of the tank). The first crossing heads for the farther wall.
    function pickTarget() {
        if (angelfish.asleep) {
            tx = px;
            pickHeight();
            return;
        }
        var margin = fishWidth * 0.6, left = margin, right = Math.max(margin + 1, tankWidth - margin);
        heading = heading === 0 ? (px - left > right - px ? -1 : 1) : -heading;
        var wall = heading < 0 ? left : right;
        tx = Math.random() < 0.25 ? px + (wall - px) * (0.35 + 0.45 * Math.random()) : wall;
        pickHeight();
    }
    // a new height and depth, without changing where it's heading
    function pickHeight() {
        var b = band();
        ty = b[0] + Math.random() * (b[1] - b[0]);
        tz = angelfish.asleep ? depth : Math.random() * 0.8;
        retarget = 8 + Math.random() * 12;
    }
    // the tank asks a fish to make way: move a little nearer or farther
    function makeWay(dz) { tz = clamp(tz + dz, 0, 0.8); }

    // Advance by dt seconds. (ax, ay) is extra acceleration from the tank, e.g. keeping clear
    // of other fish.
    function step(dt, ax, ay) {
        angelfish.advance(dt);
        var b = band();
        retarget -= dt;
        var dx = tx - px, dy = ty - py, dist = Math.sqrt(dx * dx + dy * dy);
        // arrived (sideways; it may still be climbing or diving): turn round
        if (Math.abs(dx) < size * 0.4) {
            pickTarget();
            dx = tx - px; dy = ty - py; dist = Math.sqrt(dx * dx + dy * dy);
        } else if (retarget <= 0 || ty < b[0] - 1 || ty > b[1] + 1) {
            pickHeight();
            dx = tx - px; dy = ty - py; dist = Math.sqrt(dx * dx + dy * dy);
        }
        var cruise = angelfish.asleep ? size * 0.25 : beatRate() * 0.22 * size;
        var want = dist > 1 ? cruise / dist : 0;
        // ease into the wanted velocity: fish turn in arcs, not on the spot
        var k = Math.min(1, dt * 1.1);
        vx += (dx * want - vx) * k + (ax || 0) * dt;
        vy += (dy * want - vy) * k + (ay || 0) * dt;
        if (angelfish.asleep) vx *= 1 - Math.min(1, dt * 2);   // settles straight down
        // nearer or farther, slowly: a few seconds to cross the tank's depth
        depth = clamp(depth + clamp(tz - depth, -1, 1) * Math.min(1, dt * 0.35), 0, 1);
        px = clamp(px + vx * dt, fishWidth * 0.5, tankWidth - fishWidth * 0.5);
        py = clamp(py + vy * dt, surface + fishHeight * 0.5, floor - fishHeight * 0.45);
        // Face the way it swims. Turn only when clearly swimming the other way *and* heading
        // there, so a nudge from another fish doesn't flip it.
        if (vx < -cruise * 0.5 && tx < px) facing = -1;
        else if (vx > cruise * 0.5 && tx > px) facing = 1;
        // turn around over about half a second
        if (flip !== -facing) {
            var turn = dt * 4.5;
            flip = Math.abs(-facing - flip) <= turn ? -facing : flip + (flip < -facing ? turn : -turn);
        }
        // nose up or down a little when climbing or diving
        var speed = Math.abs(vx) + 1;
        tilt = angelfish.asleep ? 0 : clamp(Math.atan2(vy, speed) * 180 / Math.PI * 0.5, -14, 14);
    }

    Item {
        id: body
        visible: swimmer.onView
        width: swimmer.fishWidth
        height: swimmer.fishHeight
        transform: [
            Scale {
                origin.x: body.width / 2
                xScale: swimmer.flip         // the drawing faces left
            },
            Rotation {
                origin.x: body.width / 2; origin.y: body.height / 2
                // tilt is in screen terms; with the fish flipped, the same nose-up angle has the
                // other sign
                angle: swimmer.tilt * swimmer.facing
            }
        ]
        Angelfish {
            id: angelfish
            anchors.fill: parent
            kind: swimmer.kind
            externalClock: true          // the tank's clock drives it (step)
        }
    }
    Caption {
        id: tag
        anchors.top: body.bottom
        anchors.horizontalCenter: body.horizontalCenter
        visible: swimmer.showCaption && swimmer.onView
        kind: swimmer.kind
        pixelSize: Math.max(10, swimmer.size * 0.07)
        opacity: 1 - 0.35 * swimmer.depth
    }
    Text {
        id: noteLine
        anchors.top: tag.visible ? tag.bottom : body.bottom
        anchors.horizontalCenter: body.horizontalCenter
        visible: swimmer.note !== "" && swimmer.onView
        text: swimmer.note
        horizontalAlignment: Text.AlignHCenter
        color: "#f6f1e4"                    // the sweater's cream, outlined so it reads on water
        style: Text.Outline
        styleColor: "#1c2128"
        font.pixelSize: Math.max(9, swimmer.size * 0.055)
        opacity: 0.85 - 0.35 * swimmer.depth
    }
}
