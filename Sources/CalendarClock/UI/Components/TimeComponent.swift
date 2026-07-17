import Foundation
import CRayLib

@MainActor
struct TimeComponent {
    static func draw() {
        let now = Date()
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: now)
        var hour = timeComponents.hour ?? 0
        let minute = timeComponents.minute ?? 0

        if hour > 12 {
            hour -= 12
        }

        let text = "\(hour):\(minute)"
        let fontSize: Int32 = 50
        let textWidth = MeasureText(text, fontSize)
        let x = (SCREEN_WIDTH / 2) - (textWidth / 2)
        let y: Int32 = 10

        DrawText(text, x, y, fontSize, COLOR_YELLOW)
    }
}