import Foundation
import Testing
@testable import CalendarClock

private func makeEvent(
    id: String,
    start: String,
    end: String,
    summary: String = "Event",
) throws -> CalendarEvent {
    let json = """
    {
      "id": "\(id)",
      "summary": "\(summary)",
      "description": null,
      "location": null,
      "start": {
        "dateTime": "\(start)",
        "timeZone": "UTC"
      },
      "end": {
        "dateTime": "\(end)",
        "timeZone": "UTC"
      },
      "etag": "etag-\(id)",
      "status": "confirmed",
      "transparency": "opaque"
    }
    """

    return try JSONDecoder().decode(CalendarEvent.self, from: Data(json.utf8))
}

private func makeTime(_ iso: String) throws -> CalendarUIUtils.TimeInfo {
    let now = try Date(iso, strategy: .iso8601)
    let calendar = Calendar.current

    return CalendarUIUtils.TimeInfo(
        now: now,
        startOfDay: calendar.startOfDay(for: now),
        hour: calendar.component(.hour, from: now),
        minute: calendar.component(.minute, from: now),
        second: calendar.component(.second, from: now),
    )
}

struct HiddenEventsLayoutTests {
    @Test func hiddenEventKeepsItsPlaceAndIsMarked() throws {
        var payload = CalendarPayload()
        payload.events = [
            try makeEvent(id: "a", start: "2026-08-17T10:00:00+00:00", end: "2026-08-17T11:00:00+00:00"),
            try makeEvent(id: "b", start: "2026-08-17T12:00:00+00:00", end: "2026-08-17T13:00:00+00:00"),
        ]
        payload.hiddenEventIds = ["b"]

        #expect(payload.positionedEvents.map(\.event.id) == ["a", "b"])
        #expect(payload.positionedEvents.map(\.isHidden) == [false, true])
        #expect(payload.visibleEvents.map(\.id) == ["a"])
    }

    @Test func hiddenEventDoesNotShrinkTheEventsItOverlaps() throws {
        let events = [
            try makeEvent(id: "a", start: "2026-08-17T10:00:00+00:00", end: "2026-08-17T12:00:00+00:00"),
            try makeEvent(id: "b", start: "2026-08-17T11:00:00+00:00", end: "2026-08-17T12:00:00+00:00"),
        ]

        var payload = CalendarPayload()
        payload.events = events

        let overlappedHeight = try #require(payload.positionedEvents.last?.height)
        #expect(overlappedHeight < 100.0)

        payload.hiddenEventIds = ["a"]

        #expect(payload.positionedEvents.last?.height == 100.0)
    }

    @Test func layoutRevisionChangesWhenAnEventIsHiddenAndShownAgain() throws {
        var payload = CalendarPayload()
        payload.events = [
            try makeEvent(id: "a", start: "2026-08-17T10:00:00+00:00", end: "2026-08-17T11:00:00+00:00")
        ]

        let afterLoad = payload.layoutRevision
        payload.hiddenEventIds = ["a"]
        let afterHiding = payload.layoutRevision
        #expect(afterHiding != afterLoad)

        // setting the same ids again is not a change, the cards stay valid
        payload.hiddenEventIds = ["a"]
        #expect(payload.layoutRevision == afterHiding)

        payload.hiddenEventIds = []
        #expect(payload.layoutRevision != afterHiding)
        #expect(payload.positionedEvents.allSatisfy { !$0.isHidden })
    }

    @Test func hiddenEventIsSkippedByTheEventsOrder() throws {
        var payload = CalendarPayload()
        payload.events = [
            try makeEvent(id: "a", start: "2026-08-17T10:00:00+00:00", end: "2026-08-17T11:00:00+00:00"),
            try makeEvent(id: "b", start: "2026-08-17T12:00:00+00:00", end: "2026-08-17T13:00:00+00:00"),
        ]
        payload.hiddenEventIds = ["b"]

        let order = CalendarUIUtils.getEventsOrder(
            events: payload.positionedEvents,
            time: try makeTime("2026-08-17T10:30:00+00:00"),
        )

        #expect(order.activeEvent?.index == 0)
        #expect(order.activeEvent?.event.id == "a")
        // the only upcoming event is hidden, so nothing is approaching
        #expect(order.nextEvent == nil)
        #expect(order.approachingEvent == nil)
    }

    @Test func hiddenActiveEventNeitherFlashesNorRings() throws {
        var payload = CalendarPayload()
        payload.events = [
            try makeEvent(id: "a", start: "2026-08-17T10:00:00+00:00", end: "2026-08-17T11:00:00+00:00")
        ]
        payload.hiddenEventIds = ["a"]

        let order = CalendarUIUtils.getEventsOrder(
            events: payload.positionedEvents,
            time: try makeTime("2026-08-17T10:30:00+00:00"),
        )

        #expect(order.activeEvent == nil)
    }
}

struct HiddenEventsStoreTests {
    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("calendar-clock-tests-\(UUID().uuidString)")
            .appendingPathComponent("hidden-events.json")
    }

    @Test func hidesAndShowsAnEventForTheGivenDay() {
        let fileURL = makeStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let store = HiddenEventsStore(fileURL: fileURL)
        let today = Date()

        #expect(store.eventIds(on: today).isEmpty)
        #expect(store.setHidden(true, eventId: "a", on: today) == ["a"])
        #expect(store.setHidden(true, eventId: "b", on: today) == ["a", "b"])
        #expect(store.eventIds(on: today) == ["a", "b"])
        #expect(store.setHidden(false, eventId: "a", on: today) == ["b"])
        #expect(store.eventIds(on: today) == ["b"])
    }

    @Test func hiddenEventsSurviveARestart() {
        let fileURL = makeStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let today = Date()
        let store = HiddenEventsStore(fileURL: fileURL)
        store.setHidden(true, eventId: "a", on: today)
        store.flush()

        let restarted = HiddenEventsStore(fileURL: fileURL)
        #expect(restarted.eventIds(on: today) == ["a"])
    }

    @Test func hiddenEventsAreDroppedWhenTheDayChanges() throws {
        let fileURL = makeStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let today = Date()
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: today))

        let store = HiddenEventsStore(fileURL: fileURL)
        store.setHidden(true, eventId: "a", on: today)
        store.flush()

        #expect(store.eventIds(on: tomorrow).isEmpty)
        // the expired ids are gone for good, asking for the old day gives nothing back
        #expect(store.eventIds(on: today).isEmpty)

        store.flush()
        let restarted = HiddenEventsStore(fileURL: fileURL)
        #expect(restarted.eventIds(on: tomorrow).isEmpty)
    }

    @Test func unreadableFileIsIgnored() throws {
        let fileURL = makeStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try Data("not json".utf8).write(to: fileURL)

        let store = HiddenEventsStore(fileURL: fileURL)
        #expect(store.eventIds(on: Date()).isEmpty)
    }
}

struct HiddenEventsNavigationTests {
    private func makeDay(hiddenEventIds: Set<String>) throws -> CalendarPayload {
        var payload = CalendarPayload()
        payload.events = [
            try makeEvent(id: "a", start: "2026-08-17T10:00:00+00:00", end: "2026-08-17T11:00:00+00:00"),
            try makeEvent(id: "b", start: "2026-08-17T12:00:00+00:00", end: "2026-08-17T13:00:00+00:00"),
            try makeEvent(id: "c", start: "2026-08-17T15:00:00+00:00", end: "2026-08-17T16:00:00+00:00"),
        ]
        payload.hiddenEventIds = hiddenEventIds
        return payload
    }

    /// Going left after the last event of the day has to land on that event even
    /// when it is hidden, the same way it does when it is visible.
    @Test func navigationStartsOnTheLastEventOfTheDayEvenWhenItIsHidden() throws {
        let time = try makeTime("2026-08-17T14:00:00+00:00")

        for hiddenEventIds in [Set<String>(), ["b"]] {
            let payload = try makeDay(hiddenEventIds: hiddenEventIds)
            let startIndex = CalendarUIUtils.getNavigationStartIndex(
                events: payload.positionedEvents,
                time: time,
                direction: .left,
            )
            #expect(startIndex == 1)
        }
    }

    @Test func navigationStartsOnTheNextEventEvenWhenItIsHidden() throws {
        let time = try makeTime("2026-08-17T14:00:00+00:00")

        for hiddenEventIds in [Set<String>(), ["c"]] {
            let payload = try makeDay(hiddenEventIds: hiddenEventIds)
            let startIndex = CalendarUIUtils.getNavigationStartIndex(
                events: payload.positionedEvents,
                time: time,
                direction: .right,
            )
            #expect(startIndex == 2)
        }
    }

    @Test func navigationStartsOnTheRunningEventEvenWhenItIsHidden() throws {
        let time = try makeTime("2026-08-17T12:30:00+00:00")

        for hiddenEventIds in [Set<String>(), ["b"]] {
            let payload = try makeDay(hiddenEventIds: hiddenEventIds)

            for direction in [CalendarUIUtils.EventsNavigationDirection.left, .right] {
                let startIndex = CalendarUIUtils.getNavigationStartIndex(
                    events: payload.positionedEvents,
                    time: time,
                    direction: direction,
                )
                #expect(startIndex == 1)
            }
        }
    }
}
