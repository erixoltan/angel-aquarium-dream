import QtQuick 2.15

// Fills a drawing's regions, each in its own colour, and repaints only when the colours change.
// A Canvas paints once into a texture; a Shape per region would be re-triangulated on every
// colour change, which cost a large share of a CPU core.
Canvas {
    property var regions: []        // [{ p: [x0, y0, x1, y1, ...] }, ...]
    property var colors: []         // one colour per region
    // The colours binding hands over a new list whenever anything it reads changes; repaint only
    // when a colour is actually different (painting is a fish's main cost).
    property string painted: ""
    onColorsChanged: {
        var key = colors.join(",");
        if (key !== painted) { painted = key; requestPaint(); }
    }
    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        for (var i = 0; i < regions.length; i++) {
            var p = regions[i].p;
            ctx.beginPath();
            ctx.moveTo(p[0], p[1]);
            for (var k = 2; k < p.length; k += 2)
                ctx.lineTo(p[k], p[k + 1]);
            ctx.closePath();
            ctx.fillStyle = String(colors[i]);
            ctx.fill();
        }
    }
}
