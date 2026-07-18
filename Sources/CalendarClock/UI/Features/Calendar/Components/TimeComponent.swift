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
                outMax: 24 * 60 - 1,
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

        let fontSize: Float = 48.0
        let hoursText = String(hour12hFormat)
        let hoursWidth = MeasureTextEx(unscii16Font, hoursText, fontSize, 0)

        let spacingText = " "
        let spacingWidth = MeasureTextEx(unscii16Font, spacingText, fontSize, 0)

        let minutesText = String(format: "%02d", minute)

        let timeText = "\(hoursText)\(spacingText)\(minutesText)"
        let timeTextWidth = MeasureTextEx(unscii16Font, timeText, fontSize, 0)
        
        var x = Utilities.remapValue(
            value: Float(hour * 60 + minute),
            inMin: DAY_START_TIME,
            inMax: DAY_END_TIME,
            outMin: 0,
            outMax: SCREEN_WIDTH,
        )

        x = max(x - hoursWidth.x, 0)
        x = min(x, SCREEN_WIDTH - timeTextWidth.x)
        x = x.rounded(.towardZero)

        let lineX = x + hoursWidth.x + spacingWidth.x / 2
        DrawLineV(Vector2(x: lineX, y: 0), Vector2(x: lineX, y: CONTENT_HEIGHT), .yellow)
        DrawTextEx(unscii16Font, timeText, Vector2(x: x, y: 10), fontSize, 0, .yellow)
    }
}