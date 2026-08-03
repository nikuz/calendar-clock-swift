import Foundation
import Testing
@testable import CalendarClock

struct AppStateTests {
    @Test func initialStateStartsLoadingAndDefaultBrightness() {
        let state = AppState()

        let current = state.current

        #expect(current.brightness.rawValue == 100.0)

        guard case .loading = current.calendar else {
            Issue.record("Expected calendar to start in loading state")
            return
        }
    }

    @Test func updateMutatesStateSafely() {
        let state = AppState()

        state.update { data in
            data.brightness = AppStateBrightness(75.0)
            data.calendar = .loaded(CalendarPayload())
        }

        let current = state.current
        #expect(current.brightness.rawValue == 75.0)

        guard case .loaded(let payload) = current.calendar else {
            Issue.record("Expected calendar to be loaded")
            return
        }
        #expect(payload.events.isEmpty)
    }

    @Test func fullDayDateTimeRangeIsRecognizedAsAllDay() throws {
        let json = """
        {
          "id": "1",
          "summary": "All day event",
          "description": null,
          "location": null,
          "start": {
            "dateTime": "2026-08-03T00:00:00+00:00",
            "timeZone": "UTC"
          },
          "end": {
            "dateTime": "2026-08-04T00:00:00+00:00",
            "timeZone": "UTC"
          },
          "etag": "etag",
          "status": "confirmed",
          "transparency": "opaque"
        }
        """

        let event = try JSONDecoder().decode(CalendarEvent.self, from: json.data(using: .utf8)!)
        #expect(event.isAllDay == true)
    }
}