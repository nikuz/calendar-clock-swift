#version 330

out vec4 finalColor;

// The dilated cut out of the scene, see `lamp-mask.fs`: 1 where the clock and
// the events are, fading to 0 across the padding around them.
uniform sampler2D texture0;
uniform vec2 screenSize;       // the frame buffer, in physical pixels
uniform float contentFraction; // CONTENT_HEIGHT / SCREEN_HEIGHT
uniform vec4 lampColor;        // the color of the dial, already dimmed to the lamp brightness

void main()
{
    // gl_FragCoord is measured from the bottom left corner of the frame buffer,
    // everything else in the application is measured from the top left one.
    // Normalized, so the physical size of the frame buffer cancels itself out
    // and a scaled high DPI window lands on the same pixels as the display does
    float y = 1.0 - gl_FragCoord.y / screenSize.y;
    float mask = 0.0;

    // the clock and the events live in the content strip at the top, under it
    // there is nothing to cut the light out for
    if (y < contentFraction) {
        // the mask is a render texture, its rows are stored bottom up
        vec2 uv = vec2(gl_FragCoord.x / screenSize.x, 1.0 - y / contentFraction);
        mask = texture(texture0, uv).a;
    }

    finalColor = vec4(lampColor.rgb, lampColor.a * (1.0 - mask));
}
