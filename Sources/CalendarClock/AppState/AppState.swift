import Foundation
import Synchronization

struct AppStateData: Sendable {
    var calendar: AppStateCalendar = .loading
    #if os(Linux)
        var brightness = AppStateBrightness(0.0)
    #else
        var brightness = AppStateBrightness(100.0)
    #endif
    var backgroundVisible = false
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