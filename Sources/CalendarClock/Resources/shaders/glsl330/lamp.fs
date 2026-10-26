#version 330

in vec2 fragTexCoord;

out vec4 finalColor;

// The dilated cut out of the scene, see `lamp-mask.fs`: 1 where the clock and
// the events are, fading to 0 across the padding around them. Drawn one to one
// over the content strip, so the coordinates of the quad are the coordinates of
// the mask and no mapping of the fragment position is needed.
uniform sampler2D texture0;
// The color of the dial, already dimmed to the brightness of the lamp.
uniform vec4 lampColor;

void main()
{
    float mask = texture(texture0, fragTexCoord).a;

    finalColor = vec4(lampColor.rgb, lampColor.a * (1.0 - mask));
}
