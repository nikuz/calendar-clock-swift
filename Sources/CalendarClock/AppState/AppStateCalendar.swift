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

    var dayEvents: [CalendarDayEvent] {
        payload?.dayEvents ?? []
    }
}

struct CalendarPayload: Sendable {
    var events: [CalendarEvent] = [] {
        didSet { processEvents() }
    }
    /// Ids of the events the user hid for the current day. Hidden events keep
    /// their place in `dayEvents` so the navigation can still reach them, but
    /// they take no part in the layout of the visible ones.
    var hiddenEventIds: Set<String> = [] {
        didSet {
            if hiddenEventIds != oldValue {
                processEvents()
            }
        }
    }
    var loadTime: Double = Date().timeIntervalSince1970
    var confirmedApproachingEventId: String?

    private(set) var dayEvents: [CalendarDayEvent] = []
    /// Bumped every time `dayEvents` is rebuilt. The UI keeps the event cards
    /// between the frames and uses the revision to tell when the cards and
    /// everything derived from them have to be built again.
    private(set) var eventsRevision: UInt64 = 0

    var visibleEvents: [CalendarEvent] {
        dayEvents.lazy.filter { !$0.isHidden }.map(\.event)
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

        dayEvents = sorted.map { event in
            CalendarDayEvent(event: event, isHidden: hiddenEventIds.contains(event.id))
        }
        eventsRevision &+= 1
    }
}

struct CalendarDayEvent: Sendable {
    let event: CalendarEvent
    /// The user hid the event, it is drawn as a thin line at the bottom of the screen.
    let isHidden: Bool
}
