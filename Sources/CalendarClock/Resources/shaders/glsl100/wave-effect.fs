#version 100

precision mediump float;

varying vec2 fragTexCoord;
varying vec4 fragColor;

// Custom inputs passed from Swift
uniform vec2 centerPoint;
uniform float time;
uniform vec4 baseColor;
uniform vec2 screenSize;
uniform float baseBrightness;

void main()
{
    vec2 pixelPos = fragTexCoord * screenSize;
    float dist = distance(pixelPos, centerPoint);

    float circleDistance = 30.0;
    float speed = 50.0;

    float animationOffset = mod(time * speed, circleDistance);
    float ringMap = mod(dist - animationOffset, circleDistance);

    float phase = mod(dist - animationOffset, circleDistance);
    float d = abs(phase - circleDistance * 0.5);
    float ringHalfWidth = 0.5;
    float ringAlpha = 1.0 - smoothstep(
        ringHalfWidth,
        ringHalfWidth + 1.0,
        d
    );

    float maxDistance = max(screenSize.x - centerPoint.x, centerPoint.x);
    float distanceFactor = dist / maxDistance;

    float dynamicBrightness = mix(0.3, 1.0, 1.0 - distanceFactor);

    vec4 finalRingColor = baseColor * fragColor;
    finalRingColor.rgb *= dynamicBrightness;

    gl_FragColor = vec4(finalRingColor.rgb, ringAlpha * finalRingColor.a);
}