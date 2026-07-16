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
    let provider = BrightnessProvider(address: .low, mode: .continuousLowRes)
    await provider.startReadingLoop(interval: 0.1) { luxValue in
        print(luxValue)
        appState.update { $0.brightness = luxValue }
    }
}

let renderer = Renderer(appState: appState)
renderer.start()

// cleanup
calendarBackgroundTask.cancel()
await calendarService.stop()
brightnessBackgroundTask.cancel()