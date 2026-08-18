import Foundation
import CRayLib

@MainActor
private struct EventCardTime {
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let endTotalMinutes: Int
}

@MainActor 
private struct EventCardGeometry {
    var xStart: Float = 0.0
    var xEnd: Float = 0.0
    var yStart: Float = 0.0
    var yEnd: Float = 0.0
    var boxWidth: Float = 0.0
    var boxContentWidth: Float = 0.0
}

@MainActor
private struct EventCardStyle {
    var font: UIFont = .unscii8
    var fontSize: Float = 8.0
    var hPadding: Float = 4.0
    var vPadding: Float = 5.0
    var lineHeight: Float = 10.0
    var characterWidth: Float = 8.0
    var color: Color = .black
    var borderColor: Color = .black
    var fill: Color = .black
}

@MainActor
struct CalendarEventCardComponent {
    /// Values that change from frame to frame but are the same for every card,
    /// so they are calculated once per frame by the view instead of per card.
    struct Context {
        let time: CalendarUIUtils.TimeInfo
        let timeMargin: Float
        let navigationShift: Float
        let brightnessFactor: Float
        let flashingEventId: String?
        let confirmedApproachingEventId: String?
        let highlightedEventIndex: Int?
        let selectedEventIndex: Int?

        init(
            time: CalendarUIUtils.TimeInfo,
            appState: AppStateData,
            eventsOrder: CalendarUIUtils.EventsOrder,
            eventsNavigation: CalendarUIUtils.EventsNavigation? = nil,
            selectedEventIndex: Int? = nil,
        ) {
            let brightness = appState.brightness

            self.time = time
            self.selectedEventIndex = selectedEventIndex
            timeMargin = CalendarUIUtils.getTimeMargin(time: time)
            navigationShift = round(eventsNavigation?.shift ?? 0)
            brightnessFactor = CalendarUIUtils.isNightTime(time)
                ? brightness.nightFactor
                : brightness.dayFactor
            flashingEventId = (eventsOrder.approachingEvent ?? eventsOrder.activeEvent)?.event.id
            confirmedApproachingEventId = appState.calendar.confirmedApproachingEventId
            highlightedEventIndex = eventsNavigation?.eventIndex
        }
    }

    /// Thickness of the line a hidden event is reduced to.
    private static let hiddenLineHeight: Float = 2.0
    /// The same line while the event is highlighted, thick enough to be spotted.
    private static let hiddenHighlightedLineHeight: Float = 6.0
    /// How much wider the card of a selected event gets. It grows to both sides
    /// from the place the event takes on the timeline.
    private static let selectedWidthFactor: Float = 2.0
    /// Gap between the island of a selected event and the bottom of the screen.
    /// Without it the summary would end on the very edge of the screen.
    private static let selectedBottomMargin: Float = 8.0
    /// Gap the island is kept away from the left and the right edge of the screen.
    private static let selectedSideMargin: Float = 4.0

    // calculated once, when the event is created
    private let event: CalendarEvent
    private let index: Int
    let isHidden: Bool
    private let baseColor: Color
    private let eventTime: EventCardTime
    private var eventPosition: CalendarUIUtils.EventPosition
    private var dayStart: Date
    private let summary: String
    private var geometry: EventCardGeometry
    private var style: EventCardStyle
    /// Width of the card on the timeline, the width every other one is derived from.
    private var baseBoxWidth: Float = 0.0
    private var highlightedYStart: Float = 0.0
    private var startTimeString = ""
    private var endTimeString = ""
    private var endTimeOffset = Vector2()
    /// How many lines the two time labels take, one or two.
    private var timeLines = 1

    // calculated by the layout, see `CalendarEventCardsLayout`
    private(set) var top: Float = 0.0

    // calculated when the event is created and when it gets highlighted or selected,
    // those are the only states that change the height of the summary box
    private(set) var summaryLines: [String] = []

    // updated on every frame
    private var isHighlighted = false
    private var isSelected = false
    private var outsideLeftEdgeIndex: Int? = nil
    private var outsideRightEdgeIndex: Int? = nil

    /// The top of the card is the only part of it that survives being covered by
    /// the events it overlaps, so it is the part the layout has to keep clear.
    var timeHeaderHeight: Float {
        isHidden ? Self.hiddenLineHeight : style.vPadding + style.lineHeight * Float(timeLines)
    }

    /// Height the card can never go below: the time labels plus the padding
    /// under them. Anything shorter would draw the time outside of the box.
    var minimumHeight: Float {
        isHidden ? Self.hiddenLineHeight : timeHeaderHeight + style.vPadding
    }

    /// The rectangle the card is drawn in, as the last `update` left it.
    var frame: Rectangle {
        Rectangle(
            x: geometry.xStart,
            y: geometry.yStart,
            width: geometry.boxWidth,
            height: geometry.yEnd - geometry.yStart,
        )
    }

    /// Vertical space the time labels take away from the summary.
    private var timeSpace: Float {
        timeHeaderHeight + style.vPadding
    }

    /// Space kept under the summary. A card ends at the bottom of the screen and
    /// the summary ends with it, only the island of a selected event has a bottom
    /// border of its own to stay away from.
    private var summaryBottomPadding: Float {
        isSelected ? style.vPadding : 0
    }

    init?(
        dayEvent: CalendarDayEvent,
        index: Int,
        startOfDay: Date,
    ) {
        let event = dayEvent.event

        guard let eventStartHour = event.start.hour,
            let eventStartMinute = event.start.minute,
            let eventEndHour = event.end.hour,
            let eventEndMinute = event.end.minute,
            let eventPosition = CalendarUIUtils.getEventPosition(event: event, startOfDay: startOfDay)
        else {
            return nil
        }

        self.event = event
        self.index = index
        self.isHidden = dayEvent.isHidden
        self.eventPosition = eventPosition
        dayStart = startOfDay
        baseColor = CALENDAR_EVENT_COLORS[index % CALENDAR_EVENT_COLORS.count]
        summary = event.summary ?? "(untitled)"

        eventTime = EventCardTime(
            startHour: eventStartHour,
            startMinute: eventStartMinute,
            endHour: eventEndHour,
            endMinute: eventEndMinute,
            endTotalMinutes: eventEndHour * 60 + eventEndMinute,
        )
        style = EventCardStyle()
        geometry = EventCardGeometry()

        measure()
        // a card is always in a drawable state, the layout may lower it later
        place(top: CalendarEventCardsLayout.baseTop)
    }

    /// Everything that only depends on the event itself: the font, the width of
    /// the box and the time labels. None of it changes while the event is on the
    /// screen, and the vertical layout is built on top of it.
    private mutating func measure() {
        let boxWidth = round(eventPosition.width)

        baseBoxWidth = boxWidth
        geometry.boxWidth = boxWidth
        geometry.boxContentWidth = boxWidth
        geometry.yEnd = CONTENT_HEIGHT

        // a hidden event carries no text, none of the font, time or summary
        // layout applies to it
        guard !isHidden else {
            return
        }

        // is short event
        if boxWidth <= 40.0 {
            style.font = .silkscreen3x7
            style.fontSize = 9.0
            style.characterWidth = 4.0
            style.hPadding = 3.0
        }

        geometry.boxContentWidth = boxWidth - style.hPadding * 2.0

        startTimeString = "\(CalendarUIUtils.formatTo12H(eventTime.startHour))"
        if eventTime.startMinute != 0 {
            startTimeString += ":\(eventTime.startMinute)"
        }
        endTimeString = "\(CalendarUIUtils.formatTo12H(eventTime.endHour))"
        if eventTime.endMinute != 0 {
            endTimeString += ":\(eventTime.endMinute)"
        }

        layOutTime()
    }

    /// Puts the end time either next to the start time or on the line under it,
    /// whichever the current width of the box has room for. The box gets wider
    /// when the event is selected, so this outlives `measure`.
    private mutating func layOutTime() {
        let startTimeStringSize = Float(startTimeString.count) * style.characterWidth
        let endTimeStringSize = Float(endTimeString.count) * style.characterWidth

        // both labels don't fit on one line, put the end time below the start time
        if startTimeStringSize + endTimeStringSize + style.characterWidth > geometry.boxContentWidth {
            timeLines = 2
            endTimeOffset = Vector2(x: style.hPadding, y: style.vPadding + style.lineHeight)
        } else {
            timeLines = 1
            endTimeOffset = Vector2(
                x: style.hPadding + geometry.boxContentWidth - endTimeStringSize,
                y: style.vPadding,
            )
        }
    }

    /// Puts the top of the card at the given distance from the top of the screen.
    /// The cards are bottom aligned, so the top is what gives the card its height
    /// and the summary has to be wrapped again for it.
    ///
    /// A hidden event keeps its place on the timeline but is squeezed into a line
    /// at the very bottom of the screen, so it stays a reminder that it is there.
    /// It ignores the layout and always sits on that line.
    mutating func place(top: Float) {
        if isHidden {
            self.top = CONTENT_HEIGHT - Self.hiddenLineHeight
            highlightedYStart = CONTENT_HEIGHT - Self.hiddenHighlightedLineHeight
        } else {
            self.top = top
            highlightedYStart = CalendarEventCardsLayout.baseTop - CONTENT_HEIGHT / 100 * 5
        }

        updateBounds()

        if !isHidden {
            updateSummaryLines()
        }
    }

    /// Top and bottom of the card. Every card ends at the bottom of the screen,
    /// only the island of a selected event floats above it.
    private mutating func updateBounds() {
        geometry.yStart = isHighlighted || isSelected ? highlightedYStart : top
        geometry.yEnd = isSelected ? CONTENT_HEIGHT - Self.selectedBottomMargin : CONTENT_HEIGHT
    }

    /// Splits the summary into the lines that fit into the card under the time.
    /// Only depends on the height of the card, so it survives until the card is
    /// highlighted or selected.
    private mutating func updateSummaryLines() {
        let summaryBoxHeight = geometry.yEnd - geometry.yStart - timeSpace - summaryBottomPadding

        summaryLines = Self.wrap(
            summary,
            charactersPerLine: Int(geometry.boxContentWidth / style.characterWidth),
            maxLines: Int(summaryBoxHeight / style.lineHeight),
        )
    }

    /// Wraps the summary into at most `maxLines` lines of `charactersPerLine`
    /// characters. What doesn't fit is cut off and the last line ends with an
    /// ellipsis. A card too short for even one line gets no summary at all,
    /// otherwise the summary would be drawn over the time labels.
    private static func wrap(
        _ summary: String,
        charactersPerLine: Int,
        maxLines: Int,
    ) -> [String] {
        guard charactersPerLine > 0, maxLines > 0 else {
            return []
        }

        var lines: [String] = []
        var line = ""

        for character in summary {
            if line.count == charactersPerLine {
                lines.append(line)
                line = ""
            }
            // a line never starts with the space it was wrapped on
            if line.isEmpty && character == " " {
                continue
            }
            line.append(character)
        }
        if !line.isEmpty {
            lines.append(line)
        }

        guard lines.count > maxLines else {
            return lines
        }

        lines = Array(lines.prefix(maxLines))
        let lastLine = lines[maxLines - 1]
        if lastLine.count > 3 {
            lines[maxLines - 1] = lastLine.dropLast(3) + "..."
        }

        return lines
    }

    mutating func update(
        context: Context,
        leftEdgeCounter: inout Int,
        rightEdgeCounter: inout Int,
    ) {
        // the day has changed, event positions are relative to the start of the day
        if dayStart != context.time.startOfDay,
            let eventPosition = CalendarUIUtils.getEventPosition(
                event: event,
                startOfDay: context.time.startOfDay,
            )
        {
            dayStart = context.time.startOfDay
            self.eventPosition = eventPosition
        }

        let wasHighlighted = isHighlighted
        let wasSelected = isSelected
        isHighlighted = context.highlightedEventIndex == index
        // a hidden event is brought back before it can be opened, it is never
        // the one the island is drawn for
        isSelected = !isHidden && context.selectedEventIndex == index

        updateGeometry(context: context)

        if !isHidden && (wasHighlighted != isHighlighted || wasSelected != isSelected) {
            // the box of the island is wider, the time labels get more room
            if wasSelected != isSelected {
                layOutTime()
            }
            // the summary box changed its size, the summary has to be re-wrapped
            updateSummaryLines()
        }

        updateStyle(context: context)

        // a hidden event is a line at the bottom of the screen, it doesn't take
        // one of the slots the off screen events are counted into
        if !isHidden {
            updateOutsideEdges(leftEdgeCounter: &leftEdgeCounter, rightEdgeCounter: &rightEdgeCounter)
        }
    }

    private mutating func updateGeometry(context: Context) {
        // the event position is rounded on its own, the two offsets are already whole
        // pixels and are the same for every card, so all of them shift together
        let xStart = round(eventPosition.start) - context.timeMargin - context.navigationShift

        if isSelected {
            // the island grows to both sides from the place the event takes on
            // the timeline, and is pushed back in when that would take it off
            // the screen: it carries the whole summary, all of it has to be seen
            let maximumWidth = SCREEN_WIDTH - Self.selectedSideMargin * 2
            let width = round(min(baseBoxWidth * Self.selectedWidthFactor, maximumWidth))
            let centeredXStart = xStart - round((width - baseBoxWidth) / 2)
            let rightmostXStart = SCREEN_WIDTH - Self.selectedSideMargin - width

            geometry.boxWidth = width
            geometry.boxContentWidth = width - style.hPadding * 2
            geometry.xStart = min(max(centeredXStart, Self.selectedSideMargin), rightmostXStart)
        } else {
            geometry.boxWidth = baseBoxWidth
            // a hidden event carries no text, it has no content box
            geometry.boxContentWidth = isHidden ? baseBoxWidth : baseBoxWidth - style.hPadding * 2
            geometry.xStart = xStart
        }

        geometry.xEnd = geometry.xStart + geometry.boxWidth
        updateBounds()
    }

    private mutating func updateStyle(context: Context) {
        // brightness factor range is -1..0, 0 means full brightness
        let brightnessFactor = isHighlighted ? 0 : context.brightnessFactor
        var color = ColorBrightness(baseColor, brightnessFactor)

        // gray out the past events
        if context.time.totalMinutes > eventTime.endTotalMinutes && !isHighlighted {
            color = ColorBrightness(.darkGray, brightnessFactor)
        }

        style.borderColor = color

        let isFlashingEvent = context.flashingEventId == event.id
        if isFlashingEvent
            && (context.confirmedApproachingEventId == event.id || context.time.second % 2 == 0)
        {
            style.fill = color
            style.color = .black
        } else {
            style.fill = .black
            style.color = color
        }
    }

    private mutating func updateOutsideEdges(
        leftEdgeCounter: inout Int,
        rightEdgeCounter: inout Int,
    ) {
        outsideLeftEdgeIndex = nil
        outsideRightEdgeIndex = nil

        // event is behind the left edge of the screen
        if geometry.xEnd <= 0 {
            outsideLeftEdgeIndex = leftEdgeCounter
            leftEdgeCounter += 1
        }
        // event is behind the right edge of the screen
        else if geometry.xStart > SCREEN_WIDTH {
            outsideRightEdgeIndex = rightEdgeCounter
            rightEdgeCounter += 1
        }
    }

    func draw() {
        if isHidden {
            drawHiddenLine()
            return
        }

        if outsideLeftEdgeIndex != nil || outsideRightEdgeIndex != nil {
            drawOutside()
        } else {
            drawBox()
            drawTime()
            drawSummary()
        }
    }

    private func drawHiddenLine() {
        DrawRectangleV(
            Vector2(x: geometry.xStart, y: geometry.yStart),
            Vector2(x: geometry.boxWidth, y: geometry.yEnd - geometry.yStart),
            style.borderColor
        )
    }

    private func drawOutside() {
        let outsideEventSize: Float = 6.0
        let outsideEventMargin = outsideEventSize * 1.5
        let outsideEventCellSize = outsideEventSize * 2.5

        if let outsideLeftEdgeIndex {
            let x = outsideEventSize / 2 + outsideEventSize
            let y = outsideEventMargin + outsideEventCellSize * Float(outsideLeftEdgeIndex)
            DrawCircleV(Vector2(x: x, y: y), outsideEventSize, ColorAlpha(style.color, 0.5))
        }

        if let outsideRightEdgeIndex {
            let x = SCREEN_WIDTH - outsideEventSize / 2 - outsideEventSize
            let y = outsideEventMargin + outsideEventCellSize * Float(outsideRightEdgeIndex)
            DrawCircleV(Vector2(x: x, y: y), outsideEventSize, ColorAlpha(style.color, 0.5))
        }
    }

    private func drawBox() {
        let chamferSize: Float = 4.0
        let lineThickness: Float = 1.0

        let xStart = geometry.xStart
        let xEnd = geometry.xEnd
        let yStart = geometry.yStart
        let yEnd = geometry.yEnd
        // an ordinary card runs into the bottom of the screen, it has no bottom
        // corners to cut off. The island of a selected event floats above it and
        // is chamfered on all four corners
        let bottomChamferSize: Float = isSelected ? chamferSize : 0
        let sideHeight = yEnd - yStart - chamferSize - bottomChamferSize

        let chamferLeftXEnd = xStart + chamferSize
        let chamferRightXStart = xEnd - chamferSize

        // filling
        DrawRectangleV(
            Vector2(x: xStart, y: yStart + chamferSize),
            Vector2(x: geometry.boxWidth, y: sideHeight),
            style.fill
        )
        DrawRectangleV(
            Vector2(x: chamferLeftXEnd, y: yStart),
            Vector2(x: chamferRightXStart - chamferLeftXEnd, y: chamferSize),
            style.fill
        )
        DrawTriangle(
            Vector2(x: chamferLeftXEnd, y: yStart + chamferSize),
            Vector2(x: chamferLeftXEnd, y: yStart),
            Vector2(x: xStart, y: yStart + chamferSize),
            style.fill
        )
        DrawTriangle(
            Vector2(x: xEnd, y: yStart + chamferSize),
            Vector2(x: chamferRightXStart, y: yStart),
            Vector2(x: chamferRightXStart, y: yStart + chamferSize),
            style.fill
        )

        // border
        DrawRectangleV(
            Vector2(x: xStart, y: yStart + chamferSize),
            Vector2(x: lineThickness, y: sideHeight),
            style.borderColor
        )
        DrawRectangleV(
            Vector2(x: xEnd - lineThickness, y: yStart + chamferSize),
            Vector2(x: lineThickness, y: sideHeight),
            style.borderColor
        )
        DrawRectangleV(
            Vector2(x: chamferLeftXEnd, y: yStart),
            Vector2(x: chamferRightXStart - chamferLeftXEnd, y: lineThickness),
            style.borderColor
        )

        // chamfers
        DrawLineEx(
            Vector2(x: xStart + lineThickness / 2, y: yStart + chamferSize),
            Vector2(x: chamferLeftXEnd, y: yStart + lineThickness / 2),
            lineThickness,
            style.borderColor
        )
        DrawLineEx(
            Vector2(x: chamferRightXStart, y: yStart + lineThickness / 2),
            Vector2(x: xEnd - lineThickness / 2, y: yStart + chamferSize),
            lineThickness,
            style.borderColor
        )

        if isSelected {
            drawIslandBottom(chamferSize: bottomChamferSize, lineThickness: lineThickness)
        }

        // debug: content filling
        // DrawRectangleV(
        //     Vector2(x: geometry.xStart + style.hPadding, y: geometry.yStart + timeSpace), 
        //     Vector2(x: geometry.boxContentWidth, y: geometry.yEnd - geometry.yStart - timeSpace),
        //     .rayWhite
        // )
    }

    /// The bottom of the floating island of a selected event: the mirror image
    /// of the two chamfered corners the top of every card is drawn with.
    private func drawIslandBottom(chamferSize: Float, lineThickness: Float) {
        let xStart = geometry.xStart
        let xEnd = geometry.xEnd
        let yEnd = geometry.yEnd

        let chamferLeftXEnd = xStart + chamferSize
        let chamferRightXStart = xEnd - chamferSize

        // filling
        DrawRectangleV(
            Vector2(x: chamferLeftXEnd, y: yEnd - chamferSize),
            Vector2(x: chamferRightXStart - chamferLeftXEnd, y: chamferSize),
            style.fill
        )
        DrawTriangle(
            Vector2(x: xStart, y: yEnd - chamferSize),
            Vector2(x: chamferLeftXEnd, y: yEnd),
            Vector2(x: chamferLeftXEnd, y: yEnd - chamferSize),
            style.fill
        )
        DrawTriangle(
            Vector2(x: chamferRightXStart, y: yEnd - chamferSize),
            Vector2(x: chamferRightXStart, y: yEnd),
            Vector2(x: xEnd, y: yEnd - chamferSize),
            style.fill
        )

        // border
        DrawRectangleV(
            Vector2(x: chamferLeftXEnd, y: yEnd - lineThickness),
            Vector2(x: chamferRightXStart - chamferLeftXEnd, y: lineThickness),
            style.borderColor
        )

        // chamfers
        DrawLineEx(
            Vector2(x: xStart + lineThickness / 2, y: yEnd - chamferSize),
            Vector2(x: chamferLeftXEnd, y: yEnd - lineThickness / 2),
            lineThickness,
            style.borderColor
        )
        DrawLineEx(
            Vector2(x: chamferRightXStart, y: yEnd - lineThickness / 2),
            Vector2(x: xEnd - lineThickness / 2, y: yEnd - chamferSize),
            lineThickness,
            style.borderColor
        )
    }

    private func drawTime() {
        let font = UIFonts.getFont(style.font)

        DrawTextEx(
            font,
            startTimeString,
            Vector2(x: geometry.xStart + style.hPadding, y: geometry.yStart + style.vPadding),
            style.fontSize,
            0,
            style.color
        )
        DrawTextEx(
            font,
            endTimeString,
            Vector2(x: geometry.xStart + endTimeOffset.x, y: geometry.yStart + endTimeOffset.y),
            style.fontSize,
            0,
            style.color
        )
    }

    private func drawSummary() {
        let font = UIFonts.getFont(style.font)

        for (index, line) in summaryLines.reversed().enumerated() {
            let lineX = geometry.xStart + style.hPadding
            let lineY = geometry.yEnd - summaryBottomPadding - (style.lineHeight * Float(index + 1))
            DrawTextEx(
                font,
                line,
                Vector2(x: lineX, y: lineY),
                style.fontSize,
                0,
                style.color
            )
        }
    }
}
