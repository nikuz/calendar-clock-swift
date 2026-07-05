import Foundation
import Security

private let serviceAccountFilePath = "config/calendar-gcloud-service-account.json"
private let calendarsFilePath = "config/calendar-ids.json"

private enum GoogleCalendarProviderError: Error {
    case configFileNotFound
    case configFileCantRead
    case calendarsFileNotFound
    case calendarInvalidResponse
}

actor GoogleCalendarProvider {
    private let headers: JWTHeaders
    private let serviceAccountConfig: ServiceAccountConfig
    private let calendarIDs: [String]
    private var accessToken: AccessToken?

    init() throws {
        let serviceAccountFileUrl = URL(fileURLWithPath: serviceAccountFilePath)
        guard FileManager.default.fileExists(atPath: serviceAccountFileUrl.path) else {
            throw GoogleCalendarProviderError.configFileNotFound
        }

        let serviceAccountFileContent: String
        do {
            serviceAccountFileContent = try String(contentsOf: serviceAccountFileUrl, encoding: .utf8)
        } catch {
            throw GoogleCalendarProviderError.configFileCantRead
        }
        let serviceAccountJsonData = serviceAccountFileContent.data(using: .utf8)!

        let serviceAccountConfigDecoder = JSONDecoder()
        serviceAccountConfigDecoder.keyDecodingStrategy = .convertFromSnakeCase
        self.serviceAccountConfig = try serviceAccountConfigDecoder.decode(ServiceAccountConfig.self, from: serviceAccountJsonData)

        self.headers = JWTHeaders()

        let calendarsUrl = URL(fileURLWithPath: calendarsFilePath)
        guard FileManager.default.fileExists(atPath: calendarsUrl.path) else {
            throw GoogleCalendarProviderError.calendarsFileNotFound
        }
        let jsonData = try Data(contentsOf: calendarsUrl)
        self.calendarIDs = try JSONDecoder().decode([String].self, from: jsonData)
    }

    func getAccessToken() async throws -> AccessToken? {
        let now = Int(Date().timeIntervalSince1970)

        // return self.token if it is present and still valid
        if self.accessToken != nil,
            let accessToken = self.accessToken,
            accessToken.expiresAt > now + 60 * 5  // expires in more than 5 minutes
        {
            return self.accessToken
        }

        let payload = JWTPayload(
            iss: self.serviceAccountConfig.clientEmail,
            aud: self.serviceAccountConfig.tokenUri,
            scope: "https://www.googleapis.com/auth/calendar.readonly",
            exp: now + 3600, // valid for one hour
            iat: now
        )

        let payloadBase64String = try CalendarUtils.encodeJSON(payload)
        let headersBase64String = try CalendarUtils.encodeJSON(self.headers)
        let signingInput = "\(headersBase64String).\(payloadBase64String)"

        let signature = try CalendarUtils.signRS256(
            signingInput,
            privateKeyPEM: serviceAccountConfig.privateKey
        )

        let jwtString = "\(signingInput).\(CalendarUtils.base64URLEncode(signature))"
        print(jwtString)

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:jwt-bearer"),
            URLQueryItem(name: "assertion", value: jwtString),
        ]
        let requestBody = Data((components.query ?? "").utf8)

        do {
            let (responseBody, response) = try await URLSession.shared.upload(for: request, from: requestBody)
 
            guard let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode)
            else {
                throw URLError(.badServerResponse)
            }

            let responseDecoder = JSONDecoder()
            responseDecoder.keyDecodingStrategy = .convertFromSnakeCase

            self.accessToken = try responseDecoder.decode(AccessToken.self, from: responseBody)
        } catch let error as NSError {
            print("\(error.code): \(error)")
        }

        return self.accessToken
    }

    /// Fetches upcoming events from every calendar in `calendarIDs`, merged into one array
    /// and sorted by start date. All calendars are fetched concurrently.
    func fetchEvents() async throws -> [CalendarEvent] {
        let accessToken = try await self.getAccessToken()

        guard let unwrappedAccessToken = accessToken else {
            print("Can't fetch calendar events without access token")
            return []
        }

        print(unwrappedAccessToken.expiresAt)

        // withThrowingTaskGroup runs one "child task" per calendar at the same time,
        // instead of waiting for each network request to finish before starting the next.
        // `of: [CalendarEvent].self` says each child task hands back an array of events.
        let allEvents = try await withThrowingTaskGroup(of: [CalendarEvent].self) { group in
            for calendarID in calendarIDs {
                group.addTask {
                    try await self.fetchEvents(calendarID: calendarID, accessToken: unwrappedAccessToken.accessToken)
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
            throw GoogleCalendarProviderError.calendarInvalidResponse
        }

        let decoded = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
        return decoded.items
    }
}