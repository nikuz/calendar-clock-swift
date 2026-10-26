#version 330

out vec4 finalColor;

// The scene, rendered on a fully transparent background: every pixel the clock
// and the events cover carries an alpha of 1, everything else carries a 0. Or,
// on the second pass, the result of the first one.
uniform sampler2D texture0;
uniform vec2 sourceSize;       // size of the source texture, in pixels
uniform vec2 stepDirection;    // (1, 0) on the horizontal pass, (0, 1) on the vertical one

// How far the cut out reaches past the pixels it is made for. The bounds of the
// loop have to be a compile time constant on GLSL ES 1.00, so the radius is
// baked into the shader instead of arriving as a uniform.
const int RADIUS = 6;
// Up to this distance the cut out is solid, past it the light fades back in.
const float CORE = 3.0;

// Normalized over RADIUS rather than past it: the loop stops sampling at
// RADIUS, so a falloff that still had weight left there would end the halo
// on a step of light instead of fading into it.
float falloff(float offsetDistance)
{
    return clamp(
        (float(RADIUS) - offsetDistance) / (float(RADIUS) - CORE),
        0.0,
        1.0
    );
}

void main()
{
    // the target has the size of the source, so the fragment and the texel it
    // is made of are one and the same
    vec2 uv = gl_FragCoord.xy / sourceSize;
    vec2 texelStep = stepDirection / sourceSize;
    float mask = 0.0;

    // a dilation of the alpha channel: separable, so the two passes together
    // cost 2 * (2 * RADIUS + 1) samples instead of the square of it
    for (int i = -RADIUS; i <= RADIUS; i++) {
        float offset = float(i);
        vec2 sampleUV = clamp(uv + texelStep * offset, vec2(0.0), vec2(1.0));
        float sampled = texture(texture0, sampleUV).a;
        mask = max(mask, sampled * falloff(abs(offset)));
    }

    finalColor = vec4(mask, mask, mask, mask);
}
