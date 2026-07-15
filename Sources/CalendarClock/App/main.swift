import Foundation
import CRayLib

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
    let provider = BrightnessProvider(address: .low, mode: .continuousHighRes)
    provider.startPrintingLoop(interval: 1.0)
}

let configFlags = FLAG_WINDOW_UNDECORATED.rawValue | FLAG_WINDOW_RESIZABLE.rawValue
SetConfigFlags(configFlags)

InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "")
SetTargetFPS(60)

while !WindowShouldClose() && !KEY_Q.isPressed {
    BeginDrawing()
    ClearBackground(COLOR_BLACK)

    let text = "Calendar Clock"
    let fontSize: Int32 = 20
    let textWidth = MeasureText(text, fontSize)
    let x = (SCREEN_WIDTH / 2) - (textWidth / 2)
    let y = (CONTENT_HEIGHT / 2) - (fontSize / 2)

    DrawText(text, x, y, fontSize, COLOR_YELLOW)

    switch appState.current.calendar {
    case .loading:
        let loadingText = "Loading events..."
        let loadingTextWidth = MeasureText(loadingText, 18)
        let loadingX = (SCREEN_WIDTH / 2) - (loadingTextWidth / 2)
        DrawText(loadingText, loadingX, y + 40, 18, COLOR_WHITE)

    case .loaded(let events):
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        for (index, event) in events.enumerated() {
            let summary = event.summary ?? "(untitled)"
            let dateString: String
            if let date = event.start.date {
                dateString = formatter.string(from: date)
            } else {
                dateString = "unknown date"
            }
            let eventText = "\(summary) — \(dateString)"
            DrawText(eventText, 20, Int32(80 + index * 20), 16, COLOR_WHITE)
        }

    case .failed(let error):
        let errorText = "Failed to load events: \(error.localizedDescription)"
        let errorTextWidth = MeasureText(errorText, 16)
        let errorX = (SCREEN_WIDTH / 2) - (errorTextWidth / 2)
        DrawText(errorText, errorX, y + 40, 16, COLOR_RED)
    }

    let buttonClicked = GuiButton(Rectangle(x: 5, y: 5, width: 160, height: 40), "Click Me!")

    if buttonClicked != 0 {
        print("Button was clicked!")
        appState.update { $0.calendar = .loaded([]) }
    }

    EndDrawing()
}

// cleanup
calendarBackgroundTask.cancel()
await calendarService.stop()
brightnessBackgroundTask.cancel()

CloseWindow()