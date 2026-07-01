import Foundation

/// Matches the top-level response from `GET /calendars/{calendarId}/events`.
/// Google wraps the actual event list inside an "items" array — this struct exists
/// purely so JSONDecoder has something to decode the whole response into.
struct CalendarEventsResponse: Decodable {
    let items: [CalendarEvent]
}

/// One event from the Google Calendar API.
/// Only the fields you're likely to actually use are modeled — the real API response
/// has many more (attendees, recurrence, colorId, etc.). Add fields here as you need them.
struct CalendarEvent: Decodable, Identifiable {
    let id: String
    let summary: String?  // event title — optional because Google allows untitled events
    let description: String?
    let location: String?
    let start: EventDateTime
    let end: EventDateTime

    /// Google represents a date/time two different ways depending on whether the event
    /// is all-day or has a specific time:
    ///   - all-day event:  { "date": "2026-07-04" }
    ///   - timed event:    { "dateTime": "2026-07-04T09:00:00-07:00", "timeZone": "America/Los_Angeles" }
    /// This struct captures both possibilities; `date` decodes it into a single Swift `Date`
    /// so the rest of your code doesn't need to care which case it was.
    struct EventDateTime: Decodable {
        let dateOnly: String?
        let dateTime: String?
        let timeZone: String?

        enum CodingKeys: String, CodingKey {
            case dateOnly = "date"
            case dateTime
            case timeZone
        }

        /// True if this represents an all-day event rather than a specific time.
        var isAllDay: Bool {
            dateOnly != nil
        }

        /// The parsed Swift `Date`, regardless of which of the two formats Google sent.
        var date: Date? {
            if let dateTime {
                return ISO8601DateFormatter().date(from: dateTime)
            }
            if let dateOnly {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone(identifier: "UTC")
                return formatter.date(from: dateOnly)
            }
            return nil
        }
    }
}