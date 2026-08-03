import Foundation

struct CalendarEventsResponse: Decodable, Sendable {
    let items: [CalendarEvent]
}

struct CalendarEvent: Decodable, Identifiable, Sendable {
    let id: String
    var summary: String?  
    let description: String?
    let location: String?
    let start: EventDateTime
    let end: EventDateTime
    let etag: String
    let status: CalendarEventStatus
    let transparency: CalendarEventTransparency?

    var isAllDay: Bool {
        if start.dateOnly != nil || end.dateOnly != nil {
            return true
        }

        guard let startDate = start.date,
              let endDate = end.date else {
            return false
        }

        let timeZone = start.timeZone.flatMap(TimeZone.init(identifier:))
            ?? end.timeZone.flatMap(TimeZone.init(identifier:))
            ?? .current

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let startOfDay = calendar.startOfDay(for: startDate)
        let nextStartOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)

        return startDate == startOfDay && endDate == nextStartOfDay
    }

    enum CalendarEventStatus: String, Decodable, Sendable {
        case confirmed, tentative, canceled
    }
    
    enum CalendarEventTransparency: String, Decodable, Sendable {
        case opaque, transparent
    }

    struct EventDateTime: Decodable {
        let dateOnly: String?
        let dateTime: String?
        let timeZone: String?

        let isAllDay: Bool
        let date: Date?

        enum CodingKeys: String, CodingKey {
            case dateOnly = "date"
            case dateTime
            case timeZone
        }

        private static let ymdFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter
        }()
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let decodedDateOnly = try container.decodeIfPresent(String.self, forKey: .dateOnly)
            let decodedDateTime = try container.decodeIfPresent(String.self, forKey: .dateTime)
            let decodedTimeZone = try container.decodeIfPresent(String.self, forKey: .timeZone)

            self.dateOnly = decodedDateOnly
            self.dateTime = decodedDateTime
            self.timeZone = decodedTimeZone

            let parsedDate: Date?
            if let dt = decodedDateTime {
                parsedDate = try? Date(dt, strategy: .iso8601)
            } else if let dOnly = decodedDateOnly {
                let ymdStrategy = Date.ParseStrategy(
                    format: "\(year: .defaultDigits)-\(month: .defaultDigits)-\(day: .defaultDigits)",
                    timeZone: TimeZone(identifier: "UTC")!
                )
                parsedDate = try? Date(dOnly, strategy: ymdStrategy)
            } else {
                parsedDate = nil
            }

            self.date = parsedDate

            let timeZone = decodedTimeZone.flatMap(TimeZone.init(identifier:)) ?? .current
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone

            let isMidnightDate = parsedDate.map { calendar.startOfDay(for: $0) == $0 } ?? false
            self.isAllDay = decodedDateOnly != nil || isMidnightDate
        }
    }
}