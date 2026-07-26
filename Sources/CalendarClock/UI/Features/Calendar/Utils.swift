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

    static func formatTo12H(_ hour: Int) -> Int {
        var hour12hFormat = hour
        if hour12hFormat > 12 {
            hour12hFormat -= 12
        }
        return hour12hFormat
    }

    typealias EventsOrder = (
        prevEvent: (index: Int, event: CalendarEvent)?,
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

    typealias EventsNavigation = (activeEventIndex: Int, shift: Int32)

    static func getEventsNavigation(
        _ time: TimeInfo,
        _ eventOrderData: (index: Int, event: CalendarEvent)?
    ) -> EventsNavigation? {
        guard let currentHour = time.components.hour,
            let currentMinute = time.components.minute,
            let eventIndex = eventOrderData?.index,
            let event = eventOrderData?.event,
            let eventStartDate = event.start.date,
            let eventEndDate = event.end.date
        else {
            return nil
        }

        let timeMargin = Utilities.remapValue(
            value: Int32(currentHour * 60 + currentMinute),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32((SCREEN_WIDTH * EVENTS_ZOOM) / (EVENTS_ZOOM / (EVENTS_ZOOM - 1))),
        )

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let startTimeSeconds = eventStartDate.timeIntervalSince1970 - startOfToday.timeIntervalSince1970
        let startPosition = Utilities.remapValue(
            value: Int32(startTimeSeconds / 60),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM),
        )

        let endTimeSeconds = eventEndDate.timeIntervalSince1970 - startOfToday.timeIntervalSince1970
        let endPosition = Utilities.remapValue(
            value: Int32(endTimeSeconds / 60),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM)
        )

        let xStart = startPosition - timeMargin
        let xEnd = endPosition - timeMargin
        let screenWidth = Int32(SCREEN_WIDTH)
        let edgePadding: Int32 = 30

        // event is behind the left edge of the screen
        if xStart < edgePadding {
            return (
                eventIndex,
                xStart - edgePadding
            )
        }

        // event is behind the right edge of the screen
        if xEnd > screenWidth - edgePadding {
            return (
                eventIndex,
                xEnd - screenWidth + edgePadding
            )
        }

        return (eventIndex, 0)
    }
}