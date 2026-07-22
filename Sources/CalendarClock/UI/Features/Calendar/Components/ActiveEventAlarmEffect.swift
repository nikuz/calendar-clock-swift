import Foundation
import CRayLib

@MainActor private var expansionRadius: Int32 = 0
@MainActor private var lastRadiusExtensionTime: Double = 0

@MainActor
struct ActiveEventAlarmEffect {
    static func draw(
        time: CalendarUIUtils.TimeInfo, 
        appState: AppStateData, 
        eventsOrder: CalendarUIUtils.EventsOrder,
    ) {
        guard let activeEvent = eventsOrder.activeEvent,
            activeEvent.event.id != appState.calendar.confirmedApproachingEventId,
            let currentHour = time.components.hour,
            let currentMinute = time.components.minute,
            let activeEventStartDate = activeEvent.event.start.date,
            let activeEventEndDate = activeEvent.event.end.date
        else {
            if expansionRadius != 0 { expansionRadius = 0 }
            return
        }

        let calendar = Calendar.current
        let currentTime = currentHour * 60 + currentMinute
        let marginLeft = Utilities.remapValue(
            value: Int32(currentTime),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32((SCREEN_WIDTH * EVENTS_ZOOM) / (EVENTS_ZOOM / (EVENTS_ZOOM - 1))),
        )
        let activeEventStartHour = calendar.component(.hour, from: activeEventStartDate)
        let activeEventStartMinute = calendar.component(.minute, from: activeEventStartDate)
        let activeEventStartTime = activeEventStartHour * 60 + activeEventStartMinute
        let startPosition = Utilities.remapValue(
            value: Int32(activeEventStartTime),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM),
        )
        let activeEventEndHour = calendar.component(.hour, from: activeEventEndDate)
        let activeEventEndMinute = calendar.component(.minute, from: activeEventEndDate)
        let activeEventEndTime = activeEventEndHour * 60 + activeEventEndMinute
        let endPosition = Utilities.remapValue(
            value: Int32(activeEventEndTime),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM)
        )

        let x = startPosition - marginLeft + (endPosition - startPosition) / 2
        let y = SCREEN_HEIGHT - (SCREEN_HEIGHT - EVENTS_HEIGHT) / 2
        let circleDistance: Int32 = 30
        let circlesAmount = max(Int32(SCREEN_WIDTH) - x, x) / circleDistance + 1

        var brightnessFactor = appState.brightness.dayFactor
        for index in 1...circlesAmount {
            let radius = Float(index * circleDistance) + Float(expansionRadius)
            let itemColor = ColorBrightness(CALENDAR_EVENT_COLORS[activeEvent.index], brightnessFactor)
            DrawRingLines(Vector2(x: Float(x), y: y), radius, radius + 1, 0, 360, 100, itemColor)
            brightnessFactor -= 0.03
        }

        let curRenderingTime = GetTime()

        if curRenderingTime - lastRadiusExtensionTime >= 0.02 {
            expansionRadius += 1
            lastRadiusExtensionTime = curRenderingTime
        }
        if expansionRadius == circleDistance {
            expansionRadius = 0
        }
    }
}