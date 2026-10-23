#version 440
// The water shader of common/Water.qml in Qt 6's form: Qt 6 takes no shader source at run time, so
// `make` bakes this into water.frag.qsb with qsb (package qt6-shader-baker). Keep the two in step.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// Qt's default vertex shader reads qt_Matrix and qt_Opacity, so they come first.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float aspect;
    float floorLevel;
    vec2 worldSize;
    vec2 offset;
    vec2 viewSize;
};

// Tileable water caustic (after Dave Hoskins / joltz0r): a few iterations of warped
// sines whose bright creases look like light focused by surface waves.
float caustic(vec2 uv, float t) {
    vec2 p = mod(uv * 6.28318, 6.28318) - 250.0;
    vec2 i = p;
    float c = 1.0;
    for (int n = 0; n < 4; n++) {
        float tn = t * (1.0 - (3.5 / float(n + 1)));
        i = p + vec2(cos(tn - i.x) + sin(tn + i.y), sin(tn - i.y) + cos(tn + i.x));
        c += 1.0 / length(vec2(p.x / (sin(i.x + tn) / 0.005), p.y / (cos(i.y + tn) / 0.005)));
    }
    c = 1.17 - pow(c / 4.0, 1.4);
    return pow(abs(c), 8.0);
}

void main() {
    vec2 uv = (qt_TexCoord0 * viewSize + offset) / worldSize;   // in the whole tank; y grows downwards
    float depth = uv.y / floorLevel;    // 0 at the surface, 1 at the sand

    vec3 shallow = vec3(0.13, 0.52, 0.66);
    vec3 deep = vec3(0.02, 0.11, 0.24);
    vec3 col = mix(shallow, deep, pow(clamp(depth, 0.0, 1.0), 0.75));

    // caustics fade with depth
    vec2 cuv = vec2(uv.x * aspect, uv.y) * 0.55;
    col += vec3(0.55, 0.8, 0.85) * caustic(cuv, time * 0.35) * 0.32 * pow(1.0 - clamp(depth, 0.0, 1.0), 1.6);

    // light rays from the surface, slanted and slowly swaying
    float x = uv.x * aspect + uv.y * 0.35;
    float rays = sin(x * 7.0 + sin(time * 0.13) * 1.5) * sin(x * 3.1 - time * 0.07 + 1.3);
    col += vec3(0.6, 0.85, 0.9) * max(rays, 0.0) * 0.09 * (1.0 - clamp(depth, 0.0, 1.0));

    // sand: a gently waving top edge, lit by the same caustics
    float edge = floorLevel + 0.012 * sin(uv.x * aspect * 9.0) + 0.008 * sin(uv.x * aspect * 23.0 + 1.0);
    if (uv.y > edge) {
        float s = (uv.y - edge) / max(0.001, 1.0 - edge);
        vec3 sand = mix(vec3(0.62, 0.55, 0.38), vec3(0.36, 0.30, 0.20), s);
        sand += vec3(0.25, 0.3, 0.25) * caustic(cuv * 1.7, time * 0.35) * 0.12;
        col = mix(col, sand, smoothstep(0.0, 0.004, uv.y - edge));
    }
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
