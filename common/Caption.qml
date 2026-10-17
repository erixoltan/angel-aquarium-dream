import QtQuick 2.15
import "Palettes.js" as Palettes

// A name tag for a fish: its text on a pill in the fish's stripe colour, so it reads on any
// wallpaper and repeats the colour code. Pure QtQuick, like the characters.
Rectangle {
    id: caption
    property string kind: "cpu"
    property string text: Palettes.of(kind).name
    property real pixelSize: 14

    // rounded up with a pixel spare: an exact fit can elide the text when it's measured again
    implicitWidth: Math.ceil(label.implicitWidth) + 1 + pixelSize * 1.2
    implicitHeight: label.implicitHeight + pixelSize * 0.3
    radius: height / 2
    color: Palettes.of(kind).stripe
    border.color: Palettes.of(kind).ink
    border.width: Math.max(1, pixelSize / 12)

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, caption.width - caption.pixelSize * 1.2)
        text: caption.text
        elide: Text.ElideRight
        color: "#f6f1e4"        // the sweater's cream
        font.pixelSize: caption.pixelSize
        font.bold: true
        font.letterSpacing: caption.pixelSize * 0.05
    }
}
