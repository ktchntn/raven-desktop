#version 440
// RAVEN: VPN card radar (components/VpnCard.qml). A dot grid; a slow sweep lights the dots it
// passes (lime, fading behind it), a few fixed "blips" flare as it crosses them. Dots fade out
// toward the edges so the effect has no hard border inside the card.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float angle;        // sweep angle, radians
    float spacing;      // grid pitch, px
    float edge;         // fade-out width at the edges, px
    vec2 size;          // item size, px
    vec2 centre;        // sweep centre, px
    vec4 accent;
    vec4 grid;
};

const float TAU = 6.2831853;
const float TAIL = 1.4;          // radians of glowing wake behind the arm

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 cell = floor(p / spacing);
    vec2 c = (cell + 0.5) * spacing;
    float d = length(p - c);

    float a = atan(c.y - centre.y, c.x - centre.x);
    float behind = mod(angle - a, TAU);                 // 0 = under the arm, grows behind it
    float wake = clamp(1.0 - behind / TAIL, 0.0, 1.0);
    wake *= wake;

    float blip = step(0.985, hash(cell)) * exp(-behind * 1.6);

    float e = min(min(c.x, c.y), min(size.x - c.x, size.y - c.y));
    float fade = smoothstep(0.0, edge, e);

    float r = 1.1 + 0.5 * wake + 1.0 * blip;
    float dotMask = 1.0 - smoothstep(r - 0.4, r + 0.6, d);

    float lime = max(wake * 0.42 + (wake > 0.0 ? 0.06 : 0.0), blip * 0.95);
    vec3 rgb = mix(grid.rgb, accent.rgb, step(0.001, lime));
    float alpha = (lime > 0.001 ? lime : 0.28) * dotMask * fade;
    fragColor = vec4(rgb * alpha, alpha) * qt_Opacity;
}
