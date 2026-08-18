import Foundation
import Testing
@testable import CalendarClock

/// Everything is built in UTC and the cards are asked for the UTC start of the
/// day, so the tests don't depend on the time zone the machine runs in.
private let dayStart = try! Date("2026-08-17T00:00:00+00:00", strategy: .iso8601)

private func makeEvent(
    id: String,
    from startMinutes: Int,
    to endMinutes: Int,
    summary: String = "Event",
) throws -> CalendarEvent {
    func iso(_ minutes: Int) -> String {
        String(
            format: "2026-08-17T%02d:%02d:00+00:00",
            minutes / 60,
            minutes % 60,
        )
    }

    let json = """
    {
      "id": "\(id)",
      "summary": "\(summary)",
      "description": null,
      "location": null,
      "start": {
        "dateTime": "\(iso(startMinutes))",
        "timeZone": "UTC"
      },
      "end": {
        "dateTime": "\(iso(endMinutes))",
        "timeZone": "UTC"
      },
      "etag": "etag-\(id)",
      "status": "confirmed",
      "transparency": "opaque"
    }
    """

    return try JSONDecoder().decode(CalendarEvent.self, from: Data(json.utf8))
}

private func makeTime(_ minutes: Int) -> CalendarUIUtils.TimeInfo {
    CalendarUIUtils.TimeInfo(
        now: dayStart.addingTimeInterval(Double(minutes) * 60),
        startOfDay: dayStart,
        hour: minutes / 60,
        minute: minutes % 60,
        second: 0,
    )
}

/// Draws one frame of the given cards, the way the view does, and gives them back.
@MainActor
private func update(
    _ cards: inout [CalendarEventCardComponent?],
    time: CalendarUIUtils.TimeInfo,
    highlightedEventIndex: Int? = nil,
    selectedEventIndex: Int? = nil,
) {
    let context = CalendarEventCardComponent.Context(
        time: time,
        appState: AppStateData(),
        eventsOrder: (nil, nil, nil, nil),
        eventsNavigation: highlightedEventIndex.map { ($0, 0, 0, 0, 0) },
        selectedEventIndex: selectedEventIndex,
    )
    var leftEdgeCounter = 0
    var rightEdgeCounter = 0

    for index in cards.indices {
        cards[index]?.update(
            context: context,
            leftEdgeCounter: &leftEdgeCounter,
            rightEdgeCounter: &rightEdgeCounter,
        )
    }
}

@MainActor
private func makeCards(_ events: [CalendarEvent]) -> [CalendarEventCardComponent?] {
    var payload = CalendarPayload()
    payload.events = events

    return CalendarEventCardsLayout.makeCards(for: payload.dayEvents, startOfDay: dayStart)
}

@MainActor
struct SelectedEventCardTests {
    @Test func aSelectedCardIsTwiceAsWideAndGrowsToBothSides() throws {
        var cards = makeCards([try makeEvent(id: "a", from: 12 * 60, to: 13 * 60)])
        let time = makeTime(12 * 60 + 30)

        update(&cards, time: time, highlightedEventIndex: 0)
        let highlighted = try #require(cards.first ?? nil).frame

        update(&cards, time: time, highlightedEventIndex: 0, selectedEventIndex: 0)
        let selected = try #require(cards.first ?? nil).frame

        #expect(selected.width == highlighted.width * 2)
        // the island keeps the middle of the card it grew out of, up to the half
        // pixel an odd width can't be split into
        let centerShift = (selected.x + selected.width / 2) - (highlighted.x + highlighted.width / 2)
        #expect(abs(centerShift) <= 0.5)
        #expect(selected.x < highlighted.x)
        #expect(selected.x + selected.width > highlighted.x + highlighted.width)
    }

    @Test func aSelectedCardFloatsAboveTheBottomOfTheScreen() throws {
        var cards = makeCards([try makeEvent(id: "a", from: 12 * 60, to: 13 * 60)])
        let time = makeTime(12 * 60 + 30)

        update(&cards, time: time, highlightedEventIndex: 0)
        let highlighted = try #require(cards.first ?? nil).frame
        #expect(highlighted.y + highlighted.height == CONTENT_HEIGHT)

        update(&cards, time: time, highlightedEventIndex: 0, selectedEventIndex: 0)
        let selected = try #require(cards.first ?? nil).frame
        // the island starts where the highlighted card does and ends above the screen
        #expect(selected.y == highlighted.y)
        #expect(selected.y + selected.height < CONTENT_HEIGHT)
    }

    @Test func anIslandGrownOverTheEdgeOfTheScreenIsPushedBackIn() throws {
        // the first event of the day sits on the left edge of the timeline
        var cards = makeCards([try makeEvent(id: "a", from: 6 * 60 + 30, to: 8 * 60)])
        let time = makeTime(6 * 60 + 30)

        update(&cards, time: time, highlightedEventIndex: 0, selectedEventIndex: 0)
        let selected = try #require(cards.first ?? nil).frame

        #expect(selected.x >= 0)
        #expect(selected.x + selected.width <= SCREEN_WIDTH)
    }

    @Test func aSelectedCardFitsMoreOfItsSummaryOnALine() throws {
        let summary = String(repeating: "word ", count: 20)
        var cards = makeCards([try makeEvent(id: "a", from: 12 * 60, to: 13 * 60, summary: summary)])
        let time = makeTime(12 * 60 + 30)

        update(&cards, time: time, highlightedEventIndex: 0)
        let highlighted = try #require(cards.first ?? nil)
        let highlightedLine = try #require(highlighted.summaryLines.first)

        update(&cards, time: time, highlightedEventIndex: 0, selectedEventIndex: 0)
        let selected = try #require(cards.first ?? nil)
        let selectedLine = try #require(selected.summaryLines.first)

        #expect(selectedLine.count > highlightedLine.count)
    }

    @Test func aHiddenEventIsNeverDrawnAsAnIsland() throws {
        var payload = CalendarPayload()
        payload.events = [try makeEvent(id: "a", from: 12 * 60, to: 13 * 60)]
        payload.hiddenEventIds = ["a"]

        var cards = CalendarEventCardsLayout.makeCards(
            for: payload.dayEvents,
            startOfDay: dayStart,
        )
        update(&cards, time: makeTime(12 * 60 + 30), highlightedEventIndex: 0, selectedEventIndex: 0)

        let hidden = try #require(cards.first ?? nil).frame
        #expect(hidden.y + hidden.height == CONTENT_HEIGHT)
    }
}
