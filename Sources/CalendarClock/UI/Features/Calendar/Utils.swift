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

    typealias EventsNavigation = (
        eventIndex: Int, 
        shift: Float,
        duration: Double,
        startTime: Double,
    )

    enum EventsNavigationDirection {
        case left, right
    }

    static func getEventsNavigation(
        time: TimeInfo,
        events: [CalendarEvent],
        eventsOrder: EventsOrder,
        eventsNavigation: EventsNavigation?,
        direction: EventsNavigationDirection,
    ) -> EventsNavigation? {
        var eventIndex: Int? = nil

        if let eventsNavigation {
            eventIndex = eventsNavigation.eventIndex
            eventIndex! += direction == .left ? -1 : 1
        } else {
            if let activeEvent = eventsOrder.activeEvent {
                eventIndex = activeEvent.index
            } else if let prevEvent = eventsOrder.prevEvent, direction == .left {
                eventIndex = prevEvent.index
            } else if let nextEvent = eventsOrder.nextEvent, direction == .right {
                eventIndex = nextEvent.index
            }
        }

        guard let eventIndex, 
            eventIndex >= 0,
            eventIndex < events.count
        else {
            return eventsNavigation
        }

        let event = events[eventIndex]

        let eventRectangle = getEventRectangle(
            time: time,
            event: event,
        )

        let edgePadding: Float = 30.0
        let duration = 2.0
        let startTime = GetTime()
        let shift = eventsNavigation?.shift ?? 0

        // event is behind the left edge of the screen
        if eventRectangle.x - shift < edgePadding {
            return (
                eventIndex,
                eventRectangle.x - edgePadding,
                duration,
                startTime,
            )
        }
        // event is behind the right edge of the screen
        else if eventRectangle.x - shift + eventRectangle.width > SCREEN_WIDTH - edgePadding {
            return (
                eventIndex,
                (eventRectangle.x + eventRectangle.width) - SCREEN_WIDTH + edgePadding,
                duration,
                startTime,
            )
        } 
        
        // event is already in within visible screen area
        return (
            eventIndex,
            shift: eventsNavigation?.shift ?? 0,
            duration,
            startTime,
        )
    }

    static func getEventRectangle(
        time: TimeInfo, 
        event: CalendarEvent,
        eventsNavigation: EventsNavigation? = nil,
    ) -> Rectangle {
        guard let currentHour = time.components.hour,
            let currentMinute = time.components.minute,
            let eventStartDate = event.start.date,
            let eventEndDate = event.end.date
        else {
            return Rectangle()
        }

        let calendar = Calendar.current
        let timeMargin = round(Utilities.remapValue(
            value: Float(currentHour * 60 + currentMinute),
            inMin: DAY_START_TIME,
            inMax: DAY_END_TIME,
            outMin: 0,
            outMax: (SCREEN_WIDTH * EVENTS_ZOOM) / (EVENTS_ZOOM / (EVENTS_ZOOM - 1)),
        ))

        let startOfToday = calendar.startOfDay(for: Date())

        let startTimeSeconds = eventStartDate.timeIntervalSince1970 - startOfToday.timeIntervalSince1970
        let startPosition = Utilities.remapValue(
            value: Float(startTimeSeconds / 60),
            inMin: DAY_START_TIME,
            inMax: DAY_END_TIME,
            outMin: 0,
            outMax: SCREEN_WIDTH * EVENTS_ZOOM,
        )

        let endTimeSeconds = eventEndDate.timeIntervalSince1970 - startOfToday.timeIntervalSince1970
        let endPosition = Utilities.remapValue(
            value: Float(endTimeSeconds / 60),
            inMin: DAY_START_TIME,
            inMax: DAY_END_TIME,
            outMin: 0,
            outMax: SCREEN_WIDTH * EVENTS_ZOOM
        )

        var xStart = startPosition - timeMargin
        var xEnd = endPosition - timeMargin

        if let eventsNavigation {
            xStart -= eventsNavigation.shift
            xEnd -= eventsNavigation.shift
        }

        return Rectangle(
            x: round(xStart), 
            y: CONTENT_HEIGHT - EVENTS_HEIGHT, 
            width: round(xEnd - xStart), 
            height: EVENTS_HEIGHT
        )
    }
}