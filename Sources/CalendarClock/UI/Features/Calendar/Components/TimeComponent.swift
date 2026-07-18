import Foundation
import CRayLib

@MainActor
struct CalendarTimeComponent {
    static func draw(time: DateComponents, appState: AppStateData) {
        let unscii16Font = UIFonts.getFont(.unscii16)
        let hour = time.hour ?? 0
        let minute = time.minute ?? 0
        var hour12hFormat = hour

        if hour12hFormat > 12 {
            hour12hFormat -= 12
        }

        let isNightTime = CalendarUIUtils.isNightTime(time)
        let fontSize: Float = isNightTime ? 80.0 : 48.0
        let color: Color = ColorBrightness(isNightTime ? .red : .white, appState.brightness.factor)
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
        DrawLineV(Vector2(x: lineX, y: 0), Vector2(x: lineX, y: CONTENT_HEIGHT), color)
        DrawTextEx(unscii16Font, timeText, Vector2(x: x, y: 10), fontSize, 0, color)
    }
}