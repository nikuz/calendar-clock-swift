import Foundation
import CRayLib

enum CalendarUIUtils {
    typealias TimeInfo = (now: Date, components: DateComponents)

    static func getTime() -> TimeInfo {
        let mousePosition = GetMousePosition()
        var followingMouse = false
        if mousePosition.x > 0 
            && mousePosition.x < SCREEN_WIDTH 
            && mousePosition.y > 0 
            && mousePosition.y < CONTENT_HEIGHT 
        {
            followingMouse = true
        }

        let calendar = Calendar.current
        var now = Date()

        if Bool(followingMouse) {
            let minuteUnderMouseCursor = Utilities.remapValue(
                value: Int(mousePosition.x),
                inMin: 0,
                inMax: Int(SCREEN_WIDTH),
                outMin: 0,
                outMax: 24 * 60 - 1,
            )
            let startOfToday = calendar.startOfDay(for: Date())
            let currentSeconds = calendar.component(.second, from: now)
            let timeWithMinutes = Calendar.current.date(
                byAdding: .minute, 
                value: minuteUnderMouseCursor, 
                to: startOfToday
            ) ?? startOfToday
            now = Calendar.current.date(
                byAdding: .second, 
                value: currentSeconds, 
                to: timeWithMinutes
            ) ?? timeWithMinutes
        }

        return (
            now,
            calendar.dateComponents([.hour, .minute, .second], from: now)
        )
    }

    static func isNightTime(_ time: TimeInfo) -> Bool {
        guard let hour = time.components.hour else {
            return true
        }
        return hour < MORNING_HOUR || hour >= EVENING_HOUR;
    }

    typealias EventsOrder = (
        prev: (index: Int, event: CalendarEvent)?,
        activeEvent: (index: Int, event: CalendarEvent)?,
        nextEvent: (index: Int, event: CalendarEvent)?,
        approachingEvent: (index: Int, event: CalendarEvent)?,
    )

    static func getEventsOrder(
        events: [CalendarEvent], 
        time: TimeInfo,
    ) -> EventsOrder {
        let calendar = Calendar.current
        var prevEvent: (index: Int, event: CalendarEvent)?
        var activeEvent: (index: Int, event: CalendarEvent)?
        var nextEvent: (index: Int, event: CalendarEvent)?
        var approachingEvent: (index: Int, event: CalendarEvent)?

        for (index, event) in events.enumerated() {
            guard let eventStartDate = event.start.date,
                let eventEndDate = event.end.date,
                let eventStartDateMinusOneMinute = calendar.date(byAdding: .minute, value: -1, to: eventStartDate)
            else {
                continue
            }

            if time.now > eventEndDate {
                prevEvent = (index, event)
            } else if time.now >= eventStartDate && time.now <= eventEndDate {
                activeEvent = (index, event)
            } else if time.now >= eventStartDateMinusOneMinute && time.now < eventStartDate {
                approachingEvent = (index, event)
                nextEvent = (index, event)
            } else if time.now < eventStartDateMinusOneMinute && nextEvent == nil {
                nextEvent = (index, event)
            }
        }

        return (
            prevEvent,
            activeEvent,
            nextEvent,
            approachingEvent,
        )
    }
}