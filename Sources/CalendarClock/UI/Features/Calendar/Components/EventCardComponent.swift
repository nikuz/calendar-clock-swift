import Foundation
import CRayLib

@MainActor
struct CalendarEventCardComponent {
    static func draw(
        positionedEvent: PositionedCalendarEvent, 
        index: Int, 
        time: CalendarUIUtils.TimeInfo,
        appState: AppStateData,
        eventsOrder: CalendarUIUtils.EventsOrder,
        eventsNavigation: CalendarUIUtils.EventsNavigation? = nil,
        outsideLeftEdgeIndex: inout Int,
        outsideRightEdgeIndex: inout Int,
    ) {
        let event = positionedEvent.event
        guard let currentHour = time.components.hour,
            let currentMinute = time.components.minute,
            let currentSecond = time.components.second,
            let eventStartDate = event.start.date,
            let eventEndDate = event.end.date
        else {
            return
        }

        let currentTime = currentHour * 60 + currentMinute
        let calendar = Calendar.current
        
        let eventRectangle = CalendarUIUtils.getEventRectangle(
            time: time,
            event: event,
            eventsNavigation: eventsNavigation,
        )
        // let eventRectangle = Rectangle(x: 0.0, y: 10.0, width: 100.0, height: 20.0)
        let xStart = eventRectangle.x
        let xEnd = eventRectangle.x + eventRectangle.width

        let eventStartHour = calendar.component(.hour, from: eventStartDate)
        let eventStartMinute = calendar.component(.minute, from: eventStartDate)

        let eventEndHour = calendar.component(.hour, from: eventEndDate)
        let eventEndMinute = calendar.component(.minute, from: eventEndDate)
        let eventEndTime = eventEndHour * 60 + eventEndMinute

        let isNightTime = CalendarUIUtils.isNightTime(time)
        let brightnessFactor = isNightTime ? appState.brightness.nightFactor : appState.brightness.dayFactor
        var color = ColorBrightness(CALENDAR_EVENT_COLORS[index], brightnessFactor)
        let outsideEventSize: Float = 6.0

        // event is behind the left edge of the screen
        if xEnd <= 0 {
            let x = outsideEventSize / 2 + outsideEventSize
            let y = outsideEventSize / 2 + outsideEventSize + (outsideEventSize * 2 + outsideEventSize / 2) * Float(outsideLeftEdgeIndex)
            DrawCircleV(Vector2(x: x, y: y), outsideEventSize, ColorAlpha(color, 0.5));
            outsideLeftEdgeIndex += 1
            return
        }

        // event is behind the right edge of the screen
        if xStart > SCREEN_WIDTH {
            let x = SCREEN_WIDTH - outsideEventSize / 2 - outsideEventSize
            let y = outsideEventSize / 2 + outsideEventSize + (outsideEventSize * 2 + outsideEventSize / 2) * Float(outsideRightEdgeIndex)
            DrawCircleV(Vector2(x: x, y: y), outsideEventSize, ColorAlpha(color, 0.5));
            outsideRightEdgeIndex += 1
            return
        }

        var yStart = eventRectangle.y
        let yEnd = eventRectangle.y + eventRectangle.height

        // less than 100%
        if positionedEvent.height < 100 {
            let yStartOnePercent = yStart / 100
            yStart += yStartOnePercent * (100.0 - positionedEvent.height)
        }

        var borderColor = color
        var fill: Color = .black

        let activeEvent = eventsOrder.activeEvent
        let approachingEvent = eventsOrder.approachingEvent
        let isActiveEvent =
            (approachingEvent != nil && event.id == approachingEvent?.event.id)
            || (approachingEvent == nil && activeEvent != nil && event.id == activeEvent?.event.id) 

        if isActiveEvent && (appState.calendar.confirmedApproachingEventId == event.id || currentSecond % 2 == 0) {
            fill = color
            color = .black
        }

        // gray out the past events
        if currentTime > eventEndTime {
            color = ColorBrightness(.darkGray, brightnessFactor)
            borderColor = color
        }

        let boxWidth = xEnd - xStart
        let chamferSize: Float = 4.0
        let lineThickness: Float = 1.0

        let chamferLeftXStart = xStart
        let chamferLeftXEnd = xStart + chamferSize

        #if os(Linux)
            let chamferRightXStart = xEnd - chamferSize + lineThickness
            let chamferRightXEnd = xEnd + lineThickness
        #else
            let chamferRightXStart = xEnd - chamferSize
            let chamferRightXEnd = xEnd
        #endif

        // filling
        DrawRectangleV(
            Vector2(x: xStart, y: yStart + chamferSize), 
            Vector2(x: boxWidth, y: yEnd - yStart), 
            fill
        )
        DrawRectangleV(
            Vector2(x: chamferLeftXEnd, y: yStart), 
            Vector2(x: chamferRightXStart - chamferLeftXEnd, y: yEnd - yStart), 
            fill
        )
        DrawTriangle(
            Vector2(x: chamferLeftXEnd, y: yStart + chamferSize),
            Vector2(x: chamferLeftXEnd, y: yStart),
            Vector2(x: chamferLeftXStart, y: yStart + chamferSize),
            fill
        )
        DrawTriangle(
            Vector2(x: chamferRightXEnd, y: yStart + chamferSize),
            Vector2(x: chamferRightXStart, y: yStart),
            Vector2(x: chamferRightXStart, y: yStart + chamferSize),
            fill
        )

        // border
        DrawLineV(Vector2(x: xStart, y: yStart + chamferSize), Vector2(x: xStart, y: yEnd), borderColor)
        DrawLineV(Vector2(x: chamferLeftXStart, y: yStart + chamferSize), Vector2(x: chamferLeftXEnd, y: yStart), borderColor)
        DrawLineV(Vector2(x: xStart + chamferSize, y: yStart), Vector2(x: chamferRightXStart, y: yStart), borderColor)
        DrawLineV(Vector2(x: chamferRightXStart, y: yStart), Vector2(x: chamferRightXEnd, y: yStart + chamferSize), borderColor)
        DrawLineV(Vector2(x: xEnd, y: yStart + chamferSize), Vector2(x: xEnd, y: yEnd), borderColor)

        let isTinyEvent = boxWidth <= 40.0
        let hPadding: Float = isTinyEvent ? 3.0 : 4.0
        let vPadding: Float = 5.0
        let lineHeight: Float = 10.0
        var timeSpace: Float = 20.0
        let unscii8Font = UIFonts.getFont(.unscii8)
        let silkscreen3x7Font = UIFonts.getFont(.silkscreen3x7)
        let font = isTinyEvent ? silkscreen3x7Font : unscii8Font
        let fontSize: Float = isTinyEvent ? 9.0 : 8.0
        let characterWidth: Float = isTinyEvent ? 4.0 : 8.0
        var boxContentWidth = boxWidth - hPadding * 2.0

        while boxContentWidth.truncatingRemainder(dividingBy: fontSize) != 0 {
            boxContentWidth += 1.0
        }

        // time
        var eventStartTimeString = "\(CalendarUIUtils.formatTo12H(eventStartHour))"
        if (eventStartMinute != 0) {
            eventStartTimeString += ":\(eventStartMinute)"
        }
        let eventStartTimeStringSize = Float(eventStartTimeString.count) * characterWidth
        var eventEndTimeString = "\(CalendarUIUtils.formatTo12H(eventEndHour))"
        if (eventEndMinute != 0) {
            eventEndTimeString += ":\(eventEndMinute)"
        }
        let eventEndTimeStringSize = Float(eventEndTimeString.count) * characterWidth

        var endTimeX = xStart + hPadding + boxContentWidth - eventEndTimeStringSize
        var endTimeY = yStart + vPadding
        if eventStartTimeStringSize + eventEndTimeStringSize + fontSize > boxContentWidth {
            endTimeX = xStart + hPadding
            endTimeY = yStart + vPadding + lineHeight
            timeSpace += lineHeight
        }

        DrawTextEx(
            font,
            eventStartTimeString,
            Vector2(x: xStart + hPadding, y: yStart + vPadding),
            fontSize,
            0,
            color
        )
        DrawTextEx(
            font,
            eventEndTimeString,
            Vector2(x: endTimeX, y: endTimeY),
            fontSize,
            0,
            color
        )

        // summary
        let summaryBoxHeight = yEnd - yStart - timeSpace
        let summary = event.summary ?? "(untitled)"
        var lines: [String] = []
        var curLine = ""
        var curLineWidth: Float = 0.0
        var isFullSummaryFit = false
        
        // content filling
        // DrawRectangle(xStart + hPadding, yStart + timeSpace, boxContentWidth, yEnd - yStart - timeSpace, .rayWhite)

        for (index, character) in summary.enumerated() {
            if curLineWidth + characterWidth > boxContentWidth || index == summary.count - 1 {
                if index == summary.count - 1 {
                    // if adding last character exceeds the content width,
                    // append current line to the list of lines and,
                    // add one more line that contains only last character
                    if curLineWidth + characterWidth * 2 > boxContentWidth {
                        curLine.trimPrefix(" ")
                        lines.append(contentsOf: [curLine, "\(character)"])
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
                if Float(lines.count + 1) * lineHeight >= summaryBoxHeight {
                    if !isFullSummaryFit {
                        let lastLine = lines[lines.count - 1]
                        lines[lines.count - 1] = lastLine.dropLast(3) + "..."
                    }
                    break
                }
            }
            curLine.append(character)
            curLineWidth += characterWidth
        }

        for (index, line) in lines.reversed().enumerated() {
            let lineX = xStart + hPadding
            let lineY = yEnd - (lineHeight * Float(index + 1))
            DrawTextEx(
                font,
                line,
                Vector2(x: lineX, y: lineY),
                fontSize,
                0,
                color
            )
        }
    }
}
