import Foundation
import CRayLib

@MainActor
struct TimeComponent {
    static func draw(fonts: [String: Font]) {
        guard let unscii16Font = fonts["unscii16"] else {
            return
        }
        let mousePosition = GetMousePosition()
        #if DEBUG
            let followingMouse = KEY_LEFT_CONTROL.isDown
        #else
            let followingMouse = false
        #endif
        let calendar = Calendar.current

        var now = Date()
        if (followingMouse) {
            let minuteUnderMouseCursor = Utilities.remapValue(
                value: mousePosition.x,
                inMin: 0,
                inMax: SCREEN_WIDTH,
                outMin: 0,
                outMax: 24 * 60,
            )
            let startOfToday = calendar.startOfDay(for: Date())
            now = Calendar.current.date(byAdding: .minute, value: Int(minuteUnderMouseCursor), to: startOfToday)!
        }

        let timeComponents = calendar.dateComponents([.hour, .minute], from: now)
        let hour = timeComponents.hour ?? 0
        let minute = timeComponents.minute ?? 0
        var hour12hFormat = hour

        if hour12hFormat > 12 {
            hour12hFormat -= 12
        }

        let fontSize: Float = 50.0
        let hoursText = String(hour12hFormat)
        let hoursWidth = MeasureTextEx(unscii16Font, hoursText, fontSize, 1)

        let spacingText = " "
        let spacingWidth = MeasureTextEx(unscii16Font, spacingText, fontSize, 1)

        let minutesText = String(format: "%02d", minute)

        let timeText = "\(hoursText)\(spacingText)\(minutesText)"
        let timeTextWidth = MeasureTextEx(unscii16Font, timeText, fontSize, 1)
        
        var x: Float

        if followingMouse {
            x = Utilities.remapValue(
                value: mousePosition.x,
                inMin: 0,
                inMax: SCREEN_WIDTH,
                outMin: 0,
                outMax: SCREEN_WIDTH,
            )
        } else {
            x = 0.0
            x = Utilities.remapValue(
                value: Float(hour * 60 + minute),
                inMin: 0,
                inMax: 24 * 60, // minutes per day
                outMin: 0,
                outMax: SCREEN_WIDTH,
            )
        }

        x = max(x - (timeTextWidth.x / 2), 0)
        x = min(x, SCREEN_WIDTH - timeTextWidth.x)

        let lineX = x + hoursWidth.x + spacingWidth.x / 2
        DrawLineV(Vector2(x: lineX, y: 0), Vector2(x: lineX, y: CONTENT_HEIGHT), .yellow)
        DrawTextEx(unscii16Font, timeText, Vector2(x: x, y: 10), fontSize, 1, .yellow)
    }
}