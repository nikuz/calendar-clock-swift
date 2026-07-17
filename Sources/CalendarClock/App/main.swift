import Foundation

let appState = AppState()
let calendarService = GoogleCalendarService()

let calendarBackgroundTask = Task.detached {
    do {
        try await calendarService.start(appState: appState)
    } catch {
        print("Calendar setup failed: \(error)")
        appState.update { $0.calendar = .failed(error) }
    }
}

let brightnessBackgroundTask = Task.detached {
    do {
        let provider = try BrightnessProvider(address: .low, mode: .continuousLowRes)
        await provider.startReadingLoop(interval: 0.1) { luxValue in
            if abs(appState.current.brightness - luxValue) > 1.0 {
                appState.update { $0.brightness = luxValue }
            }
        }
    } catch {
        print("BrightnessProvider setup failed: \(error)")
    }
}

let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signal(SIGINT, SIG_IGN)
sigintSource.setEventHandler {
    Task {
        calendarBackgroundTask.cancel()
        await calendarService.stop()
        exit(0)
    }
}
sigintSource.resume()

let renderer = Renderer(appState: appState)
renderer.start()

// normal cleanup
calendarBackgroundTask.cancel()
await calendarService.stop()
brightnessBackgroundTask.cancel()