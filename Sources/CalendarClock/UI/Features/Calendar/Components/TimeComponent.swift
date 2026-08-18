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
        let hour = time.hour
        let minute = time.minute
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
        
        var navigationShift: Float = 0.0
        if let eventsNavigation {
            navigationShift = round(eventsNavigation.shift)
        }

        // built out of the same whole pixel values the event cards are built out of,
        // so the line continues into the left border of an event starting right now
        // rather than landing a pixel next to it
        let x = CalendarUIUtils.getTimePosition(time: time)
            - CalendarUIUtils.getTimeMargin(time: time)
            - navigationShift

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
            lineX = round(lineX)
        }

        let brightnessFactor = isNightTime ? appState.brightness.nightFactor : appState.brightness.dayFactor
        var color = ColorBrightness(isNightTime ? .red : .white, brightnessFactor)
        if let activeEvent = eventsOrder?.activeEvent {
            color = ColorBrightness(CALENDAR_EVENT_COLORS[activeEvent.index], brightnessFactor)
        }

        // a rectangle rather than a line: a 1px GL line on a whole x sits on the seam
        // between two pixel columns, and this one has to fill exactly the column the
        // event border continues from
        DrawRectangleV(
            Vector2(x: lineX, y: 0),
            Vector2(x: 1, y: CONTENT_HEIGHT),
            color
        )
        DrawTextEx(unscii16Font, timeText, Vector2(x: textX, y: textY), fontSize, 0, color)
    }
}