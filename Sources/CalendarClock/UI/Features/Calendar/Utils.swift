import Foundation
import CRayLib

enum CalendarUIUtils {
    static func getTime() -> DateComponents {
        let mousePosition = GetMousePosition()
        var followingMouse = false
        if mousePosition.x > 0 
            && mousePosition.x < SCREEN_WIDTH 
            && mousePosition.y > 0 
            && mousePosition.y < CONTENT_HEIGHT 
        {
            followingMouse = true
        }

        let calendar = Calendar.current
        var now = Date()

        if Bool(followingMouse) {
            let minuteUnderMouseCursor = Utilities.remapValue(
                value: Int(mousePosition.x),
                inMin: 0,
                inMax: Int(SCREEN_WIDTH),
                outMin: 0,
                outMax: 24 * 60 - 1,
            )
            let startOfToday = calendar.startOfDay(for: Date())
            let currentSeconds = calendar.component(.second, from: now)
            let timeWithMinutes = Calendar.current.date(
                byAdding: .minute, 
                value: minuteUnderMouseCursor, 
                to: startOfToday
            ) ?? startOfToday
            now = Calendar.current.date(
                byAdding: .second, 
                value: currentSeconds, 
                to: timeWithMinutes
            ) ?? timeWithMinutes
        }

        return calendar.dateComponents([.hour, .minute, .second], from: now)
    }

    static func isNightTime(_ time: DateComponents) -> Bool {
        guard let hour = time.hour else {
            return true
        }
        return hour < MORNING_HOUR || hour >= EVENING_HOUR;
    }

    static func getActiveCalendarEvent(events: [CalendarEvent], time: DateComponents) -> (Int?, CalendarEvent?) {
        guard let currentHour = time.hour, let currentMinute = time.minute else {
            return (nil, nil)
        }

        let currentTime = currentHour * 60 + currentMinute
        let calendar = Calendar.current

        for (index, event) in events.enumerated() {
            guard let eventStartDate = event.start.date,
                let eventEndDate = event.end.date
            else {
                continue
            }

            let eventStartHour = calendar.component(.hour, from: eventStartDate)
            let eventStartMinute = calendar.component(.minute, from: eventStartDate)
            let eventStartTime = eventStartHour * 60 + eventStartMinute

            let eventEndHour = calendar.component(.hour, from: eventEndDate)
            let eventEndMinute = calendar.component(.minute, from: eventEndDate)
            let eventEndTime = eventEndHour * 60 + eventEndMinute

            if currentTime >= eventStartTime - 1 && currentTime <= eventEndTime {
                return (index, event)
            }
        }

        return (nil, nil)
    }
}