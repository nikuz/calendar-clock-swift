import Foundation
import CRayLib

@MainActor
struct CalendarView {
    static func draw(appState: AppState) {
        TimeComponent.draw()

        switch appState.current.calendar {
        case .loading:
            let loadingText = "Loading events..."
            let loadingTextWidth = MeasureText(loadingText, 18)
            let loadingX = (SCREEN_WIDTH / 2) - (loadingTextWidth / 2)
            DrawText(loadingText, loadingX, 40, 18, COLOR_WHITE)

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
                DrawText(eventText, 20, Int32(80 + index * 20), 16, COLOR_WHITE)
            }

        case .failed(let error):
            let errorText = "Failed to load events: \(error.localizedDescription)"
            let errorTextWidth = MeasureText(errorText, 16)
            let errorX = (SCREEN_WIDTH / 2) - (errorTextWidth / 2)
            DrawText(errorText, errorX, 40, 16, COLOR_RED)
        }        
    }
}