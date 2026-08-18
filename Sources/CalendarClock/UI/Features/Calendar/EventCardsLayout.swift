import Foundation

/// Vertical layout of the event cards.
///
/// All the cards end at the bottom of the screen and the summary is drawn at the
/// bottom of the card, so a card completely covers the summary of every card it
/// overlaps: the only part of an overlapped card that survives is the time
/// header at its top. That is why an overlapping card has to start lower than
/// the one it covers.
///
/// How much lower is a question about the content of the covered card, not about
/// the events, which is why the layout lives here and not in the app state: a
/// card whose two time labels don't fit on one line needs a whole line more to
/// stay readable than a card that fits them side by side.
@MainActor
enum CalendarEventCardsLayout {
    /// Top of a card that overlaps nothing.
    static let baseTop = CONTENT_HEIGHT - EVENTS_HEIGHT
    /// Gap left between the time header of a card and the card covering it.
    static let stackSpacing: Float = 1.0

    /// Builds the cards for the day and stacks the overlapping ones.
    static func makeCards(
        for dayEvents: [CalendarDayEvent],
        startOfDay: Date,
    ) -> [CalendarEventCardComponent?] {
        var cards = dayEvents.enumerated().map { index, dayEvent in
            CalendarEventCardComponent(
                dayEvent: dayEvent,
                index: index,
                startOfDay: startOfDay,
            )
        }

        stack(&cards, dayEvents: dayEvents)

        return cards
    }

    /// Gives every card a top that clears the time header of every card it
    /// overlaps. The events are sorted by their start date, so by the time a
    /// card is placed all the cards it can overlap already have their top.
    private static func stack(
        _ cards: inout [CalendarEventCardComponent?],
        dayEvents: [CalendarDayEvent],
    ) {
        // placed events that haven't ended yet, the ones the current event can overlap
        var openIndices: [Int] = []

        for index in cards.indices {
            // a hidden event is a line at the bottom of the screen: it neither
            // covers the visible events nor is pushed down by them
            guard var card = cards[index],
                !card.isHidden,
                let startDate = dayEvents[index].event.start.date
            else {
                continue
            }

            openIndices.removeAll { openIndex in
                guard let openEndDate = dayEvents[openIndex].event.end.date else {
                    return true
                }
                return openEndDate <= startDate
            }

            var top = baseTop
            for openIndex in openIndices {
                guard let openCard = cards[openIndex] else {
                    continue
                }
                top = max(top, openCard.top + openCard.timeHeaderHeight + stackSpacing)
            }

            // too many events overlap to give every one of them its own row,
            // the deepest ones share the last one instead of leaving the screen
            card.place(top: min(top, CONTENT_HEIGHT - card.minimumHeight))
            cards[index] = card

            if dayEvents[index].event.end.date != nil {
                openIndices.append(index)
            }
        }
    }
}
