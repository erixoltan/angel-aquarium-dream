import QtQuick 2.15

// The tank's water: deep-blue gradient, moving caustic light near the surface, slanted light
// rays, and a sandy floor. One fragment shader on the GPU, so the CPU only advances `time`.
// Pure QtQuick, like the characters.
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

    fragmentShader: "
        varying highp vec2 qt_TexCoord0;
        uniform lowp float qt_Opacity;
        uniform highp float time;
        uniform highp float aspect;
        uniform highp float floorLevel;
        uniform highp vec2 worldSize;
        uniform highp vec2 offset;
        uniform highp vec2 viewSize;

        // Tileable water caustic (after Dave Hoskins / joltz0r): a few iterations of warped
        // sines whose bright creases look like light focused by surface waves.
        highp float caustic(highp vec2 uv, highp float t) {
            highp vec2 p = mod(uv * 6.28318, 6.28318) - 250.0;
            highp vec2 i = p;
            highp float c = 1.0;
            for (int n = 0; n < 4; n++) {
                highp float tn = t * (1.0 - (3.5 / float(n + 1)));
                i = p + vec2(cos(tn - i.x) + sin(tn + i.y), sin(tn - i.y) + cos(tn + i.x));
                c += 1.0 / length(vec2(p.x / (sin(i.x + tn) / 0.005), p.y / (cos(i.y + tn) / 0.005)));
            }
            c = 1.17 - pow(c / 4.0, 1.4);
            return pow(abs(c), 8.0);
        }

        void main() {
            highp vec2 uv = (qt_TexCoord0 * viewSize + offset) / worldSize;   // in the whole tank; y grows downwards
            highp float depth = uv.y / floorLevel;    // 0 at the surface, 1 at the sand

            lowp vec3 shallow = vec3(0.13, 0.52, 0.66);
            lowp vec3 deep = vec3(0.02, 0.11, 0.24);
            highp vec3 col = mix(shallow, deep, pow(clamp(depth, 0.0, 1.0), 0.75));

            // caustics fade with depth
            highp vec2 cuv = vec2(uv.x * aspect, uv.y) * 0.55;
            col += vec3(0.55, 0.8, 0.85) * caustic(cuv, time * 0.35) * 0.32 * pow(1.0 - clamp(depth, 0.0, 1.0), 1.6);

            // light rays from the surface, slanted and slowly swaying
            highp float x = uv.x * aspect + uv.y * 0.35;
            highp float rays = sin(x * 7.0 + sin(time * 0.13) * 1.5) * sin(x * 3.1 - time * 0.07 + 1.3);
            col += vec3(0.6, 0.85, 0.9) * max(rays, 0.0) * 0.09 * (1.0 - clamp(depth, 0.0, 1.0));

            // sand: a gently waving top edge, lit by the same caustics
            highp float edge = floorLevel + 0.012 * sin(uv.x * aspect * 9.0) + 0.008 * sin(uv.x * aspect * 23.0 + 1.0);
            if (uv.y > edge) {
                highp float s = (uv.y - edge) / max(0.001, 1.0 - edge);
                highp vec3 sand = mix(vec3(0.62, 0.55, 0.38), vec3(0.36, 0.30, 0.20), s);
                sand += vec3(0.25, 0.3, 0.25) * caustic(cuv * 1.7, time * 0.35) * 0.12;
                col = mix(col, sand, smoothstep(0.0, 0.004, uv.y - edge));
            }
            gl_FragColor = vec4(col, 1.0) * qt_Opacity;
        }"
}
