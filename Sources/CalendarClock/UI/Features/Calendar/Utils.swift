import Foundation
import CRayLib

enum CalendarUIUtils {
    static func getTime() -> DateComponents {
        #if DEBUG
            let followingMouse = KEY_LEFT_CONTROL.isDown
        #else
            let followingMouse = false
        #endif

        let calendar = Calendar.current
        var now = Date()

        if (followingMouse) {
            let mousePosition = GetMousePosition()
            let minuteUnderMouseCursor = Utilities.remapValue(
                value: mousePosition.x,
                inMin: 0,
                inMax: SCREEN_WIDTH,
                outMin: 0,
                outMax: 24 * 60 - 1,
            )
            let startOfToday = calendar.startOfDay(for: Date())
            now = Calendar.current.date(byAdding: .minute, value: Int(minuteUnderMouseCursor), to: startOfToday)!
        }

        return calendar.dateComponents([.hour, .minute], from: now)
    }
    
    static func isNightTime(_ time: DateComponents) -> Bool {
        guard let hour = time.hour else {
            return true
        }
        return hour < MORNING_HOUR || hour >= EVENING_HOUR;
    }
}