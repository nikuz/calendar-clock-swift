import Foundation
import CRayLib

actor GoogleCalendarService {
    private var calendarProvider: GoogleCalendarAPIClient?
    private var ngrokCredentials: NgrokCredentials?
    private var webhookServer: CalendarWebhookServer?
    private var watchChannelsExpirationCheckingTask: Task<Void, Error>?
    private var cachedDate: Date = Date()
    private var watchDateChangeTask: Task<Void, Error>?
    
    func start(appState: AppState) async throws {
        let ngrokCredentials = try await NgrokCredentials()
        self.ngrokCredentials = ngrokCredentials
        let calendarProvider = try GoogleCalendarAPIClient()
        self.calendarProvider = calendarProvider

        try await loadEvents()
        
        #if !DEBUG
            try await calendarProvider.watch(ngrokCredentials: ngrokCredentials)
            // try await calendarProvider.stopWatching()
        #endif
        
        // Setup Webhook Server
        let server = CalendarWebhookServer(port: 8080, ngrokCredentials: ngrokCredentials) { channelId in
            print("Received Google Channel ID: \(channelId)")
            Task {
                do {
                    try await self.loadEvents()
                } catch {
                    print("Webhook fetch failed: \(error)")
                }
            }
        }
        
        try server.start()
        self.webhookServer = server
        
        self.startWatchChannelsExpirationChecking()
        self.startDateChangeChecking()
    }
    
    private func startWatchChannelsExpirationChecking() {
        if let ngrokCredentials {
            watchChannelsExpirationCheckingTask = Task {
                while !Task.isCancelled {
                    try await calendarProvider?.checkWatchChannelsExpiration(ngrokCredentials: ngrokCredentials)
                    try await Task.sleep(for: .seconds(3600)) // one hour
                }
            }
        }
    }
    
    private func startDateChangeChecking() {
        watchDateChangeTask = Task {
            while !Task.isCancelled {
                let calendar = Calendar.current
                let cachedDay = calendar.component(.day, from: cachedDate)
                let currentDay = calendar.component(.day, from: Date())
                if cachedDay != currentDay {
                    try await loadEvents()
                    cachedDate = Date()
                }
                try await Task.sleep(for: .seconds(3600)) // one hour
            }
        }
    }

    private func loadEvents() async throws {
        if let loadedEvents = try await calendarProvider?.fetchEvents() {
            appState.update { state in
                state.calendar.updatePayload { payload in 
                    payload.events = loadedEvents
                }
            }
        }
    }
    
    func stop() {
        watchChannelsExpirationCheckingTask?.cancel()
        watchDateChangeTask?.cancel()
        webhookServer?.stop()
    }
}