// Oahzi intro — concept 3b "water ripple reveal" shaders (Jim's MOTION_NOTES.md).
// Used from IntroView via ShaderLibrary.oahziRipple (distortionEffect) and
// ShaderLibrary.oahziRippleLight (colorEffect). All lengths are in points, t in seconds.
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Note: pow(x, 2.0) is undefined for negative x in Metal, so squares are written as x * x.

// distortionEffect signature: float2 f(float2 position, args...)
[[ stitchable ]] float2 oahziRipple(float2 position, float2 center, float t,
                                    float speed, float wavelength, float amp0) {
    float2 d = position - center;
    float r = length(d) + 0.001;
    float k = 2.0 * M_PI_F / wavelength;
    float disp = 0.0;
    for (int i = 0; i < 3; i++) {
        float tt = t - float(i) * 0.25;
        if (tt <= 0.0) { continue; }
        float front = speed * tt;
        float e = (r - front) / (wavelength * 1.45);
        float env = exp(-e * e);
        float amp = amp0 * exp(-tt * 1.6) * (1.0 + 0.6 * exp(-r / 67.0));
        disp += amp * env * sin(k * (r - front));
    }
    if (t > 0.3) {
        float tc = t - 0.3;
        float g = r / 110.0;
        disp += amp0 * 1.2 * exp(-tc * 2.2) * exp(-g * g) * sin(k * 1.3 * r - t * 14.0);
    }
    return position - (d / r) * disp;
}

// colorEffect signature: half4 f(float2 position, half4 color, args...)
// Refraction light: brighten rising wave faces, darken falling ones. Colors are premultiplied.
[[ stitchable ]] half4 oahziRippleLight(float2 position, half4 color, float2 center, float t,
                                        float speed, float wavelength, float amp0) {
    float r = length(position - center);
    float k = 2.0 * M_PI_F / wavelength;
    float slope = 0.0;
    for (int i = 0; i < 3; i++) {
        float tt = t - float(i) * 0.25;
        if (tt <= 0.0) { continue; }
        float front = speed * tt;
        float e = (r - front) / (wavelength * 1.45);
        float env = exp(-e * e);
        slope += amp0 * exp(-tt * 1.6) * env * k * cos(k * (r - front));
    }
    float hl = clamp(slope, -1.5, 1.5);
    float delta = max(hl, 0.0) * 0.11 - max(-hl, 0.0) * 0.04;
    half3 c = clamp(color.rgb + half3(half(delta)) * color.a, half3(0.0h), half3(color.a));
    return half4(c, color.a);
}
