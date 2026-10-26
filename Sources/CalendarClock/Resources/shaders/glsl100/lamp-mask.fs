#version 100

#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 fragTexCoord;

// The scene, rendered on a fully transparent background: every pixel the clock
// and the events cover carries an alpha of 1, everything else carries a 0. Or,
// on the second pass, the result of the first one.
uniform sampler2D texture0;
// One texel along the axis of this pass, in texture coordinates: (1/width, 0)
// on the horizontal pass, (0, 1/height) on the vertical one.
uniform vec2 texelStep;

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
    float mask = 0.0;

    // a dilation of the alpha channel: separable, so the two passes together
    // cost 2 * (2 * RADIUS + 1) samples instead of the square of it
    for (int i = -RADIUS; i <= RADIUS; i++) {
        float offset = float(i);
        // clamped rather than wrapped: past the edge of the scene the dilation
        // has to carry the edge on, not the far side of the screen
        vec2 sampleCoord = clamp(fragTexCoord + texelStep * offset, vec2(0.0), vec2(1.0));
        mask = max(mask, texture2D(texture0, sampleCoord).a * falloff(abs(offset)));
    }

    gl_FragColor = vec4(mask, mask, mask, mask);
}
