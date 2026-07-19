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
        let unscii8Font = UIFonts.getFont(.unscii8)

        let marginLeft = Utilities.remapValue(
            value: Int32(currentHour * 60 + currentMinute),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32((SCREEN_WIDTH * EVENTS_ZOOM) / (EVENTS_ZOOM / (EVENTS_ZOOM - 1))),
        )
        let eventStartHour = calendar.component(.hour, from: eventStartDate)
        let eventStartMinute = eventStartHour * 60 + calendar.component(.minute, from: eventStartDate)
        let startPosition = Utilities.remapValue(
            value: Int32(eventStartMinute),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM),
        )
        let eventEndHour = calendar.component(.hour, from: eventEndDate)
        let eventEndMinute = eventEndHour * 60 + calendar.component(.minute, from: eventEndDate)
        let endPosition = Utilities.remapValue(
            value: Int32(eventEndMinute),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM)
        )

        // let dateString: String

        // if let date = event.start.date {
        //     let hour = Calendar.current.component(.hour, from: date)
        //     let minute = Calendar.current.component(.minute, from: date)
        //     dateString = "\(hour):\(minute)"
        // } else {
        //     dateString = "unknown date"
        // }

        // let eventText = "\(summary) — \(dateString)"
        let fontSize: Float = 8.0

        // let width = Int32((endPosition - startPosition).rounded())
        let xStart = startPosition - marginLeft
        let xEnd = endPosition - marginLeft
        let yStart = Int32(CONTENT_HEIGHT / 2)
        let yEnd = Int32(CONTENT_HEIGHT)

        let color = ColorBrightness(EVENT_COLORS[index], appState.brightness.factor)

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

        let summary = event.summary ?? "(untitled)"
        DrawTextEx(unscii8Font, summary, Vector2(x: Float(xStart), y: Float(yStart + 10)), fontSize, 0, color)
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