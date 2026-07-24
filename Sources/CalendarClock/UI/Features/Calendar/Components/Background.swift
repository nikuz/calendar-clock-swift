import Foundation
import CRayLib

@MainActor
struct CalendarBackground {
    static func draw(time: CalendarUIUtils.TimeInfo, appState: AppStateData) {
        if CalendarUIUtils.isNightTime(time) || !appState.backgroundVisible {
            return
        }


        DrawTexture(UITextures.getTexture(.mountainsNight), 0, 0, .white)
    }
}