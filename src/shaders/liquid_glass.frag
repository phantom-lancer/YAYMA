#include <flutter/runtime_effect.glsl>

// Procedural optical layer for the Liquid Glass surfaces. The backdrop itself
// is sampled by a BackdropFilter underneath; this shader adds the parts a blur
// cannot produce: a normal-mapped refraction field, caustic highlights, a
// Fresnel rim with slight chromatic dispersion and a moving specular lobe.

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uTint;
uniform vec4 uTint2;
uniform vec2 uLight;
uniform float uRadius;
uniform float uIntensity;

out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * valueNoise(p);
        p = p * 2.03 + vec2(11.7, 7.3);
        amplitude *= 0.5;
    }
    return value;
}

// Signed distance to the rounded rectangle that the widget clips to.
float roundedBoxDistance(vec2 p, vec2 halfSize, float radius) {
    vec2 q = abs(p) - (halfSize - vec2(radius));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec2 p = (uv - 0.5) * uSize;
    vec2 halfSize = uSize * 0.5;

    float sd = roundedBoxDistance(p, halfSize, min(uRadius, min(halfSize.x, halfSize.y)));
    if (sd > 0.75) {
        fragColor = vec4(0.0);
        return;
    }

    // Keep the noise field aspect-independent so a wide bar and a square card
    // show the same optical grain.
    vec2 field = uv * vec2(uSize.x / max(uSize.y, 1.0), 1.0);

    float slow = fbm(field * 2.15 + vec2(uTime * 0.035, -uTime * 0.022));
    float fast = fbm(field * 5.40 + vec2(-uTime * 0.060, uTime * 0.041));

    // A fake surface normal derived from the noise gradient. It displaces the
    // tint as if the glass had a gently warped back surface.
    float dx = fbm(field * 3.1 + vec2(0.02, 0.0)) - fbm(field * 3.1 - vec2(0.02, 0.0));
    float dy = fbm(field * 3.1 + vec2(0.0, 0.02)) - fbm(field * 3.1 - vec2(0.0, 0.02));
    vec3 normal = normalize(vec3(dx * 2.4, dy * 2.4, 1.0));

    vec3 tint = mix(uTint.rgb, uTint2.rgb, clamp(slow * 1.15, 0.0, 1.0));

    float caustic = smoothstep(0.52, 0.92, slow * 0.72 + fast * 0.34);
    float caustic2 = smoothstep(0.68, 0.98, fast);

    // Specular lobe from the user-controlled light position.
    vec2 lightP = (uLight - 0.5) * uSize;
    vec3 lightDir = normalize(vec3(lightP - p, max(uSize.x, uSize.y) * 0.62));
    float specular = pow(max(dot(normal, lightDir), 0.0), 34.0);
    float softGlow = exp(-length(lightP - p) / max(uSize.x, uSize.y) * 2.4);

    // Fresnel: light gathers at the rim, strongest on the top-left edge.
    float inside = 1.0 - smoothstep(-1.4, 1.4, sd);
    float rim = smoothstep(-3.0, 0.0, sd) * inside;
    float rimBias = 0.55 + 0.45 * clamp(0.5 - uv.x + (1.0 - uv.y), 0.0, 1.0);

    // A touch of chromatic dispersion on the rim sells the refractive edge.
    vec3 fringe = mix(vec3(0.34, 0.62, 1.0), vec3(1.0, 0.46, 0.72), clamp(uv.x, 0.0, 1.0));

    vec3 color = tint * (0.10 + 0.22 * caustic + 0.10 * caustic2);
    color += vec3(0.92, 0.96, 1.0) * specular * 0.55;
    color += vec3(1.0) * rim * rimBias * 0.42;
    color += fringe * rim * 0.10;
    color += tint * softGlow * 0.16;

    float alpha = 0.10
        + 0.18 * caustic
        + 0.08 * caustic2
        + 0.30 * rim * rimBias
        + 0.26 * specular
        + 0.10 * softGlow;
    alpha *= uIntensity;

    // Darken just inside the rim so the pane keeps a physical thickness.
    float innerShade = smoothstep(-14.0, -1.0, sd) * inside;
    color *= 1.0 - 0.16 * (1.0 - innerShade);

    fragColor = vec4(clamp(color, 0.0, 1.0), clamp(alpha, 0.0, 1.0));
}
