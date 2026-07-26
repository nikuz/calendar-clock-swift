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
        didSet { processEvents() }
    }
    var confirmedApproachingEventId: String?

    private(set) var positionedEvents: [PositionedCalendarEvent] = []

    private mutating func processEvents() {
        let sanitized = events.map { event in
            if event.summary != nil {
                var updatedEvent = event
                updatedEvent.summary = (event.summary ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacing(/\p{Emoji_Presentation}/, with: "")
                return updatedEvent
            }
            return event
        }

        let sorted = sanitized.sorted {
            guard
                let firstStartDate = $0.start.date,
                let secondStartDate = $1.start.date
            else {
                return false
            }

            return firstStartDate < secondStartDate
        }

        positionedEvents = CalendarEventLayout.calculateHeights(for: sorted)
    }
}

struct PositionedCalendarEvent: Sendable {
    let event: CalendarEvent
    let height: Float
}

private enum CalendarEventLayout {
    static let baseHeight: Float = 100.0
    static let overlapPunishment: Float = 25.0
    static let minHeight: Float = 25.0

    static func calculateHeights(for events: [CalendarEvent]) -> [PositionedCalendarEvent] {
        var result: [PositionedCalendarEvent] = []
        result.reserveCapacity(events.count)

        var prevHeight = baseHeight
        var maxEndDateSoFar: Date?

        for event in events {
            let height: Float
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