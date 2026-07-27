import Foundation
import CRayLib

@MainActor private let shader = UIShaders.getShader(.waveEffect)
@MainActor private let backgroundTexture = LoadRenderTexture(Int32(SCREEN_WIDTH), Int32(CONTENT_HEIGHT))
@MainActor private let centerPointLoc = GetShaderLocation(shader, "centerPoint")
@MainActor private let timeLoc = GetShaderLocation(shader, "time")
@MainActor private let baseColorLoc = GetShaderLocation(shader, "baseColor")
@MainActor private let screenSizeLoc = GetShaderLocation(shader, "screenSize")
@MainActor private let baseBrightnessLoc = GetShaderLocation(shader, "baseBrightness")

@MainActor
struct CalendarActiveEventAlarmEffect {
    static func draw(
        time: CalendarUIUtils.TimeInfo,
        appState: AppStateData,
        eventsOrder: CalendarUIUtils.EventsOrder,
        eventsNavigation: CalendarUIUtils.EventsNavigation? = nil,
    ) {
        guard let activeEvent = eventsOrder.activeEvent,
            activeEvent.event.id != appState.calendar.confirmedApproachingEventId
        else {
            return
        }

        let eventRectangle = CalendarUIUtils.getEventRectangle(
            time: time,
            event: activeEvent.event,
            eventsNavigation: eventsNavigation,
        )

        let centerX = eventRectangle.x + eventRectangle.width / 2
        let centerY = eventRectangle.height / 2

        let raylibColor = ColorBrightness(CALENDAR_EVENT_COLORS[activeEvent.index], appState.brightness.dayFactor)
        
        var glslColor = Vector4(
            x: Float(raylibColor.r) / 255.0,
            y: Float(raylibColor.g) / 255.0,
            z: Float(raylibColor.b) / 255.0,
            w: Float(raylibColor.a) / 255.0,
        )
        
        var center = Vector2(x: centerX, y: centerY)
        var screenSize = Vector2(x: SCREEN_WIDTH, y: CONTENT_HEIGHT)
        var currentRenderTime = Float(GetTime())
        var baseBrightness = Float(appState.brightness.dayFactor)

        SetShaderValue(shader, centerPointLoc, &center, Int32(SHADER_UNIFORM_VEC2.rawValue))
        SetShaderValue(shader, timeLoc, &currentRenderTime, Int32(SHADER_UNIFORM_FLOAT.rawValue))
        SetShaderValue(shader, baseColorLoc, &glslColor, Int32(SHADER_UNIFORM_VEC4.rawValue))
        SetShaderValue(shader, screenSizeLoc, &screenSize, Int32(SHADER_UNIFORM_VEC2.rawValue))
        SetShaderValue(shader, baseBrightnessLoc, &baseBrightness, Int32(SHADER_UNIFORM_FLOAT.rawValue))

        BeginShaderMode(shader)
            let sourceRec = Rectangle(
                x: 0, 
                y: 0, 
                width: Float(backgroundTexture.texture.width), 
                height: -Float(backgroundTexture.texture.height)
            )
            let position = Vector2(x: 0, y: 0)
            DrawTextureRec(backgroundTexture.texture, sourceRec, position, .white)
        EndShaderMode()
    }
}