import Foundation

// for linux
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

private let serviceAccountFilePath = "config/calendar-gcloud-service-account.json"
private let calendarsFilePath = "config/calendar-ids.json"
private let authTokenFilePath = "temp/auth-token.json"
private let watchChannelsFilePath = "temp/watch-channels.json"
private let IGNORE_EVENTS_SUMMARY = ["busy"]

private enum GoogleCalendarAPIClientError: Error {
    case configFileNotFound
    case configFileCantRead
    case calendarsFileNotFound
    case calendarInvalidResponse
    case cantGetAccessToken
}

actor GoogleCalendarAPIClient {
    private let headers: JWTHeaders
    private let serviceAccountConfig: ServiceAccountConfig
    private let calendarIDs: [String]
    private var accessToken: AccessToken?
    private let accessTokenFileUrl: URL
    private let watchChannelsFileUrl: URL
    private var watchChannels: [String: CalendarWatchChannel] = [:]

    init() throws {
        let fileManager = FileManager.default
        let serviceAccountFileUrl = URL(fileURLWithPath: serviceAccountFilePath)
        guard fileManager.fileExists(atPath: serviceAccountFileUrl.path) else {
            throw GoogleCalendarAPIClientError.configFileNotFound
        }

        let serviceAccountFileContent: String
        do {
            serviceAccountFileContent = try String(contentsOf: serviceAccountFileUrl, encoding: .utf8)
        } catch {
            throw GoogleCalendarAPIClientError.configFileCantRead
        }
        let serviceAccountJsonData = serviceAccountFileContent.data(using: .utf8)!

        let serviceAccountConfigDecoder = JSONDecoder()
        serviceAccountConfigDecoder.keyDecodingStrategy = .convertFromSnakeCase
        self.serviceAccountConfig = try serviceAccountConfigDecoder.decode(ServiceAccountConfig.self, from: serviceAccountJsonData)

        self.headers = JWTHeaders()

        let calendarsUrls = URL(fileURLWithPath: calendarsFilePath)
        guard fileManager.fileExists(atPath: calendarsUrls.path) else {
            throw GoogleCalendarAPIClientError.calendarsFileNotFound
        }
        let calendarsUrlsJsonData = try Data(contentsOf: calendarsUrls)
        self.calendarIDs = try JSONDecoder().decode([String].self, from: calendarsUrlsJsonData)

        // extract saved access token
        self.accessTokenFileUrl = URL.currentDirectory().appendingPathComponent(authTokenFilePath)
        if fileManager.fileExists(atPath: self.accessTokenFileUrl.path) {
            let accessTokenData = try Data(contentsOf: self.accessTokenFileUrl)
            self.accessToken = try JSONDecoder().decode(AccessToken.self, from: accessTokenData)
            print("Extracted stored access token")
        } else {
            print("No access token stored")
        }

        // extract watch channels
        self.watchChannelsFileUrl = URL.currentDirectory().appendingPathComponent(watchChannelsFilePath)
        if fileManager.fileExists(atPath: self.watchChannelsFileUrl.path) {
            let watchChannelsData = try Data(contentsOf: self.watchChannelsFileUrl)
            self.watchChannels = try JSONDecoder().decode([String: CalendarWatchChannel].self, from: watchChannelsData)
            print("Extracted stored watch channels")
        } else {
            print("No watch channels stored")
        }
    }

    func getAccessToken() async throws -> AccessToken? {
        let now = Int(Date().timeIntervalSince1970)

        // return self.token if it is present and still valid
        if self.accessToken != nil,
            let accessToken = self.accessToken,
            accessToken.expiresAt > now + 60 * 5  // expires in more than 5 minutes
        {
            return accessToken
        }

        let payload = JWTPayload(
            iss: self.serviceAccountConfig.clientEmail,
            aud: self.serviceAccountConfig.tokenUri,
            scope: "https://www.googleapis.com/auth/calendar.readonly",
            exp: now + 3600,  // valid for one hour
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

            // store access token
            print("Storing access token at:", self.accessTokenFileUrl)
            let encodedToken = try JSONEncoder().encode(self.accessToken)
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: self.accessTokenFileUrl.path) {
                try encodedToken.write(to: self.accessTokenFileUrl)
            } else {
                try fileManager.createDirectory(
                    at: self.accessTokenFileUrl.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                )
                _ = fileManager.createFile(atPath: self.accessTokenFileUrl.path, contents: encodedToken)
            }
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
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarID)/events")!
        components.queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: formatter.string(from: startOfToday)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: startOfTomorrow)),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw GoogleCalendarAPIClientError.calendarInvalidResponse
        }

        let decoded = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
        return filterEvents(events: decoded.items)
    }

    private func filterEvents(events: [CalendarEvent]) -> [CalendarEvent] {
        var uniqueEvents: [CalendarEvent] = []
        var eventTags: Set<String> = []
        let startOfToday = Calendar.current.startOfDay(for: Date())

        for event in events {
            // canceled event, all day events, and event duplicates
            if event.status == .canceled || eventTags.contains(event.etag) || event.end.dateTime == nil {
                continue
            }
            // outdated events
            if let endDate = event.end.date, endDate < startOfToday {
                continue
            }
            // events with ignored summary
            if let summary = event.summary, IGNORE_EVENTS_SUMMARY.contains(summary.lowercased()) {
                continue
            }
            eventTags.insert(event.etag)
            uniqueEvents.append(event)
        }

        return uniqueEvents
    }

    func watch(ngrokCredentials: NgrokCredentials) async throws {
        let accessToken = try await self.getAccessToken()
        guard let unwrappedAccessToken = accessToken else {
            throw GoogleCalendarAPIClientError.cantGetAccessToken
        }

        var watchChannels: [String: CalendarWatchChannel] = [:]
        try await withThrowingTaskGroup(of: (calendarID: String, channel: CalendarWatchChannel?).self) { group in
            for calendarID in calendarIDs {
                if self.watchChannels[calendarID] == nil {
                    group.addTask {
                        try await self.watch(
                            calendarID: calendarID,
                            accessToken: unwrappedAccessToken.accessToken,
                            ngrokCredentials: ngrokCredentials,
                        )
                    }
                }
            }

            // Collect the results from every child task as they complete.
            for try await item in group {
                if let channel = item.channel {
                    watchChannels[item.calendarID] = channel
                }
            }
        }

        var isEqual = true
        for (calendarId, _) in watchChannels {
            if self.watchChannels[calendarId] == nil {
                isEqual = false
            }
        }
        if !isEqual {
            // store watch channels
            print("Storing watch channels at:", self.watchChannelsFileUrl)
            let encodedWatchChannels = try JSONEncoder().encode(watchChannels)
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: self.watchChannelsFileUrl.path) {
                try encodedWatchChannels.write(to: self.watchChannelsFileUrl)
            } else {
                try fileManager.createDirectory(
                    at: self.watchChannelsFileUrl.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                )
                _ = fileManager.createFile(atPath: self.watchChannelsFileUrl.path, contents: encodedWatchChannels)
            }
        }
    }

    private func watch(
        calendarID: String,
        accessToken: String,
        ngrokCredentials: NgrokCredentials,
    ) async throws -> (calendarID: String, channel: CalendarWatchChannel?) {
        print("Watch ", calendarID)
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarID)/events/watch")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = CalendarWatchPayload(
            id: UUID().uuidString,
            address: ngrokCredentials.domainURL,
            user: ngrokCredentials.user,
            password: ngrokCredentials.password
        )
        let payloadData = try JSONEncoder().encode(payload)

        let (responseBody, response) = try await URLSession.shared.upload(for: request, from: payloadData)

        guard let response = response as? HTTPURLResponse,
            (200...299).contains(response.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        return (
            calendarID: calendarID,
            channel: try JSONDecoder().decode(CalendarWatchChannel.self, from: responseBody)
        )
    }

    func stopWatching() async throws {
        let accessToken = try await self.getAccessToken()
        guard let unwrappedAccessToken = accessToken else {
            throw GoogleCalendarAPIClientError.cantGetAccessToken
        }

        await withThrowingTaskGroup { group in
            for (_, watchChannel) in self.watchChannels {
                group.addTask {
                    try await self.stopWatching(
                        id: watchChannel.id,
                        resourceId: watchChannel.resourceId,
                        accessToken: unwrappedAccessToken.accessToken
                    )
                }
            }
        }

        self.watchChannels = [:]

        // remove watch channels file
        if FileManager.default.fileExists(atPath: self.watchChannelsFileUrl.path) {
            print("Remove watch channels at:", self.watchChannelsFileUrl)
            try FileManager.default.removeItem(at: self.watchChannelsFileUrl)
        }
    }

    private func stopWatching(id: String, resourceId: String, accessToken: String) async throws {
        print("Stop watching ", id)
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/channels/stop")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = CalendarStopWatchingPayload(id: id, resourceId: resourceId)
        let payloadData = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.upload(for: request, from: payloadData)

        guard let response = response as? HTTPURLResponse,
            (200...299).contains(response.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
    }

    func checkWatchChannelsExpiration(ngrokCredentials: NgrokCredentials) async throws {
        let now = Date()
        let oneHourAhead = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        var someIsAlmostExpired = false

        for (_, channel) in self.watchChannels {
            if let expirationMS = Double(channel.expiration) {
                let expirationDate = Date(timeIntervalSince1970: expirationMS / 1000.0)

                if expirationDate < oneHourAhead {
                    someIsAlmostExpired = true
                    break
                }
            }
        }

        if (someIsAlmostExpired) {
            try await self.stopWatching()
            try await self.watch(ngrokCredentials: ngrokCredentials)
        }
    }
}