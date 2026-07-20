import Foundation
import Synchronization

struct CalendarPayload: Sendable {
    var events: [CalendarEvent] = []
    var confirmedApproachingEventId: String?
}

enum AppStateCalendar: Sendable {
    case loading
    case loaded(CalendarPayload)
    case failed(any Error & Sendable)
    
    mutating func updatePayload(_ transform: (inout CalendarPayload) -> Void) {
        var payload = CalendarPayload()
        
        if case .loaded(let existing) = self {
            payload = existing
        }
        
        transform(&payload)
        self = .loaded(payload)
    }

    var payload: CalendarPayload? {
        if case .loaded(let payload) = self {
            return payload
        }
        return nil
    }

    var confirmedApproachingEventId: String? {
        payload?.confirmedApproachingEventId
    }
    
    var events: [CalendarEvent] {
        payload?.events ?? []
    }
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