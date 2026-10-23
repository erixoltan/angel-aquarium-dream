import QtQuick 2.15

// Plasma 6 / Qt 6 version of common/Water.qml: the same water, with the shader baked ahead of time
// (water.frag, built into water.frag.qsb next to this file), since Qt 6 can't compile one at run
// time. The properties are the shader's uniforms, by name.
ShaderEffect {
    id: water

    property real time: 0               // seconds; the host advances it
    property real floorLevel: 0.9       // where the sand starts, as a fraction of the height
    // A tank across several screens draws one slice per window: the whole tank's size, and where
    // this slice starts in it. Alone, the slice is the whole tank.
    property size worldSize: Qt.size(width, height)
    property point offset: Qt.point(0, 0)
    readonly property size viewSize: Qt.size(width, height)
    readonly property real aspect: worldSize.width / Math.max(1, worldSize.height)

    fragmentShader: "water.frag.qsb"
}
