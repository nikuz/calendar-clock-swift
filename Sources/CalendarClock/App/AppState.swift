import Foundation
import Synchronization

enum CalendarState: Sendable {
    case loading
    case loaded([CalendarEvent])
    case failed(any Error & Sendable)
}

struct StateData: Sendable {
    var calendar: CalendarState = .loading
    #if os(Linux)
        var brightness: Double = 0
    #else
        var brightness: Double = 100
    #endif
}

final class AppState: Sendable {
    private let state = Mutex(StateData())

    var current: StateData {
        state.withLock { $0 }
    }

    func update(_ body: (inout StateData) -> Void) {
        state.withLock { body(&$0) }
    }
}