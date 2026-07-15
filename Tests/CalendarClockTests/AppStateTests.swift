import Testing
@testable import CalendarClock

struct AppStateTests {
    @Test func initialStateStartsLoadingAndDefaultBrightness() {
        let state = AppState()

        let current = state.current

        #expect(current.brightness == 100)

        guard case .loading = current.calendar else {
            Issue.record("Expected calendar to start in loading state")
            return
        }
    }

    @Test func updateMutatesStateSafely() {
        let state = AppState()

        state.update { data in
            data.brightness = 75
            data.calendar = .loaded([])
        }

        let current = state.current
        #expect(current.brightness == 75)

        guard case .loaded(let events) = current.calendar else {
            Issue.record("Expected calendar to be loaded")
            return
        }
        #expect(events.isEmpty)
    }
}