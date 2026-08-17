import Foundation
import CRayLib

@MainActor private let unscii8Font = UIFonts.getFont(.unscii8)
@MainActor private let silkscreen3x7Font = UIFonts.getFont(.silkscreen3x7)

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
    var boxHeight: Float = 0.0
}

@MainActor
private struct EventCardStyle {
    var font = unscii8Font
    var fontSize: Float = 8.0
    var hPadding: Float = 4.0
    var vPadding: Float = 5.0
    var lineHeight: Float = 10.0
    var timeSpace: Float = 20.0
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

        /// The user is walking through the events, hidden events are shown.
        var isNavigating: Bool {
            highlightedEventIndex != nil
        }

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
            navigationShift = eventsNavigation?.shift ?? 0
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

    // calculated once, when the event is created
    private let event: CalendarEvent
    private let index: Int
    private let isHidden: Bool
    private let baseColor: Color
    private let eventTime: EventCardTime
    private var eventPosition: CalendarUIUtils.EventPosition
    private var dayStart: Date
    private let summary: String
    private var geometry: EventCardGeometry
    private var style: EventCardStyle
    private var defaultYStart: Float = 0.0
    private var highlightedYStart: Float = 0.0
    private var startTimeString = ""
    private var endTimeString = ""
    private var endTimeOffset = Vector2()
    private var timeSpace: Float = 0.0

    // calculated when the event is created and when it gets highlighted or selected,
    // those are the only states that change the height of the summary box
    private var summaryLines: [String] = []

    // updated on every frame
    private var isHighlighted = false
    private var isSelected = false
    private var isNavigating = false
    private var outsideLeftEdgeIndex: Int? = nil
    private var outsideRightEdgeIndex: Int? = nil

    init?(
        positionedEvent: PositionedCalendarEvent,
        index: Int,
        startOfDay: Date,
    ) {
        let event = positionedEvent.event

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
        self.isHidden = positionedEvent.isHidden
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

        layout(boxHeight: positionedEvent.height)
    }

    /// Everything that only depends on the event itself: sizes, fonts and the
    /// time labels. None of it changes while the event is on the screen.
    private mutating func layout(boxHeight: Float) {
        let boxWidth = round(eventPosition.width)

        if isHidden {
            layoutHiddenLine(boxWidth: boxWidth)
            return
        }

        // is short event
        if boxWidth <= 40.0 {
            style.font = silkscreen3x7Font
            style.fontSize = 9.0
            style.characterWidth = 4.0
            style.hPadding = 3.0
        }

        let boxTop = CONTENT_HEIGHT - EVENTS_HEIGHT

        geometry.boxWidth = boxWidth
        geometry.boxContentWidth = boxWidth - style.hPadding * 2.0
        geometry.boxHeight = boxHeight
        geometry.yEnd = boxTop + EVENTS_HEIGHT

        highlightedYStart = boxTop - CONTENT_HEIGHT / 100 * 5
        defaultYStart = boxTop
        // less than 100%
        if boxHeight < 100 {
            let yStartOnePercent = boxTop / 100
            defaultYStart += yStartOnePercent * (100.0 - boxHeight)
        }
        geometry.yStart = defaultYStart

        startTimeString = "\(CalendarUIUtils.formatTo12H(eventTime.startHour))"
        if eventTime.startMinute != 0 {
            startTimeString += ":\(eventTime.startMinute)"
        }
        endTimeString = "\(CalendarUIUtils.formatTo12H(eventTime.endHour))"
        if eventTime.endMinute != 0 {
            endTimeString += ":\(eventTime.endMinute)"
        }

        let startTimeStringSize = Float(startTimeString.count) * style.characterWidth
        let endTimeStringSize = Float(endTimeString.count) * style.characterWidth

        timeSpace = style.timeSpace
        // both labels don't fit on one line, put the end time below the start time
        if startTimeStringSize + endTimeStringSize + style.characterWidth > geometry.boxContentWidth {
            endTimeOffset = Vector2(x: style.hPadding, y: style.vPadding + style.lineHeight)
            timeSpace += style.lineHeight
        } else {
            endTimeOffset = Vector2(
                x: style.hPadding + geometry.boxContentWidth - endTimeStringSize,
                y: style.vPadding,
            )
        }

        updateSummaryLines()
    }

    /// A hidden event keeps its place on the timeline but is squeezed into a
    /// line at the very bottom of the screen. It carries no text, so none of the
    /// font, time or summary layout applies to it.
    private mutating func layoutHiddenLine(boxWidth: Float) {
        geometry.boxWidth = boxWidth
        geometry.boxContentWidth = boxWidth
        geometry.boxHeight = Self.hiddenLineHeight
        geometry.yEnd = CONTENT_HEIGHT

        defaultYStart = CONTENT_HEIGHT - Self.hiddenLineHeight
        highlightedYStart = CONTENT_HEIGHT - Self.hiddenHighlightedLineHeight
        geometry.yStart = defaultYStart
    }

    /// Splits the summary into the lines that fit into the card.
    /// Only depends on the size of the summary box, so it survives until the
    /// card is highlighted or selected.
    private mutating func updateSummaryLines() {
        let summaryBoxHeight = geometry.yEnd - geometry.yStart - timeSpace
        let summaryLength = summary.count
        var lines: [String] = []
        var curLine = ""
        var curLineWidth: Float = 0.0
        var isFullSummaryFit = false

        for (index, character) in summary.enumerated() {
            if curLineWidth + style.characterWidth > geometry.boxContentWidth || index == summaryLength - 1 {
                if index == summaryLength - 1 {
                    // if adding last character exceeds the content width,
                    // append current line to the list of lines and,
                    // add one more line that contains only last character
                    if curLineWidth + style.characterWidth * 2 > geometry.boxContentWidth {
                        curLine.trimPrefix(" ")
                        lines.append(curLine)
                        if Float(lines.count) * style.lineHeight + style.lineHeight <= summaryBoxHeight {
                            lines.append("\(character)")
                        }
                    } else {
                        curLine.append(character)
                        curLine.trimPrefix(" ")
                        lines.append(curLine)
                    }
                    isFullSummaryFit = true
                } else {
                    curLine.trimPrefix(" ")
                    lines.append(curLine)
                }
                curLine = ""
                curLineWidth = 0
                if Float(lines.count + 1) * style.lineHeight >= summaryBoxHeight {
                    if !isFullSummaryFit {
                        let lastLine = lines[lines.count - 1]
                        lines[lines.count - 1] = lastLine.dropLast(3) + "..."
                    }
                    break
                }
            }
            curLine.append(character)
            curLineWidth += style.characterWidth
        }

        summaryLines = lines
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
        isSelected = context.selectedEventIndex == index
        isNavigating = context.isNavigating

        updateGeometry(context: context)

        // the summary box changed its height, the summary has to be re-wrapped
        if !isHidden && (wasHighlighted != isHighlighted || wasSelected != isSelected) {
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
        let xStart = round(eventPosition.start - context.timeMargin - context.navigationShift)

        geometry.xStart = xStart
        geometry.xEnd = xStart + geometry.boxWidth
        geometry.yStart = isHighlighted ? highlightedYStart : defaultYStart
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
            // a hidden event only shows up while the user walks through the events
            if isNavigating {
                drawHiddenLine()
            }
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
        let sideHeight = yEnd - yStart - chamferSize

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

        // debug: content filling
        // DrawRectangleV(
        //     Vector2(x: geometry.xStart + style.hPadding, y: geometry.yStart + style.timeSpace), 
        //     Vector2(x: geometry.boxContentWidth, y: geometry.yEnd - geometry.yStart - style.timeSpace),
        //     .rayWhite
        // )
    }

    private func drawTime() {
        DrawTextEx(
            style.font,
            startTimeString,
            Vector2(x: geometry.xStart + style.hPadding, y: geometry.yStart + style.vPadding),
            style.fontSize,
            0,
            style.color
        )
        DrawTextEx(
            style.font,
            endTimeString,
            Vector2(x: geometry.xStart + endTimeOffset.x, y: geometry.yStart + endTimeOffset.y),
            style.fontSize,
            0,
            style.color
        )
    }

    private func drawSummary() {
        for (index, line) in summaryLines.reversed().enumerated() {
            let lineX = geometry.xStart + style.hPadding
            let lineY = geometry.yEnd - (style.lineHeight * Float(index + 1))
            DrawTextEx(
                style.font,
                line,
                Vector2(x: lineX, y: lineY),
                style.fontSize,
                0,
                style.color
            )
        }
    }
}
