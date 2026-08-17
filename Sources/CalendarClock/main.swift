import Foundation

private let appState = AppState()
private let hiddenEventsStore = HiddenEventsStore()
private let calendarService = GoogleCalendarService(hiddenEventsStore: hiddenEventsStore)

private let calendarBackgroundTask = Task.detached {
    do {
        try await calendarService.start(appState: appState)
    } catch {
        print("Calendar setup failed: \(error)")
        appState.update { $0.calendar = .failed(error) }
    }
}

private let brightnessBackgroundTask = Task.detached {
    do {
        let provider = try BrightnessProvider(address: .low, mode: .continuousHighRes)
        await provider.startReadingLoop(interval: 0.1) { luxValue in
            if abs(appState.current.brightness.rawValue - luxValue) > 1.0 {
                appState.update { $0.brightness = AppStateBrightness(luxValue) }
            }
        }
    } catch {
        print("BrightnessProvider setup failed: \(error)")
    }
}

private let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signal(SIGINT, SIG_IGN)
sigintSource.setEventHandler {
    Task {
        calendarBackgroundTask.cancel()
        await calendarService.stop()
        hiddenEventsStore.flush()
        exit(0)
    }
}
sigintSource.resume()

private let renderer = Renderer(appState: appState, hiddenEventsStore: hiddenEventsStore)
renderer.start()

// normal cleanup
calendarBackgroundTask.cancel()
await calendarService.stop()
brightnessBackgroundTask.cancel()
hiddenEventsStore.flush()