import Foundation

struct CalendarEventsResponse: Decodable, Sendable {
    let items: [CalendarEvent]
}

struct CalendarEvent: Decodable, Identifiable, Sendable {
    let id: String
    let summary: String?  
    let description: String?
    let location: String?
    let start: EventDateTime
    let end: EventDateTime

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
            
            self.dateOnly = decodedDateOnly
            self.dateTime = decodedDateTime
            self.timeZone = try container.decodeIfPresent(String.self, forKey: .timeZone)
            self.isAllDay = (decodedDateOnly != nil)
            
            // Parse using modern, thread-safe value strategies
            if let dt = decodedDateTime {
                self.date = try? Date(dt, strategy: .iso8601)
            } else if let dOnly = decodedDateOnly {
                let ymdStrategy = Date.ParseStrategy(
                    format: "\(year: .defaultDigits)-\(month: .defaultDigits)-\(day: .defaultDigits)",
                    timeZone: TimeZone(identifier: "UTC")!
                )
                self.date = try? Date(dOnly, strategy: ymdStrategy)
            } else {
                self.date = nil
            }
        }
    }
}