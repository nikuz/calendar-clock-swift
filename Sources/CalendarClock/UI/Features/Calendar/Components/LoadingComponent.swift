import Foundation
import CRayLib

// Configuration
private let barWidth: Float = 15.0
private let maxBarHeight: Float = 60.0
private let barSpacing: Float = 10.0
private let totalBars = 3

// Calculate layout positioning
private let totalWidth = (barWidth * Float(totalBars)) + (barSpacing * Float(totalBars - 1))
private let startX = (SCREEN_WIDTH - totalWidth) / 2
private let centerY = CONTENT_HEIGHT / 2

@MainActor
struct LoadingComponent {
    static func draw() {
        let time = Float(GetTime())
        
        // Loop through and draw each bar
        for i in 0..<totalBars {
            // Stagger the animation phase for each bar using the loop index
            let phaseShift = Float(i) * 1.2
            let wave = sin(time * 6.0 - phaseShift) // Controls speed and wave effect
            
            // Keep the wave value positive (0.0 to 1.0 range)
            let normalizedWave = (wave + 1.0) / 2.0
            
            // Scale the height dynamically based on the wave
            let currentHeight = maxBarHeight * normalizedWave
            
            // Calculate position so the bars sit flat and bounce upwards
            let xPos = startX + Float(i) * (barWidth + barSpacing)
            let yPos = centerY + (maxBarHeight / 2.0) - currentHeight
            
            DrawRectangle(
                Int32(xPos),
                Int32(yPos),
                Int32(barWidth),
                Int32(currentHeight),
                .maroon
            )
        }
    }
}