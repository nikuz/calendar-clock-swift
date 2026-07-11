import Foundation

final class AppState {
    private let lock = NSLock()

    // Internal backing properties
    private var _events: [CalendarEvent] = []
    private var _isLoading = true
    private var _loadError: Error?
    private var _brightness: Double = 100

    // Thread-safe computed properties
    var events: [CalendarEvent] {
        get { lock.lock(); defer { lock.unlock() }; return _events }
        set { lock.lock(); defer { lock.unlock() }; _events = newValue }
    }

    var isLoading: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isLoading }
        set { lock.lock(); defer { lock.unlock() }; _always_write_safely(_isLoading = newValue) }
    }

    var loadError: Error? {
        get { lock.lock(); defer { lock.unlock() }; return _loadError }
        set { lock.lock(); defer { lock.unlock() }; _loadError = newValue }
    }

    var brightness: Double {
        get { lock.lock(); defer { lock.unlock() }; return _brightness }
        set { lock.lock(); defer { lock.unlock() }; _brightness = newValue }
    }

    // Tiny helper helper to keep defer block tidy
    private func _always_write_safely(_ body: @autoclosure () -> Void) { body() }
}
