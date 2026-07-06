import Foundation
import CRayLib

final class AppState {
    var events: [CalendarEvent] = []
    var isLoading = true
    var loadError: Error?
}

let appState = AppState()

let calendarProvider = try GoogleCalendarProvider()
Task(priority: .background) {
    do {
        while true {
            print("Loading calendar events at \(Date())")
            do {
                let loadedEvents = try await calendarProvider.fetchEvents()
                await MainActor.run {
                    appState.events = loadedEvents
                    appState.isLoading = false
                    appState.loadError = nil
                }
            } catch {
                await MainActor.run {
                    appState.loadError = error
                    appState.isLoading = false
                }
            }

            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
        }
    } catch {
        await MainActor.run {
            appState.loadError = error
            appState.isLoading = false
        }
    }
}

@MainActor
func runApp() async {
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

        if appState.isLoading {
            let loadingText = "Loading events..."
            let loadingTextWidth = MeasureText(loadingText, 18)
            let loadingX = (SCREEN_WIDTH / 2) - (loadingTextWidth / 2)
            DrawText(loadingText, loadingX, y + 40, 18, COLOR_WHITE)
        } else if let loadError = appState.loadError {
            let errorText = "Failed to load events: \(loadError.localizedDescription)"
            let errorTextWidth = MeasureText(errorText, 16)
            let errorX = (SCREEN_WIDTH / 2) - (errorTextWidth / 2)
            DrawText(errorText, errorX, y + 40, 16, COLOR_RED)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short

            for (index, event) in appState.events.enumerated() {
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
        }

        let buttonClicked = GuiButton(Rectangle(x: 5, y: 5, width: 160, height: 40), "Click Me!")

        if buttonClicked != 0 {
            print("Button was clicked!")
            appState.events = []
        }

        EndDrawing()
    }

    CloseWindow()
}

await runApp()