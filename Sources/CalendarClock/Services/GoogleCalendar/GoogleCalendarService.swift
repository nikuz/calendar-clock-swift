import Foundation
import CRayLib

actor GoogleCalendarService {
    var webhookServer: CalendarWebhookServer?
    private var pollingTask: Task<Void, Error>?
    
    func start(appState: AppState) async throws {
        let ngrokCredentials = try await NgrokCredentials()
        let calendarProvider = try GoogleCalendarAPIClient()
        
        // Initial fetch
        let loadedEvents = try await calendarProvider.fetchEvents()
        appState.update { $0.calendar = .loaded(loadedEvents) }

        #if !DEBUG
        try await calendarProvider.watch(ngrokCredentials: ngrokCredentials)
        // try await calendarProvider.stopWatching()
        #endif
        
        // Setup Webhook Server
        let server = CalendarWebhookServer(port: 8080, ngrokCredentials: ngrokCredentials) { channelId in
            print("Received Google Channel ID: \(channelId)")
            // Note: Ensure this closure is marked @Sendable in the server's definition
            Task {
                do {
                    let newEvents = try await calendarProvider.fetchEvents()
                    appState.update { $0.calendar = .loaded(newEvents) }
                } catch {
                    print("Webhook fetch failed: \(error)")
                }
            }
        }
        
        try server.start()
        self.webhookServer = server
        
        // Setup continuous polling
        self.startPolling(provider: calendarProvider, credentials: ngrokCredentials)
    }
    
    private func startPolling(provider: GoogleCalendarAPIClient, credentials: NgrokCredentials) {
        pollingTask = Task {
            while !Task.isCancelled {
                try await provider.checkWatchChannelsExpiration(ngrokCredentials: credentials)
                try await Task.sleep(for: .seconds(3600)) // one hour
            }
        }
    }
    
    func stop() {
        pollingTask?.cancel()
        webhookServer?.stop()
    }
}