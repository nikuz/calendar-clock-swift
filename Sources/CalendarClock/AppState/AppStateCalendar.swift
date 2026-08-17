import Foundation

enum AppStateCalendar: Sendable {
    case loading
    case loaded(CalendarPayload)
    case failed(any Error & Sendable)

    mutating func updatePayload(_ transform: (inout CalendarPayload) -> Void) {
        var payload = CalendarPayload(
            loadTime: Date().timeIntervalSince1970,
        )

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

    var positionedEvents: [PositionedCalendarEvent] {
        payload?.positionedEvents ?? []
    }
}

struct CalendarPayload: Sendable {
    var events: [CalendarEvent] = [] {
        didSet { processEvents() }
    }
    /// Ids of the events the user hid for the current day. Hidden events keep
    /// their place in `positionedEvents` so the navigation can still reach them,
    /// but they take no part in the layout of the visible ones.
    var hiddenEventIds: Set<String> = [] {
        didSet {
            if hiddenEventIds != oldValue {
                processEvents()
            }
        }
    }
    var loadTime: Double = Date().timeIntervalSince1970
    var confirmedApproachingEventId: String?

    private(set) var positionedEvents: [PositionedCalendarEvent] = []
    /// Bumped every time `positionedEvents` is rebuilt. The UI keeps the event
    /// cards between the frames and uses the revision to tell when the cards and
    /// everything derived from them have to be built again.
    private(set) var layoutRevision: UInt64 = 0

    var visibleEvents: [CalendarEvent] {
        positionedEvents.lazy.filter { !$0.isHidden }.map(\.event)
    }

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

        positionedEvents = CalendarEventLayout.calculateHeights(for: sorted, hiddenEventIds: hiddenEventIds)
        layoutRevision &+= 1
    }
}

struct PositionedCalendarEvent: Sendable {
    let event: CalendarEvent
    let height: Float
    /// The user hid the event, it is only drawn as a thin line while navigating.
    let isHidden: Bool
}

private enum CalendarEventLayout {
    static let baseHeight: Float = 100.0
    static let overlapPunishment: Float = 25.0
    static let minHeight: Float = 25.0

    static func calculateHeights(
        for events: [CalendarEvent],
        hiddenEventIds: Set<String>,
    ) -> [PositionedCalendarEvent] {
        var result: [PositionedCalendarEvent] = []
        result.reserveCapacity(events.count)

        var prevHeight = baseHeight
        var maxEndDateSoFar: Date?

        for event in events {
            // a hidden event is drawn as a thin line: it neither overlaps the
            // visible events nor is punished for being overlapped by them
            if hiddenEventIds.contains(event.id) {
                result.append(PositionedCalendarEvent(event: event, height: minHeight, isHidden: true))
                continue
            }

            let height: Float
            if let maxEndDateSoFar, let eventStartDate = event.start.date, eventStartDate < maxEndDateSoFar {
                height = max(prevHeight - overlapPunishment, minHeight)
            } else {
                height = baseHeight
            }

            result.append(PositionedCalendarEvent(event: event, height: height, isHidden: false))
            prevHeight = height
            if let eventEndDate = event.end.date {
                maxEndDateSoFar = max(maxEndDateSoFar ?? eventEndDate, eventEndDate)
            }
        }

        return result
    }
}
