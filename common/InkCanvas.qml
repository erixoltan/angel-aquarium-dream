import QtQuick 2.15

// A drawing's ink layer in any colour. The ink pictures are black with alpha; this paints one and
// then floods it with the colour, keeping the alpha. Repainted only when the colour changes, and
// it needs no shaders, so it works the same under Qt 5 and Qt 6.
Canvas {
    id: ink
    property url source
    property color color: "black"
    onColorChanged: requestPaint()
    onSourceChanged: loadImage(source)
    onImageLoaded: requestPaint()
    Component.onCompleted: loadImage(source)
    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (!isImageLoaded(source)) return;
        ctx.drawImage(source, 0, 0, width, height);
        ctx.globalCompositeOperation = "source-in";
        ctx.fillStyle = String(ink.color);
        ctx.fillRect(0, 0, width, height);
    }
}
