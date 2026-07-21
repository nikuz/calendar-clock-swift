import Foundation

enum AppStateCalendar: Sendable {
    case loading
    case loaded(CalendarPayload)
    case failed(any Error & Sendable)
    
    mutating func updatePayload(_ transform: (inout CalendarPayload) -> Void) {
        var payload = CalendarPayload()
        
        if case .loaded(let existing) = self {
            payload = existing
        }
        
        transform(&payload)
        self = .loaded(payload)
    }

    var payload: CalendarPayload? {
        if case .loaded(let payload) = self {
            return payload
        }
        return nil
    }

    var confirmedApproachingEventId: String? {
        payload?.confirmedApproachingEventId
    }
    
    var events: [CalendarEvent] {
        payload?.events ?? []
    }
}

struct CalendarPayload: Sendable {
    var events: [CalendarEvent] = [] {
        didSet { recalculateLayout() }
    }
    var confirmedApproachingEventId: String?

    private(set) var positionedEvents: [PositionedCalendarEvent] = []

    private mutating func recalculateLayout() {
        let sorted = events.sorted { 
            guard let firstStartDate = $0.start.date, let secondStartDate = $1.start.date else {
                return false
            }
            return firstStartDate < secondStartDate
        }
        positionedEvents = CalendarEventLayout.calculateHeights(for: sorted)
    }
}

struct PositionedCalendarEvent: Sendable {
    let event: CalendarEvent
    let height: Int
}

private enum CalendarEventLayout {
    static let baseHeight: Int = 100
    static let overlapPunishment: Int = 25
    static let minHeight: Int = 25

    static func calculateHeights(for events: [CalendarEvent]) -> [PositionedCalendarEvent] {
        var result: [PositionedCalendarEvent] = []
        result.reserveCapacity(events.count)

        var prevHeight = baseHeight
        var maxEndDateSoFar: Date?

        for event in events {
            let height: Int
            if let maxEndDateSoFar, let eventStartDate = event.start.date, eventStartDate < maxEndDateSoFar {
                height = max(prevHeight - overlapPunishment, minHeight)
            } else {
                height = baseHeight
            }

            result.append(PositionedCalendarEvent(event: event, height: height))
            prevHeight = height
            if let eventEndDate = event.end.date {
                maxEndDateSoFar = max(maxEndDateSoFar ?? eventEndDate, eventEndDate)
            }
        }

        return result
    }
}