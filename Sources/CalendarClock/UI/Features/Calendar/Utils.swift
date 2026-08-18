import Foundation
import CRayLib

enum CalendarUIUtils {
    struct TimeInfo {
        let now: Date
        let startOfDay: Date
        let hour: Int
        let minute: Int
        let second: Int

        var totalMinutes: Int {
            hour * 60 + minute
        }
    }

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
        let startOfToday = calendar.startOfDay(for: now)

        if Bool(followingMouse) {
            let minuteUnderMouseCursor = Utilities.remapValue(
                value: Int(mousePosition.x),
                inMin: 0,
                inMax: Int(SCREEN_WIDTH),
                outMin: 0,
                outMax: 24 * 60 - 1,
            )
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

        return TimeInfo(
            now: now,
            startOfDay: startOfToday,
            hour: calendar.component(.hour, from: now),
            minute: calendar.component(.minute, from: now),
            second: calendar.component(.second, from: now),
        )
    }

    static func isNightTime(_ time: TimeInfo) -> Bool {
        return time.hour < MORNING_HOUR || time.hour >= EVENING_HOUR;
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
        events: [CalendarDayEvent],
        time: TimeInfo,
    ) -> EventsOrder {
        let calendar = Calendar.current
        var prevEvent: (index: Int, event: CalendarEvent)?
        var activeEvent: (index: Int, event: CalendarEvent)?
        var nextEvent: (index: Int, event: CalendarEvent)?
        var approachingEvent: (index: Int, event: CalendarEvent)?

        for (index, dayEvent) in events.enumerated() {
            // a hidden event never becomes the active, the approaching, the next
            // or the previous one: it doesn't flash, ring or move the time line
            guard !dayEvent.isHidden else {
                continue
            }

            let event = dayEvent.event

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

    /// The event the arrows start from when the navigation is not active yet.
    /// Deliberately built from the whole day instead of `getEventsOrder`, which
    /// leaves the hidden events out: hiding an event must not change the order
    /// the navigation walks through them.
    static func getNavigationStartIndex(
        events: [CalendarDayEvent],
        time: TimeInfo,
        direction: EventsNavigationDirection,
    ) -> Int? {
        var activeEventIndex: Int?
        var prevEventIndex: Int?
        var nextEventIndex: Int?

        for (index, dayEvent) in events.enumerated() {
            guard let eventStartDate = dayEvent.event.start.date,
                let eventEndDate = dayEvent.event.end.date
            else {
                continue
            }

            if time.now > eventEndDate {
                prevEventIndex = index
            } else if time.now >= eventStartDate {
                activeEventIndex = index
            } else if nextEventIndex == nil {
                nextEventIndex = index
            }
        }

        if let activeEventIndex {
            return activeEventIndex
        }

        return direction == .left ? prevEventIndex : nextEventIndex
    }

    /// Moves the highlight one event to the left or to the right. Hidden events
    /// are walked over like any other one, that is the only way back to them.
    static func getEventsNavigation(
        time: TimeInfo,
        events: [CalendarDayEvent],
        eventsNavigation: EventsNavigation?,
        direction: EventsNavigationDirection,
    ) -> EventsNavigation? {
        var eventIndex: Int? = nil

        if let eventsNavigation {
            eventIndex = eventsNavigation.eventIndex
            eventIndex! += direction == .left ? -1 : 1
        } else {
            eventIndex = getNavigationStartIndex(events: events, time: time, direction: direction)
        }

        guard let eventIndex, 
            eventIndex >= 0,
            eventIndex < events.count
        else {
            return eventsNavigation
        }

        let event = events[eventIndex].event

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

    /// Position of an event on the day timeline, in pixels, before the current
    /// time and the navigation shift are applied. Only depends on the event
    /// dates, so it can be calculated once instead of on every frame.
    struct EventPosition {
        let start: Float
        let end: Float

        var width: Float {
            end - start
        }
    }

    static func getEventPosition(event: CalendarEvent, startOfDay: Date) -> EventPosition? {
        guard let eventStartDate = event.start.date,
            let eventEndDate = event.end.date
        else {
            return nil
        }

        let startTimeSeconds = eventStartDate.timeIntervalSince1970 - startOfDay.timeIntervalSince1970
        let startPosition = Utilities.remapValue(
            value: Float(startTimeSeconds / 60),
            inMin: DAY_START_TIME,
            inMax: DAY_END_TIME,
            outMin: 0,
            outMax: SCREEN_WIDTH * EVENTS_ZOOM,
        )

        let endTimeSeconds = eventEndDate.timeIntervalSince1970 - startOfDay.timeIntervalSince1970
        let endPosition = Utilities.remapValue(
            value: Float(endTimeSeconds / 60),
            inMin: DAY_START_TIME,
            inMax: DAY_END_TIME,
            outMin: 0,
            outMax: SCREEN_WIDTH * EVENTS_ZOOM
        )

        return EventPosition(start: startPosition, end: endPosition)
    }

    /// Horizontal offset of the whole timeline for the given time.
    static func getTimeMargin(time: TimeInfo) -> Float {
        return Utilities.remapValue(
            value: Float(time.totalMinutes),
            inMin: DAY_START_TIME,
            inMax: DAY_END_TIME,
            outMin: 0,
            outMax: (SCREEN_WIDTH * EVENTS_ZOOM) / (EVENTS_ZOOM / (EVENTS_ZOOM - 1)),
        )
    }

    static func getEventRectangle(
        time: TimeInfo,
        event: CalendarEvent,
        eventsNavigation: EventsNavigation? = nil,
    ) -> Rectangle {
        guard let position = getEventPosition(event: event, startOfDay: time.startOfDay) else {
            return Rectangle()
        }

        let xStart = position.start - getTimeMargin(time: time) - (eventsNavigation?.shift ?? 0)

        return Rectangle(
            x: round(xStart),
            y: CONTENT_HEIGHT - EVENTS_HEIGHT,
            width: round(position.width),
            height: EVENTS_HEIGHT
        )
    }
}