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
        var eventIndex = 0

        if let eventsNavigation {
            eventIndex = eventsNavigation.eventIndex
            eventIndex += direction == .left ? -1 : 1
        } else {
            if let activeEvent = eventsOrder.activeEvent {
                eventIndex = activeEvent.index
            } else if let prevEvent = eventsOrder.prevEvent, direction == .left {
                eventIndex = prevEvent.index
            } else if let nextEvent = eventsOrder.nextEvent, direction == .right {
                eventIndex = nextEvent.index
            }
        }

        if eventIndex < 0 || eventIndex == events.count {
            return eventsNavigation
        }

        let event = events[eventIndex]

        let eventRectangle = getEventRectangle(
            time: time,
            event: event,
            eventsNavigation: eventsNavigation,
        )

        let edgePadding: Float = 30.0
        let duration = 2.0
        let startTime = GetTime()

        var xStart = eventRectangle.x
        var xEnd = eventRectangle.x + eventRectangle.width

        // take raw event position without shift
        if let eventsNavigation {
            xStart += eventsNavigation.shift
            xEnd += eventsNavigation.shift
        }

        // event is behind the left edge of the screen
        if eventRectangle.x < edgePadding {
            return (
                eventIndex,
                xStart - edgePadding,
                duration,
                startTime,
            )
        }
        // event is behind the right edge of the screen
        else if eventRectangle.x + eventRectangle.width > SCREEN_WIDTH - edgePadding {
            return (
                eventIndex,
                xEnd - SCREEN_WIDTH + edgePadding,
                duration,
                startTime,
            )
        } 
        // event is already in within visible screen area
        else if let eventsNavigation {
            return (
                eventIndex,
                shift: eventsNavigation.shift,
                duration,
                startTime,
            )
        }

        return eventsNavigation
    }

    static func getEventRectangle(
        time: TimeInfo, 
        event: CalendarEvent,
        eventsNavigation: EventsNavigation?,
    ) -> Rectangle {
        guard let currentHour = time.components.hour,
            let currentMinute = time.components.minute,
            let eventStartDate = event.start.date,
            let eventEndDate = event.end.date
        else {
            return Rectangle()
        }

        let calendar = Calendar.current
        let timeMargin = Utilities.remapValue(
            value: Float(currentHour * 60 + currentMinute),
            inMin: DAY_START_TIME,
            inMax: DAY_END_TIME,
            outMin: 0,
            outMax: (SCREEN_WIDTH * EVENTS_ZOOM) / (EVENTS_ZOOM / (EVENTS_ZOOM - 1)),
        )

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
        xStart = round(xStart)
        xEnd = round(xEnd)

        var width = round(xEnd - xStart)
        if width.truncatingRemainder(dividingBy: 2.0) != 0.0 {
            width += 1.0
        }
        
        return Rectangle(
            x: xStart, 
            y: CONTENT_HEIGHT - EVENTS_HEIGHT, 
            width: width, 
            height: EVENTS_HEIGHT
        )
    }
}