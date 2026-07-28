import Foundation
import CRayLib

@MainActor
struct CalendarTimeComponent {
    static func draw(
        time: CalendarUIUtils.TimeInfo, 
        appState: AppStateData, 
        eventsOrder: CalendarUIUtils.EventsOrder? = nil,
        eventsNavigation: CalendarUIUtils.EventsNavigation? = nil,
    ) {
        let unscii16Font = UIFonts.getFont(.unscii16)
        let hour = time.components.hour ?? 0
        let minute = time.components.minute ?? 0
        let hour12hFormat = CalendarUIUtils.formatTo12H(hour)
        let isNightTime = CalendarUIUtils.isNightTime(time)
        let fontSize: Float = isNightTime ? 80.0 : 48.0
        let hoursText = String(hour12hFormat)
        let hoursTextSize = MeasureTextEx(unscii16Font, hoursText, fontSize, 0)

        let spacingText = " "
        let spacingTextSize = MeasureTextEx(unscii16Font, spacingText, fontSize, 0)

        let minutesText = String(format: "%02d", minute)
        let minutesTextSize = MeasureTextEx(unscii16Font, minutesText, fontSize, 0)

        let timeText = "\(hoursText)\(spacingText)\(minutesText)"
        let timeTextSize = MeasureTextEx(unscii16Font, timeText, fontSize, 0)
        
        var x = Utilities.remapValue(
            value: Float(hour * 60 + minute),
            inMin: DAY_START_TIME,
            inMax: DAY_END_TIME,
            outMin: 0,
            outMax: SCREEN_WIDTH,
        )

        var navigationShift: Float = 0.0
        if let eventsNavigation {
            navigationShift = eventsNavigation.shift
        }
        x = round(x - navigationShift)

        var textX = x - hoursTextSize.x - spacingTextSize.x / 2
        if navigationShift == 0 {
            textX = max(textX, 0)
            textX = min(textX, SCREEN_WIDTH - timeTextSize.x)
        }
        let textY = isNightTime ? CONTENT_HEIGHT / 2 - timeTextSize.y / 2 : 5.0

        var lineX = x
        if navigationShift == 0 {
            lineX = max(lineX, hoursTextSize.x + spacingTextSize.x / 2)
            lineX = min(lineX, SCREEN_WIDTH - minutesTextSize.x - spacingTextSize.x / 2)
        }

        let brightnessFactor = isNightTime ? appState.brightness.nightFactor : appState.brightness.dayFactor
        var color = ColorBrightness(isNightTime ? .red : .white, brightnessFactor)
        if let activeEvent = eventsOrder?.activeEvent {
            color = ColorBrightness(CALENDAR_EVENT_COLORS[activeEvent.index], brightnessFactor)
        }

        DrawLineV(
            Vector2(x: lineX, y: 0), 
            Vector2(x: lineX, y: CONTENT_HEIGHT), 
            color
        )
        DrawTextEx(unscii16Font, timeText, Vector2(x: textX, y: textY), fontSize, 0, color)
    }
}