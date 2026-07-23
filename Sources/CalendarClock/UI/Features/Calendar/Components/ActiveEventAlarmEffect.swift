import Foundation
import CRayLib

@MainActor private let shader = UIShaders.getShader(.waveEffect)
@MainActor private let texture = LoadRenderTexture(Int32(SCREEN_WIDTH), Int32(CONTENT_HEIGHT))
@MainActor private let centerPointLoc = GetShaderLocation(shader, "centerPoint")
@MainActor private let timeLoc = GetShaderLocation(shader, "time")
@MainActor private let baseColorLoc = GetShaderLocation(shader, "baseColor")
@MainActor private let screenSizeLoc = GetShaderLocation(shader, "screenSize")
@MainActor private let baseBrightnessLoc = GetShaderLocation(shader, "baseBrightness")

@MainActor
struct ActiveEventAlarmEffect {
    static func draw(
        time: CalendarUIUtils.TimeInfo,
        appState: AppStateData,
        eventsOrder: CalendarUIUtils.EventsOrder
    ) {
        guard let activeEvent = eventsOrder.activeEvent,
            activeEvent.event.id != appState.calendar.confirmedApproachingEventId,
            let currentHour = time.components.hour,
            let currentMinute = time.components.minute,
            let activeEventStartDate = activeEvent.event.start.date,
            let activeEventEndDate = activeEvent.event.end.date
        else {
            return
        }

        let calendar = Calendar.current
        let currentTime = currentHour * 60 + currentMinute
        let marginLeft = Utilities.remapValue(
            value: Int32(currentTime),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32((SCREEN_WIDTH * EVENTS_ZOOM) / (EVENTS_ZOOM / (EVENTS_ZOOM - 1)))
        )
        let activeEventStartHour = calendar.component(.hour, from: activeEventStartDate)
        let activeEventStartMinute = calendar.component(.minute, from: activeEventStartDate)
        let activeEventStartTime = activeEventStartHour * 60 + activeEventStartMinute
        let startPosition = Utilities.remapValue(
            value: Int32(activeEventStartTime),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM)
        )
        let activeEventEndHour = calendar.component(.hour, from: activeEventEndDate)
        let activeEventEndMinute = calendar.component(.minute, from: activeEventEndDate)
        let activeEventEndTime = activeEventEndHour * 60 + activeEventEndMinute
        let endPosition = Utilities.remapValue(
            value: Int32(activeEventEndTime),
            inMin: Int32(DAY_START_TIME),
            inMax: Int32(DAY_END_TIME),
            outMin: 0,
            outMax: Int32(SCREEN_WIDTH * EVENTS_ZOOM)
        )

        let centerX = Float(startPosition - marginLeft + (endPosition - startPosition) / 2)
        let centerY = EVENTS_HEIGHT / 2

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
                width: Float(texture.texture.width), 
                height: -Float(texture.texture.height)
            )
            let position = Vector2(x: 0, y: 0)
            DrawTextureRec(texture.texture, sourceRec, position, .white)
        EndShaderMode()
    }
}