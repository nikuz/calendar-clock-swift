#version 100

precision mediump float;

// Input vertex attributes
varying vec2 fragTexCoord;
varying vec4 fragColor;

// Input uniforms
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec2 screenSize;
uniform vec2 direction;     // (1.0, 0.0) for horizontal, (0.0, 1.0) for vertical
uniform bool applyGrayscale; // false for Pass 1, true for Pass 2

// Gaussian blur parameters
const vec3 offset = vec3(0.0, 1.3846153846, 3.2307692308);
const vec3 weight = vec3(0.2270270270, 0.3162162162, 0.0702702703);

void main()
{
    vec2 texel = 1.0 / screenSize;

    // Base pixel calculation
    vec4 color = texture2D(texture0, fragTexCoord) * weight.x;

    // Multiply texture coordinate steps by the custom direction uniform
    color += texture2D(texture0, fragTexCoord + (direction * offset.y * texel)) * weight.y;
    color += texture2D(texture0, fragTexCoord - (direction * offset.y * texel)) * weight.y;

    color += texture2D(texture0, fragTexCoord + (direction * offset.z * texel)) * weight.z;
    color += texture2D(texture0, fragTexCoord - (direction * offset.z * texel)) * weight.z;

    // Apply tint and vertex color
    color *= colDiffuse * fragColor;

    // Conditionally convert to grayscale only on the final pass
    if (applyGrayscale)
    {
        float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        gl_FragColor = vec4(vec3(gray), color.a);
    }
    else
    {
        gl_FragColor = color;
    }
}
