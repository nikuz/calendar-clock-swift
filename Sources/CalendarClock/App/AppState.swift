import Foundation
import Synchronization

enum AppStateCalendar: Sendable {
    case loading
    case loaded([CalendarEvent])
    case failed(any Error & Sendable)
}

struct AppStateBrightness: Sendable {
    let rawValue: Double
    let factor: Float

    private let BRIGHTNESS_MIN: Float = 0.0
    private let BRIGHTNESS_MAX: Float = 40.0

    init(_ rawValue: Double) {
        self.rawValue = rawValue
        let factor = Utilities.remapValue(
            value: Float(rawValue),
            inMin: BRIGHTNESS_MIN,
            inMax: BRIGHTNESS_MAX,
            outMin: -1,
            outMax: 0
        )
        self.factor = max(factor, -0.95)
    }
}

struct AppStateData: Sendable {
    var calendar: AppStateCalendar = .loading
    #if os(Linux)
        var brightness = AppStateBrightness(0.0)
    #else
        var brightness = AppStateBrightness(100.0)
    #endif
}

final class AppState: Sendable {
    private let state = Mutex(AppStateData())

    var current: AppStateData {
        state.withLock { $0 }
    }

    func update(_ body: (inout AppStateData) -> Void) {
        state.withLock { body(&$0) }
    }
}