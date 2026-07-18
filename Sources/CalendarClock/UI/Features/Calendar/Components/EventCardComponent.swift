import Foundation
import CRayLib

@MainActor
struct CalendarEventCardComponent {
    static func draw(event: CalendarEvent, time: DateComponents, appState: AppStateData) {
        let unscii8Font = UIFonts.getFont(.unscii8)
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
        let fontSize: Float = 10.0
        
        DrawTextEx(unscii8Font, eventText, Vector2(x: 0, y: 10), fontSize, 0, .white)
    }
}