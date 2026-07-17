import Foundation
import CRayLib

@MainActor
struct CalendarView {
    static func draw(appState: AppState, fonts: [String: Font]) {
        TimeComponent.draw(fonts: fonts)

        guard let unscii8Font = fonts["unscii8"] else {
            return
        }

        switch appState.current.calendar {
        case .loading:
            let loadingText = "Loading events..."
            let loadingTextWidth = MeasureTextEx(unscii8Font, loadingText, 18, 1)
            let loadingX = (SCREEN_WIDTH / 2) - (loadingTextWidth.x / 2)
            DrawTextEx(unscii8Font, loadingText, Vector2(x: loadingX, y: 40), 18, 1, .white)

        case .loaded(let events):
            for (index, event) in events.enumerated() {
                let summary = event.summary ?? "(untitled)"
                let dateString: String
                if let date = event.start.date {
                    let hour = Calendar.current.component(.hour, from: date)
                    let minute = Calendar.current.component(.minute, from: date)
                    dateString = "\(hour):\(minute)"
                } else {
                    dateString = "unknown date"
                }
                let eventText = "\(summary) — \(dateString)"
                DrawText(eventText, 20, Int32(80 + index * 20), 16, .white)
            }

        case .failed(let error):
            let errorText = "Failed to load events: \(error.localizedDescription)"
            let errorTextWidth = MeasureTextEx(unscii8Font, errorText, 16, 1)
            let errorX = (SCREEN_WIDTH / 2) - (errorTextWidth.x / 2)
            DrawTextEx(unscii8Font, errorText, Vector2(x: errorX, y: 40), 16, 1, .white)
        }        
    }
}