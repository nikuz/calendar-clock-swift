import Foundation
import Testing
@testable import CalendarClock

/// Everything is built in UTC and the layout is asked for the UTC start of the
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

@MainActor
private func makeCards(
    _ events: [CalendarEvent],
    hiddenEventIds: Set<String> = [],
) -> [CalendarEventCardComponent?] {
    var payload = CalendarPayload()
    payload.events = events
    payload.hiddenEventIds = hiddenEventIds

    return CalendarEventCardsLayout.makeCards(for: payload.dayEvents, startOfDay: dayStart)
}

@MainActor
struct EventCardsLayoutTests {
    private let baseTop = CalendarEventCardsLayout.baseTop
    private let spacing = CalendarEventCardsLayout.stackSpacing

    @Test func aCardThatOverlapsNothingTakesTheWholeHeight() throws {
        let cards = makeCards([
            try makeEvent(id: "a", from: 10 * 60, to: 11 * 60),
            try makeEvent(id: "b", from: 12 * 60, to: 13 * 60),
        ])

        #expect(cards.compactMap { $0?.top } == [baseTop, baseTop])
    }

    @Test func anOverlappingCardStartsBelowTheTimeOfTheCardItCovers() throws {
        // 10 - 11 is wide enough for both time labels on one line
        let cards = makeCards([
            try makeEvent(id: "a", from: 10 * 60, to: 11 * 60),
            try makeEvent(id: "b", from: 10 * 60 + 30, to: 11 * 60 + 30),
        ])

        let covered = try #require(cards.first ?? nil)
        let covering = try #require(cards.last ?? nil)

        #expect(covered.top == baseTop)
        #expect(covering.top == covered.top + covered.timeHeaderHeight + spacing)
    }

    @Test func aTwoLineTimeHeaderPushesTheNextCardOneLineFurtherDown() throws {
        let oneLineCards = makeCards([
            try makeEvent(id: "a", from: 10 * 60, to: 11 * 60),
            try makeEvent(id: "b", from: 10 * 60 + 10, to: 11 * 60 + 10),
        ])
        // a half an hour event is too narrow for "10" and "10:30" side by side,
        // the end time goes onto a line of its own
        let twoLineCards = makeCards([
            try makeEvent(id: "a", from: 10 * 60, to: 10 * 60 + 30),
            try makeEvent(id: "b", from: 10 * 60 + 10, to: 11 * 60 + 10),
        ])

        let oneLineHeader = try #require(oneLineCards.first ?? nil).timeHeaderHeight
        let twoLineHeader = try #require(twoLineCards.first ?? nil).timeHeaderHeight
        #expect(twoLineHeader == oneLineHeader + 10.0)

        let afterOneLine = try #require(oneLineCards.last ?? nil).top
        let afterTwoLines = try #require(twoLineCards.last ?? nil).top
        #expect(afterTwoLines == afterOneLine + 10.0)
        // the whole point: the second line of the time stays uncovered
        #expect(afterTwoLines > baseTop + twoLineHeader)
    }

    @Test func aCardOnlyClearsTheCardsItActuallyOverlaps() throws {
        let cards = makeCards([
            try makeEvent(id: "a", from: 10 * 60, to: 11 * 60),
            try makeEvent(id: "b", from: 10 * 60 + 30, to: 11 * 60 + 30),
            // starts after "a" ended, only "b" is in its way
            try makeEvent(id: "c", from: 11 * 60, to: 12 * 60),
            // overlaps nothing at all
            try makeEvent(id: "d", from: 14 * 60, to: 15 * 60),
        ])

        let tops = cards.compactMap { $0?.top }
        #expect(tops[1] > tops[0])
        #expect(tops[2] > tops[1])
        #expect(tops[3] == baseTop)
    }

    @Test func aCardNeverLosesItsOwnTime() throws {
        // deeper than the screen can cascade, the last cards share the bottom row
        let events = try (0..<6).map { index in
            try makeEvent(id: "\(index)", from: 10 * 60 + index * 10, to: 13 * 60)
        }

        for card in makeCards(events).compactMap({ $0 }) {
            #expect(CONTENT_HEIGHT - card.top >= card.minimumHeight)
        }
    }

    @Test func aCardTooShortForASummaryDrawsOnlyItsTime() throws {
        let cards = makeCards([
            try makeEvent(id: "a", from: 10 * 60, to: 13 * 60, summary: "First event"),
            try makeEvent(id: "b", from: 10 * 60 + 30, to: 13 * 60, summary: "Second event"),
            try makeEvent(id: "c", from: 11 * 60, to: 13 * 60, summary: "Third event"),
        ])

        let cardSummaries = cards.compactMap { $0?.summaryLines }
        #expect(!cardSummaries[0].isEmpty)
        // the third card is squeezed down to its time labels, a summary line
        // there would be drawn straight over them
        #expect(cardSummaries[2].isEmpty)

        for (index, summaryLines) in cardSummaries.enumerated() {
            let card = try #require(cards[index] ?? nil)
            let summaryHeight = Float(summaryLines.count) * 10.0
            #expect(CONTENT_HEIGHT - card.top - summaryHeight >= card.timeHeaderHeight)
        }
    }

    @Test func aSummaryTooLongForTheCardEndsWithAnEllipsis() throws {
        let cards = makeCards([
            try makeEvent(
                id: "a",
                from: 10 * 60,
                to: 10 * 60 + 45,
                summary: "A very long summary that cannot possibly fit into the card",
            )
        ])

        let summaryLines = try #require(cards.first ?? nil).summaryLines
        #expect(summaryLines.last?.hasSuffix("...") == true)
    }

    @Test func aHiddenEventNeitherCoversTheOthersNorIsPushedDown() throws {
        let events = [
            try makeEvent(id: "a", from: 10 * 60, to: 12 * 60),
            try makeEvent(id: "b", from: 11 * 60, to: 12 * 60),
        ]

        let overlapped = try #require(makeCards(events).last ?? nil)
        #expect(overlapped.top > baseTop)

        let cards = makeCards(events, hiddenEventIds: ["a"])
        let hidden = try #require(cards.first ?? nil)
        let visible = try #require(cards.last ?? nil)

        #expect(visible.top == baseTop)
        // the hidden event is a line at the very bottom of the screen
        #expect(hidden.top == CONTENT_HEIGHT - hidden.minimumHeight)
    }
}
