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
        let marginLeft = Utilities.remapValue(
            value: Int32(currentTime),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32((SCREEN_WIDTH * EVENTS_ZOOM) / (EVENTS_ZOOM / (EVENTS_ZOOM - 1))),
        )
        let eventStartHour = calendar.component(.hour, from: eventStartDate)
        let eventStartMinute = calendar.component(.minute, from: eventStartDate)
        let eventStartTime = eventStartHour * 60 + eventStartMinute
        let startPosition = Utilities.remapValue(
            value: Int32(eventStartTime),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM),
        )
        let eventEndHour = calendar.component(.hour, from: eventEndDate)
        let eventEndMinute = calendar.component(.minute, from: eventEndDate)
        let eventEndTime = eventEndHour * 60 + eventEndMinute
        let endPosition = Utilities.remapValue(
            value: Int32(eventEndTime),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM)
        )

        let xStart = startPosition - marginLeft
        let xEnd = endPosition - marginLeft
        let yEnd = Int32(CONTENT_HEIGHT)
        var yStart = Int32(CONTENT_HEIGHT - EVENTS_HEIGHT)

        // less than 100%
        if positionedEvent.height < 100 {
            let yStartOnePercent = Float(yStart) / 100
            yStart += Int32(yStartOnePercent * Float(100 - positionedEvent.height))
        }

        let isNightTime = CalendarUIUtils.isNightTime(time)
        let brightnessFactor = isNightTime ? appState.brightness.nightFactor : appState.brightness.dayFactor
        var color = ColorBrightness(CALENDAR_EVENT_COLORS[index], brightnessFactor)
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

        let chamferSize: Int32 = 4
        let lineThickness: Int32 = 1

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
        DrawRectangle(xStart, yStart + chamferSize, xEnd - xStart, yEnd - yStart, fill)
        DrawRectangle(chamferLeftXEnd, yStart, chamferRightXStart - chamferLeftXEnd, yEnd - yStart, fill)
        DrawTriangle(
            Vector2(x: Float(chamferLeftXEnd), y: Float(yStart + chamferSize)),
            Vector2(x: Float(chamferLeftXEnd), y: Float(yStart)),
            Vector2(x: Float(chamferLeftXStart), y: Float(yStart + chamferSize)),
            fill
        )
        DrawTriangle(
            Vector2(x: Float(chamferRightXEnd), y: Float(yStart + chamferSize)),
            Vector2(x: Float(chamferRightXStart), y: Float(yStart)),
            Vector2(x: Float(chamferRightXStart), y: Float(yStart + chamferSize)),
            fill
        )

        // border
        DrawLine(xStart, yStart + chamferSize, xStart, yEnd, borderColor)
        DrawLine(chamferLeftXStart, yStart + chamferSize, chamferLeftXEnd, yStart, borderColor)
        DrawLine(xStart + chamferSize, yStart, chamferRightXStart, yStart, borderColor)
        DrawLine(chamferRightXStart, yStart, chamferRightXEnd, yStart + chamferSize, borderColor)
        DrawLine(xEnd, yStart + chamferSize, xEnd, yEnd, borderColor)

        let isTinyEvent = xEnd - xStart <= 40
        let hPadding: Int32 = isTinyEvent ? 3 : 4
        let vPadding: Int32 = 5
        let lineHeight: Int32 = 10
        var timeSpace: Int32 = 20
        let unscii8Font = UIFonts.getFont(.unscii8)
        let silkscreen3x7Font = UIFonts.getFont(.silkscreen3x7)
        let font = isTinyEvent ? silkscreen3x7Font : unscii8Font
        let fontSize: Int32 = isTinyEvent ? 9 : 8
        let characterWidth: Int32 = isTinyEvent ? 4 : 8
        var boxWidth = xEnd - xStart - hPadding * 2

        while boxWidth % fontSize != 0 {
            boxWidth += 1
        }

        // time
        var eventStartTimeString = "\(CalendarUIUtils.formatTo12H(eventStartHour))"
        if (eventStartMinute != 0) {
            eventStartTimeString += ":\(eventStartMinute)"
        }
        let eventStartTimeStringSize = Int32(eventStartTimeString.count) * fontSize
        var eventEndTimeString = "\(CalendarUIUtils.formatTo12H(eventEndHour))"
        if (eventEndMinute != 0) {
            eventEndTimeString += ":\(eventEndMinute)"
        }
        let eventEndTimeStringSize = Int32(eventEndTimeString.count) * fontSize

        var endTimeX = Float(xStart + hPadding + boxWidth - eventEndTimeStringSize)
        var endTimeY = Float(yStart + vPadding)
        if eventStartTimeStringSize + eventEndTimeStringSize + fontSize > boxWidth {
            endTimeX = Float(xStart + hPadding)
            endTimeY = Float(yStart + vPadding + lineHeight)
            timeSpace += lineHeight
        }

        DrawTextEx(
            font,
            eventStartTimeString,
            Vector2(x: Float(xStart + hPadding), y: Float(yStart + vPadding)),
            Float(fontSize),
            0,
            color
        )
        DrawTextEx(
            font,
            eventEndTimeString,
            Vector2(x: endTimeX, y: endTimeY),
            Float(fontSize),
            0,
            color
        )

        // summary
        let summaryBoxHeight = yEnd - yStart - timeSpace
        let summary = (event.summary ?? "(untitled)").trimmingPrefix(" ")
        var lines: [String] = []
        var curLine = ""
        var curLineWidth: Int32 = 0

        for (index, character) in summary.enumerated() {
            if curLineWidth + characterWidth > boxWidth || index == summary.count - 1 {
                if index == summary.count - 1 {
                    curLine.append(character)
                }
                curLine.trimPrefix(" ")
                lines.append(curLine)
                curLine = ""
                curLineWidth = 0
                if Int32(lines.count) * lineHeight >= summaryBoxHeight {
                    break
                }
            }
            curLine.append(character)
            curLineWidth += characterWidth
        }

        for (index, line) in lines.enumerated() {
            DrawTextEx(
                font,
                line,
                Vector2(x: Float(xStart + hPadding), y: Float(yStart + timeSpace + (10 * Int32(index)))),
                Float(fontSize),
                0,
                color
            )
        }
    }
}
