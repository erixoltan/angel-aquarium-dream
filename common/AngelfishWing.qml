import QtQuick 2.15
import "AngelfishArt.js" as Art

// One angel wing, flapping from its base. The angelfish draws two: one behind the body and one
// in front. Both use the same picture and the same hinge, so they stay attached at the root.
Image {
    id: wingImage
    property real raise: 0          // degrees, negative lifts the wing
    property real lag: 0            // radians behind the beat
    property real amount: 0
    property real beat: 0
    readonly property real rootX: Art.art.wingRoot.x - Art.art.pieces.wing_front.x
    readonly property real rootY: Art.art.wingRoot.y - Art.art.pieces.wing_front.y
    x: Art.art.pieces.wing_front.x; y: Art.art.pieces.wing_front.y
    width: Art.art.pieces.wing_front.w; height: Art.art.pieces.wing_front.h
    mipmap: true
    opacity: amount
    visible: amount > 0
    transform: [
        Scale { origin.x: wingImage.rootX; origin.y: wingImage.rootY
                xScale: 0.6 + 0.4 * wingImage.amount; yScale: 0.6 + 0.4 * wingImage.amount },
        // no wing, no flapping: read `beat` only while visible, so a wingless fish doesn't
        // re-evaluate this on every frame
        Rotation { origin.x: wingImage.rootX; origin.y: wingImage.rootY
                   angle: wingImage.visible ? wingImage.raise + Math.sin(wingImage.beat - wingImage.lag) * 12 - 4 : 0 }
    ]
}
