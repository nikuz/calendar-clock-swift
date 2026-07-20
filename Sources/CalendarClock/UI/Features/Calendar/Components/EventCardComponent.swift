import Foundation
import CRayLib

@MainActor
struct CalendarEventCardComponent {
    static func draw(event: CalendarEvent, index: Int, time: DateComponents, appState: AppStateData) {
        guard let currentHour = time.hour,
            let currentMinute = time.minute,
            let eventStartDate = event.start.date,
            let eventEndDate = event.end.date
        else {
            return;
        }

        let calendar = Calendar.current
        let marginLeft = Utilities.remapValue(
            value: Int32(currentHour * 60 + currentMinute),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32((SCREEN_WIDTH * EVENTS_ZOOM) / (EVENTS_ZOOM / (EVENTS_ZOOM - 1))),
        )
        let eventStartHour = calendar.component(.hour, from: eventStartDate)
        let eventStartMinute = calendar.component(.minute, from: eventStartDate)
        let startPosition = Utilities.remapValue(
            value: Int32(eventStartHour * 60 + eventStartMinute),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM),
        )
        let eventEndHour = calendar.component(.hour, from: eventEndDate)
        let eventEndMinute = calendar.component(.minute, from: eventEndDate)
        let endPosition = Utilities.remapValue(
            value: Int32(eventEndHour * 60 + eventEndMinute),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM)
        )

        let xStart = startPosition - marginLeft
        let xEnd = endPosition - marginLeft
        let yStart = Int32(CONTENT_HEIGHT / 2)
        let yEnd = Int32(CONTENT_HEIGHT)

        var brightnessFactor = appState.brightness.factor
        // dim the past events
        if eventEndHour * 60 + eventEndMinute < currentHour * 60 + currentMinute {
            brightnessFactor -= 0.3
        }
        let color = ColorBrightness(EVENT_COLORS[index], brightnessFactor)

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
        DrawRectangle(xStart, yStart + chamferSize, xEnd - xStart, yEnd - yStart, .black)
        DrawRectangle(chamferLeftXEnd, yStart, chamferRightXStart - chamferLeftXEnd, yEnd - yStart, .black)
        DrawTriangle(
            Vector2(x: Float(chamferLeftXEnd), y: Float(yStart + chamferSize)),
            Vector2(x: Float(chamferLeftXEnd), y: Float(yStart)),
            Vector2(x: Float(chamferLeftXStart), y: Float(yStart + chamferSize)),
            .black
        )
        DrawTriangle(
            Vector2(x: Float(chamferRightXEnd), y: Float(yStart + chamferSize)),
            Vector2(x: Float(chamferRightXStart), y: Float(yStart)),
            Vector2(x: Float(chamferRightXStart), y: Float(yStart + chamferSize)),
            .black
        )

        // border
        DrawLine(xStart, yStart + chamferSize, xStart, yEnd, color)
        DrawLine(chamferLeftXStart, yStart + chamferSize, chamferLeftXEnd, yStart, color)
        DrawLine(xStart + chamferSize, yStart, chamferRightXStart, yStart, color)
        DrawLine(chamferRightXStart, yStart, chamferRightXEnd, yStart + chamferSize, color)
        DrawLine(xEnd, yStart + chamferSize, xEnd, yEnd, color)


        let hPadding: Int32 = 5
        let vPadding: Int32 = 5
        let lineHeight: Int32 = 10
        var timeSpace: Int32 = 20
        let boxWidth = xEnd - xStart - hPadding * 2
        let isTinyEvent = xEnd - xStart <= 40
        let unscii8Font = UIFonts.getFont(.unscii8)
        let tiny5Font = UIFonts.getFont(.tiny5)
        let font = isTinyEvent ? tiny5Font : unscii8Font
        let fontSize: Int32 = isTinyEvent ? 10 : 8

        // time
        var eventStartTime = "\(eventStartHour)"
        if (eventStartMinute != 0) {
            eventStartTime += ":\(eventStartMinute)"
        }
        let eventStartTimeSize = MeasureTextEx(font, eventStartTime, Float(fontSize), 0)
        var eventEndTime = "\(eventEndHour)"
        if (eventEndMinute != 0) {
            eventEndTime += ":\(eventEndMinute)"
        }
        let eventEndTimeSize = MeasureTextEx(font, eventEndTime, Float(fontSize), 0)

        var endTimeX = Float(xStart + hPadding + boxWidth - Int32(eventEndTimeSize.x))
        var endTimeY = Float(yStart + vPadding)
        if eventStartTimeSize.x + eventEndTimeSize.x > Float(boxWidth) {
            endTimeX = Float(xStart + hPadding)
            endTimeY = Float(yStart + vPadding + lineHeight)
            timeSpace += lineHeight
        }

        DrawTextEx(
            font,
            eventStartTime,
            Vector2(x: Float(xStart + hPadding), y: Float(yStart + vPadding)),
            Float(fontSize),
            0,
            color
        )
        DrawTextEx(
            font,
            eventEndTime,
            Vector2(x: endTimeX, y: endTimeY),
            Float(fontSize),
            0,
            color
        )

        // summary
        let summaryBoxHeight = yEnd - yStart - timeSpace
        let summary = event.summary ?? "(untitled)"
        var lines: [String] = []
        var curLine = ""
        var curLineWidth: Int32 = 0

        for (index, character) in summary.enumerated() {
            if curLineWidth + fontSize >= boxWidth || index == summary.count - 1 {
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
            curLineWidth += fontSize
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

let EVENT_COLORS: [Color] = [
    Color(r: 0, g: 255, b: 255, a: 255),  // Cyan
    Color(r: 255, g: 69, b: 0, a: 255),  // Orange Red
    Color(r: 255, g: 166, b: 0, a: 255),  // Orange
    Color(r: 138, g: 43, b: 226, a: 255),  // Blue Violet
    Color(r: 255, g: 0, b: 255, a: 255),  // Magenta
    Color(r: 139, g: 69, b: 19, a: 255),  // Brown
    Color(r: 50, g: 205, b: 50, a: 255),  // Lime
    Color(r: 255, g: 217, b: 0, a: 255),  // Gold
    Color(r: 64, g: 224, b: 208, a: 255),  // Turquoise
    Color(r: 255, g: 192, b: 203, a: 255),  // Pink
    Color(r: 220, g: 20, b: 60, a: 255),  // Crimson
    Color(r: 230, g: 230, b: 250, a: 255),  // Lavender
    Color(r: 128, g: 128, b: 0, a: 255),  // Olive
    Color(r: 0, g: 255, b: 127, a: 255),  // Spring Green
    Color(r: 70, g: 130, b: 180, a: 255),  // Steel Blue
    Color(r: 218, g: 165, b: 32, a: 255),  // Goldenrod
    Color(r: 255, g: 105, b: 180, a: 255),  // Hot Pink
    Color(r: 34, g: 139, b: 34, a: 255),  // Forest Green
    Color(r: 128, g: 0, b: 0, a: 255),  // Maroon
]