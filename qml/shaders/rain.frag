#version 440
// RAVEN: lock screen dot rain (services/Lock.qml). A faint dot grid; columns of lit dots fall
// over it, lime at the head fading to grey. Every column has its own start time, speed, length
// and pause between drops (hashed from the column index), so nothing is stored per column. The
// screen starts empty at lock time and the rain builds up as the columns start one by one.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;         // seconds since the screen locked
    float pitch;        // grid pitch, px
    vec2 size;          // item size, px
    vec4 accent;
    vec4 ink;
    vec4 grid;
};

float hash(float x, float k) {
    return fract(sin(x * 12.9898 + k * 78.233) * 43758.5453);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 cell = floor(p / pitch);
    vec2 c = (cell + 0.5) * pitch;
    float d = length(p - c);
    float rows = ceil(size.y / pitch);

    float col = cell.x;
    float speed = 4.5 + 10.5 * hash(col, 1.0);           // cells per second
    float len = 8.0 + 18.0 * hash(col, 2.0);
    float gap = rows * (0.3 + 1.4 * hash(col, 3.0));    // pause before the next drop
    float cycle = rows + len + gap;
    float start = 7.0 * hash(col, 4.0);                  // first drop: 0-7 s after locking
    float local = time - start;
    float head = local < 0.0 ? -1.0e4 : floor(mod(local * speed, cycle));
    float i = head - cell.y;                             // 0 = the head, grows up the tail

    // the faint grid dot, always there
    vec3 rgb = grid.rgb * 0.5 * (1.0 - smoothstep(0.7, 1.7, d));
    if (i >= 0.0 && i < len) {
        float t = 1.0 - i / len;
        vec3 lit;
        float r;
        if (i < 0.5)      { lit = accent.rgb;             r = 2.3; }   // head
        else if (i < 2.5) { lit = accent.rgb * 0.75 * t;  r = 1.9; }   // just behind it
        else              { lit = ink.rgb * 0.55 * t * t; r = 1.9; }   // tail, fading
        rgb = max(rgb, lit * (1.0 - smoothstep(r - 0.4, r + 0.6, d)));
    }
    fragColor = vec4(rgb, 1.0) * qt_Opacity;
}
