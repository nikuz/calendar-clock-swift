import Foundation
import GoogleCloudAuth
import NIO

private let serviceAccountFilePath = "config/calendar-gcloud-service-account.json";
private let calendarsFilePath = "config/calendar-ids.json";

private enum GoogleCalendarProviderError: Error {
    case credentialsFileNotFound
    case calendarsFileNotFound
}

actor GoogleCalendarProvider {
    private let authorization: Authorization
    private let eventLoopGroup: EventLoopGroup
    private let calendarIDs: [String]

    init() throws {
        let serviceAccountUrl = URL(fileURLWithPath: serviceAccountFilePath)
        guard FileManager.default.fileExists(atPath: serviceAccountUrl.path) else {
            throw GoogleCalendarProviderError.credentialsFileNotFound
        }

        let provider = try ServiceAccountProvider(credentialsURL: serviceAccountUrl)
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        self.authorization = Authorization(
            scopes: [Scope("https://www.googleapis.com/auth/calendar.readonly")],
            provider: provider,
            eventLoopGroup: eventLoopGroup
        )
        self.eventLoopGroup = eventLoopGroup

        let calendarsUrl = URL(fileURLWithPath: calendarsFilePath)
        guard FileManager.default.fileExists(atPath: calendarsUrl.path) else {
            throw GoogleCalendarProviderError.credentialsFileNotFound
        }
        let jsonData = try Data(contentsOf: calendarsUrl)
        self.calendarIDs = try JSONDecoder().decode([String].self, from: jsonData)
    }

    enum GoogleCalendarProviderError: Error {
        case credentialsFileNotFound
        case invalidResponse
    }

    /// Fetches upcoming events from every calendar in `calendarIDs`, merged into one array
    /// and sorted by start date. All calendars are fetched concurrently.
    func fetchEvents() async throws -> [CalendarEvent] {
        let accessToken = try await authorization.accessToken()

        // withThrowingTaskGroup runs one "child task" per calendar at the same time,
        // instead of waiting for each network request to finish before starting the next.
        // `of: [CalendarEvent].self` says each child task hands back an array of events.
        let allEvents = try await withThrowingTaskGroup(of: [CalendarEvent].self) { group in
            for calendarID in calendarIDs {
                group.addTask {
                    try await self.fetchEvents(calendarID: calendarID, accessToken: accessToken)
                }
            }

            // Collect the results from every child task as they complete.
            var combined: [CalendarEvent] = []
            for try await events in group {
                combined.append(contentsOf: events)
            }
            return combined
        }

        return allEvents.sorted { lhs, rhs in
            (lhs.start.date ?? .distantFuture) < (rhs.start.date ?? .distantFuture)
        }
    }

    /// Fetches events for a single calendar. Kept private since callers should use
    /// `fetchEvents()` to get results across all configured calendars.
    private func fetchEvents(calendarID: String, accessToken: String) async throws -> [CalendarEvent] {
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarID)/events")!
        components.queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: ISO8601DateFormatter().string(from: Date())),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw GoogleCalendarProviderError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
        return decoded.items
    }

    func shutdown() async throws {
        try await authorization.shutdown()
        try await eventLoopGroup.shutdownGracefully()
    }
}