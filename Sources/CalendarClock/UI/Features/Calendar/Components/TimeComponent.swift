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
        let color = ColorBrightness(isNightTime ? .red : .white, appState.brightness.factor)
        let hoursText = String(hour12hFormat)
        let hoursTextSize = MeasureTextEx(unscii16Font, hoursText, fontSize, 0)

        let spacingText = " "
        let spacingTextSize = MeasureTextEx(unscii16Font, spacingText, fontSize, 0)

        let minutesText = String(format: "%02d", minute)
        let minutesTextSize = MeasureTextEx(unscii16Font, minutesText, fontSize, 0)

        let timeText = "\(hoursText)\(spacingText)\(minutesText)"
        let timeTextSize = MeasureTextEx(unscii16Font, timeText, fontSize, 0)
        
        let x = Utilities.remapValue(
            value: Float(hour * 60 + minute),
            inMin: DAY_START_TIME,
            inMax: DAY_END_TIME,
            outMin: 0,
            outMax: SCREEN_WIDTH,
        )

        var textX = max(x - hoursTextSize.x - spacingTextSize.x / 2, 0)
        textX = min(textX, SCREEN_WIDTH - timeTextSize.x)
        textX = textX.rounded(.towardZero)
        let textY: Float = isNightTime ? CONTENT_HEIGHT / 2 - timeTextSize.y / 2 : 5.0

        var lineX = max(x, hoursTextSize.x + spacingTextSize.x / 2)
        lineX = min(lineX, SCREEN_WIDTH - minutesTextSize.x - spacingTextSize.x / 2)

        DrawLineV(Vector2(x: lineX, y: 0), Vector2(x: lineX, y: CONTENT_HEIGHT), color)
        DrawTextEx(unscii16Font, timeText, Vector2(x: textX, y: textY), fontSize, 0, color)
    }
}