import Foundation
import CRayLib

@MainActor
struct CalendarErrorComponent {
    static func draw(
        error: Error, 
        time: CalendarUIUtils.TimeInfo,
        appState: AppStateData,
    ) {
        guard !CalendarUIUtils.isNightTime(time) else {
            return
        }

        let unscii8Font = UIFonts.getFont(.unscii8)
        let errorText = error.localizedDescription
        let fontSize: Float = 8.0;
        let textWidth = MeasureTextEx(unscii8Font, errorText, fontSize, 0)
        let position = Vector2(
            x: SCREEN_WIDTH / 2 - textWidth.x / 2, 
            y: CONTENT_HEIGHT  - textWidth.y - 10,
        )
        let color: Color = ColorBrightness(.maroon, appState.brightness.factor)

        DrawTextEx(unscii8Font, errorText, position, fontSize, 0, color)
    }
}