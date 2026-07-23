#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

// Custom inputs passed from Swift
uniform vec2 centerPoint;      // The (x, y) center position of the event in screen pixels
uniform float time;            // Total elapsed time from GetTime()
uniform vec4 baseColor;        // The color of the active calendar event
uniform vec2 screenSize;       // Screen dimensions (1024.0, 128.0)
uniform float baseBrightness;  // appState.brightness.dayFactor

void main()
{
    // Convert current pixel position from normalized UV coordinates to screen pixels
    vec2 pixelPos = fragTexCoord * screenSize;

    // Calculate exact pixel distance from the center of the effect
    float dist = distance(pixelPos, centerPoint);

    // Dynamic configuration matching your Swift CPU logic
    float circleDistance = 30.0; 
    float speed = 50.0; // Controls how fast the expansion moves (pixels per second)

    // Calculate expanding animation offset based on elapsed time
    float animationOffset = mod(time * speed, circleDistance);

    // Determine if the current pixel lands on one of the repeating rings
    // We check the remainder of the distance divided by our spacing interval
    float ringMap = mod(dist - animationOffset, circleDistance);

    // Create a sharp 1-pixel-wide ring using smoothstep for perfect anti-aliased edges
    float phase = mod(dist - animationOffset, circleDistance);
    float d = abs(phase - circleDistance * 0.5);
    float ringHalfWidth = 0.5;
    float ringAlpha = 1.0 - smoothstep(
        ringHalfWidth,
        ringHalfWidth + 0.5,
        d
    );

    // Calculate brightness attenuation matching your loop logic
    // Rings farther away dynamically shift in brightness/alpha
    float maxDistance = max(screenSize.x - centerPoint.x, centerPoint.x);
    float distanceFactor = dist / maxDistance;
    
    float dynamicBrightness = mix(0.3, 1.0, 1.0 - distanceFactor);

    vec4 finalRingColor = baseColor * fragColor;
    finalRingColor.rgb *= dynamicBrightness;

    // Output final composition: Only display color where a ring exists
    finalColor = vec4(finalRingColor.rgb, ringAlpha * finalRingColor.a);
}
