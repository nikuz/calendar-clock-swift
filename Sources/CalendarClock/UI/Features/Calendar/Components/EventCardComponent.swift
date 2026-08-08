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
    private var time: CalendarUIUtils.TimeInfo
    private let event: CalendarEvent
    private let index: Int
    private let isHighlighted: Bool
    private let isSelected: Bool

    private var outsideLeftEdgeIndex: Int? = nil
    private var outsideRightEdgeIndex: Int? = nil

    private let confirmedApproachingEventId: String?

    private var eventTime: EventCardTime
    private var geometry: EventCardGeometry
    private var style: EventCardStyle

    init?(
        positionedEvent: PositionedCalendarEvent, 
        index: Int, 
        time: CalendarUIUtils.TimeInfo,
        appState: AppStateData,
        eventsOrder: CalendarUIUtils.EventsOrder,
        eventsNavigation: CalendarUIUtils.EventsNavigation? = nil,
        outsideLeftEdgeIndex: inout Int,
        outsideRightEdgeIndex: inout Int,
        isHighlighted: Bool = false,
        isSelected: Bool = false,
    ) {
        event = positionedEvent.event
        
        guard let eventStartHour = event.start.hour, 
            let eventStartMinute = event.start.minute,
            let eventEndHour = event.end.hour,
            let eventEndMinute = event.end.minute
        else {
            return nil
        }

        self.index = index
        self.time = time
        self.isHighlighted = isHighlighted
        self.isSelected = isSelected

        eventTime = EventCardTime(
            startHour: eventStartHour, 
            startMinute: eventStartMinute, 
            endHour: eventEndHour, 
            endMinute: eventEndMinute,
        )
        style = EventCardStyle()

        confirmedApproachingEventId = appState.calendar.confirmedApproachingEventId

        let eventRectangle = CalendarUIUtils.getEventRectangle(
            time: time,
            event: event,
            eventsNavigation: eventsNavigation,
        )

        // is short event
        if eventRectangle.width <= 40.0 {
            style.font = silkscreen3x7Font
            style.fontSize = 9.0
            style.characterWidth = 4.0
            style.hPadding = 3.0
        }

        let currentHour = time.hour
        let currentMinute = time.minute
        let currentSecond = time.second
        let currentTime = currentHour * 60 + currentMinute
        let eventEndTime = eventEndHour * 60 + eventEndMinute
        let isNightTime = CalendarUIUtils.isNightTime(time)
        let brightness = appState.brightness
        var brightnessFactor = isNightTime ? brightness.nightFactor : brightness.dayFactor

        if isHighlighted {
            brightnessFactor = 0 // brightness factor range is -1..0, 0 means full brightness
        }

        style.color = ColorBrightness(CALENDAR_EVENT_COLORS[index], brightnessFactor)
        style.borderColor = style.color
        style.fill = .black

        // gray out the past events
        if currentTime > eventEndTime && !isHighlighted {
            style.color = ColorBrightness(.darkGray, brightnessFactor)
            style.borderColor = style.color
        }

        let activeEvent = eventsOrder.activeEvent
        let approachingEvent = eventsOrder.approachingEvent
        let isActiveEvent =
            (approachingEvent != nil && event.id == approachingEvent?.event.id)
            || (approachingEvent == nil && activeEvent != nil && event.id == activeEvent?.event.id) 

        if isActiveEvent && (confirmedApproachingEventId == event.id || currentSecond % 2 == 0) {
            style.fill = style.color
            style.color = .black
        }

        let xStart = eventRectangle.x
        let xEnd = eventRectangle.x + eventRectangle.width
        let boxWidth = eventRectangle.width
        let boxContentWidth = boxWidth - style.hPadding * 2.0
        let boxHeight = positionedEvent.height
        var yStart = eventRectangle.y
        let yEnd = eventRectangle.y + eventRectangle.height

        // less than 100%
        if isHighlighted {
            yStart = yStart - CONTENT_HEIGHT / 100 * 5
        } else if boxHeight < 100 {
            let yStartOnePercent = yStart / 100
            yStart += yStartOnePercent * (100.0 - boxHeight)
        }

        geometry = EventCardGeometry(
            xStart: xStart, 
            xEnd: xEnd, 
            yStart: yStart, 
            yEnd: yEnd, 
            boxWidth: boxWidth, 
            boxContentWidth: boxContentWidth, 
            boxHeight: boxHeight,
        )

        // event is behind the left edge of the screen
        if xEnd <= 0 {
            self.outsideLeftEdgeIndex = outsideLeftEdgeIndex
            outsideLeftEdgeIndex += 1
        }

        // event is behind the right edge of the screen
        if xStart > SCREEN_WIDTH {
            self.outsideRightEdgeIndex = outsideRightEdgeIndex
            outsideRightEdgeIndex += 1
        }
    }

    func draw() {
        if outsideLeftEdgeIndex != nil || outsideRightEdgeIndex != nil {
            drawOutside()
        } else {
            drawBox()
            let timeSpace = drawTime()
            drawSummary(timeSpace: timeSpace)
        }
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

        let chamferLeftXStart = geometry.xStart + lineThickness
        let chamferLeftXEnd = geometry.xStart + chamferSize + lineThickness

        #if os(Linux)
            let chamferRightXStart = geometry.xEnd - chamferSize
            let chamferRightXEnd = geometry.xEnd
        #else
            let chamferRightXStart = geometry.xEnd - chamferSize - lineThickness
            let chamferRightXEnd = geometry.xEnd - lineThickness
        #endif

        // filling
        DrawRectangleV(
            Vector2(x: geometry.xStart, y: geometry.yStart + chamferSize), 
            Vector2(x: geometry.boxWidth, y: geometry.yEnd - geometry.yStart), 
            style.fill
        )
        DrawRectangleV(
            Vector2(x: chamferLeftXEnd, y: geometry.yStart), 
            Vector2(x: chamferRightXStart - chamferLeftXEnd, y: geometry.yEnd - geometry.yStart), 
            style.fill
        )
        DrawTriangle(
            Vector2(x: chamferLeftXEnd, y: geometry.yStart + chamferSize),
            Vector2(x: chamferLeftXEnd, y: geometry.yStart),
            Vector2(x: chamferLeftXStart, y: geometry.yStart + chamferSize),
            style.fill
        )
        DrawTriangle(
            Vector2(x: chamferRightXEnd, y: geometry.yStart + chamferSize),
            Vector2(x: chamferRightXStart, y: geometry.yStart),
            Vector2(x: chamferRightXStart, y: geometry.yStart + chamferSize),
            style.fill
        )

        // border
        DrawLineEx(
            Vector2(x: geometry.xStart + lineThickness, y: geometry.yStart + chamferSize), 
            Vector2(x: geometry.xStart + lineThickness, y: geometry.yEnd), 
            lineThickness, 
            style.borderColor
        )
        DrawLineEx(
            Vector2(x: chamferLeftXStart, y: geometry.yStart + chamferSize), 
            Vector2(x: chamferLeftXEnd, y: geometry.yStart), 
            lineThickness, 
            style.borderColor
        )
        DrawLineEx(
            Vector2(x: geometry.xStart + chamferSize, y: geometry.yStart), 
            Vector2(x: chamferRightXStart, y: geometry.yStart), 
            lineThickness, 
            style.borderColor
        )
        DrawLineEx(
            Vector2(x: chamferRightXStart, y: geometry.yStart), 
            Vector2(x: chamferRightXEnd, y: geometry.yStart + chamferSize), 
            lineThickness, 
            style.borderColor
        )
        DrawLineEx(
            Vector2(x: geometry.xEnd - lineThickness, y: geometry.yStart + chamferSize), 
            Vector2(x: geometry.xEnd - lineThickness, y: geometry.yEnd), 
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

    private func drawTime() -> Float {
        var eventStartTimeString = "\(CalendarUIUtils.formatTo12H(eventTime.startHour))"
        if (eventTime.startMinute != 0) {
            eventStartTimeString += ":\(eventTime.startMinute)"
        }
        let eventStartTimeStringSize = Float(eventStartTimeString.count) * style.characterWidth
        var eventEndTimeString = "\(CalendarUIUtils.formatTo12H(eventTime.endHour))"
        if (eventTime.endMinute != 0) {
            eventEndTimeString += ":\(eventTime.endMinute)"
        }
        let eventEndTimeStringSize = Float(eventEndTimeString.count) * style.characterWidth

        var endTimeX = geometry.xStart + style.hPadding + geometry.boxContentWidth - eventEndTimeStringSize
        var endTimeY = geometry.yStart + style.vPadding
        var timeSpace = style.timeSpace

        if eventStartTimeStringSize + eventEndTimeStringSize + style.characterWidth > geometry.boxContentWidth {
            endTimeX = geometry.xStart + style.hPadding
            endTimeY = geometry.yStart + style.vPadding + style.lineHeight
            timeSpace += style.lineHeight
        }

        DrawTextEx(
            style.font,
            eventStartTimeString,
            Vector2(x: geometry.xStart + style.hPadding, y: geometry.yStart + style.vPadding),
            style.fontSize,
            0,
            style.color
        )
        DrawTextEx(
            style.font,
            eventEndTimeString,
            Vector2(x: endTimeX, y: endTimeY),
            style.fontSize,
            0,
            style.color
        )

        return timeSpace
    }

    private func drawSummary(timeSpace: Float) {
        let summaryBoxHeight = geometry.yEnd - geometry.yStart - timeSpace
        let summary = event.summary ?? "(untitled)"
        var lines: [String] = []
        var curLine = ""
        var curLineWidth: Float = 0.0
        var isFullSummaryFit = false

        for (index, character) in summary.enumerated() {
            if curLineWidth + style.characterWidth > geometry.boxContentWidth || index == summary.count - 1 {
                if index == summary.count - 1 {
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

        for (index, line) in lines.reversed().enumerated() {
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
