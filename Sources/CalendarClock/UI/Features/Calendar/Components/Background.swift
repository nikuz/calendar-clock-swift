import Foundation
import CRayLib

@MainActor
struct CalendarBackground {
    static func draw(time: CalendarUIUtils.TimeInfo, appState: AppStateData) {
        // the lamp fills the screen with light of its own, the picture would
        // only be a shape cut out of it
        if CalendarUIUtils.isNightTime(time) || !appState.backgroundVisible || appState.lamp.isActive {
            return
        }

        DrawTexture(UITextures.getTexture(.mountainsNight), 0, 0, .white)
    }
}
