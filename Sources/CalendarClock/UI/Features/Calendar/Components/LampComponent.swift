import Foundation
import CRayLib

/// The dilation reaches past the edges of the texture, and the light samples a
/// row of it right on the edge. Both have to land back on the edge instead of
/// wrapping around to the other side of the screen, which is what the default
/// wrapping mode would do.
@MainActor private func makeLampTexture() -> RenderTexture2D {
    let target = LoadRenderTexture(Int32(SCREEN_WIDTH), Int32(CONTENT_HEIGHT))
    SetTextureWrap(target.texture, Int32(TEXTURE_WRAP_CLAMP.rawValue))
    return target
}

// the scene, drawn on a fully transparent background: the alpha channel of it
// is the shape the light is cut out of
@MainActor private let contentTexture = makeLampTexture()
// the two passes of the separable dilation that gives the cut out its padding
@MainActor private let horizontalMaskTexture = makeLampTexture()
@MainActor private let maskTexture = makeLampTexture()

@MainActor private let maskShader = UIShaders.getShader(.lampMask)
@MainActor private let maskTexelStepLoc = GetShaderLocation(maskShader, "texelStep")

@MainActor private let lampShader = UIShaders.getShader(.lamp)
@MainActor private let lampColorLoc = GetShaderLocation(lampShader, "lampColor")

/// A render texture is stored upside down, and raylib turns it back up when the
/// source rectangle is given a negative height. Every pass below draws one of
/// them over a target of its own size, so they all share this rectangle: the
/// coordinates the quad is textured with then run the same way down the screen
/// as the scene does, and the texel a fragment reads is the pixel it covers.
@MainActor
private func uprightSource(_ texture: Texture2D) -> Rectangle {
    Rectangle(
        x: 0,
        y: 0,
        width: Float(texture.width),
        height: -Float(texture.height),
    )
}

/// Turns the screen into a lamp: a solid field of light with the clock and the
/// events cut out of it, so the room gets lit without losing the scene.
///
/// `L` turns it on, `Escape` turns it off, the up and the down arrows run the
/// brightness, the left and the right ones turn the color dial.
@MainActor
struct CalendarLampComponent {
    /// Repeat of a held arrow key. The press itself moves the brightness by a
    /// single percent, so a tap is always exactly one step. Holding the key
    /// starts the value running after a short delay, and the longer it is held
    /// the faster it goes: the whole range is a bit over two seconds away, and
    /// any single percent of it is still reachable.
    private struct HeldKeyRepeat {
        /// How long the key has to be held before the value starts running.
        private static let initialDelay = 0.35  // seconds
        private static let startRate: Float = 8  // percent per second
        private static let acceleration: Float = 60  // percent per second, per second
        private static let maximumRate: Float = 120  // percent per second

        private var heldTime = 0.0
        /// The fraction of a percent the frames so far add up to.
        private var carried: Float = 0

        mutating func reset() {
            heldTime = 0
            carried = 0
        }

        /// Whole percent the brightness has to move by in this frame.
        mutating func steps(frameTime: Double) -> Int {
            heldTime += frameTime

            guard heldTime > Self.initialDelay else {
                return 0
            }

            let heldAfterDelay = Float(heldTime - Self.initialDelay)
            let rate = min(Self.startRate + heldAfterDelay * Self.acceleration, Self.maximumRate)

            carried += rate * Float(frameTime)
            let steps = carried.rounded(.down)
            carried -= steps

            return Int(steps)
        }
    }

    /// A frame longer than this is a stall rather than a frame, and the held
    /// key must not jump the brightness across the whole dial because of it.
    private static let maximumFrameTime = 0.25  // seconds

    private static var lastFrameTimestamp = GetTime()
    private static var brightnessRepeat = HeldKeyRepeat()
    /// Which of the two arrows the current repeat belongs to, 0 while neither
    /// of them is held.
    private static var brightnessDirection = 0

    /// What the lamp did with the keyboard of this frame.
    enum KeyboardOutcome {
        /// The lamp is off and none of its keys was pressed, the keys of this
        /// frame belong to the scene.
        case passed
        /// The lamp took the keys of this frame.
        case taken
        /// `Escape` turned the lamp off. The scene gets no other key of this
        /// frame, but it is given the chance to let that `Escape` answer a
        /// ringing alarm as well.
        case turnedOffTheLamp
    }

    /// Handles the keys of the lamp. While the lamp is on it owns the keyboard:
    /// the arrows drive the light instead of the events, and `Escape` turns the
    /// lamp off instead of reaching the scene behind it.
    static func handleKeyboardShortcuts(appState: AppState, isNightTime: Bool) -> KeyboardOutcome {
        let now = GetTime()
        let frameTime = min(now - lastFrameTimestamp, maximumFrameTime)
        lastFrameTimestamp = now

        guard appState.current.lamp.isActive else {
            guard KEY_L.isPressed else {
                return .passed
            }
            turnOn(appState: appState, isNightTime: isNightTime)
            return .taken
        }

        if KEY_ESCAPE.isPressed {
            appState.update { $0.lamp.isActive = false }
            return .turnedOffTheLamp
        }

        adjustBrightness(appState: appState, frameTime: frameTime)
        adjustColor(appState: appState)

        return .taken
    }

    /// The lamp always opens on the same light: 2700K at the brightness the
    /// rest of the application is drawn with, so it never comes on brighter
    /// than the room the previous session left it in.
    private static func turnOn(appState: AppState, isNightTime: Bool) {
        appState.update { state in
            let globalBrightnessFactor = isNightTime
                ? state.brightness.nightFactor
                : state.brightness.dayFactor

            state.lamp = AppStateLamp(
                isActive: true,
                brightness: AppStateLamp.brightness(for: globalBrightnessFactor),
                colorIndex: 0,
            )
        }

        brightnessRepeat.reset()
        brightnessDirection = 0
    }

    private static func adjustBrightness(appState: AppState, frameTime: Double) {
        let direction: Int
        if KEY_UP.isDown {
            direction = 1
        } else if KEY_DOWN.isDown {
            direction = -1
        } else {
            brightnessRepeat.reset()
            brightnessDirection = 0
            return
        }

        var steps = 0

        // the key has just been pressed, or the other one has taken over: one
        // step right away, and the acceleration starts from the beginning
        if direction != brightnessDirection {
            brightnessDirection = direction
            brightnessRepeat.reset()
            steps = 1
        } else {
            steps = brightnessRepeat.steps(frameTime: frameTime)
        }

        guard steps != 0 else {
            return
        }

        appState.update { state in
            state.lamp.brightness = min(
                max(
                    state.lamp.brightness + steps * direction,
                    AppStateLamp.brightnessMin,
                ),
                AppStateLamp.brightnessMax,
            )
        }
    }

    /// The colors are a dial rather than a list: both ends of it wrap around.
    private static func adjustColor(appState: AppState) {
        let direction: Int
        if KEY_LEFT.isPressed || KEY_LEFT.isPressedRepeat {
            direction = -1
        } else if KEY_RIGHT.isPressed || KEY_RIGHT.isPressedRepeat {
            direction = 1
        } else {
            return
        }

        appState.update { state in
            let colorsCount = LAMP_COLORS.count
            state.lamp.colorIndex = (state.lamp.colorIndex + direction + colorsCount) % colorsCount
        }
    }

    /// Draws the scene into the texture the cut out is made of and dilates it
    /// by the padding. Renders into textures, so it has to run before the frame
    /// on the screen is opened.
    static func renderMask(drawContent: () -> Void) {
        BeginTextureMode(contentTexture)
        // the scene on nothing: what it covers is what the light is cut out of
        ClearBackground(.blank)
        drawContent()
        EndTextureMode()

        dilate(
            source: contentTexture.texture,
            into: horizontalMaskTexture,
            stepDirection: Vector2(x: 1, y: 0),
        )
        dilate(
            source: horizontalMaskTexture.texture,
            into: maskTexture,
            stepDirection: Vector2(x: 0, y: 1),
        )
    }

    private static func dilate(
        source: Texture2D,
        into target: RenderTexture2D,
        stepDirection: Vector2,
    ) {
        var texelStep = Vector2(
            x: stepDirection.x / Float(source.width),
            y: stepDirection.y / Float(source.height),
        )

        SetShaderValue(maskShader, maskTexelStepLoc, &texelStep, Int32(SHADER_UNIFORM_VEC2.rawValue))

        BeginTextureMode(target)
            ClearBackground(.blank)
            // the mask the shader writes has to land in the target as it is,
            // ordinary alpha blending would multiply it by itself on the way
            BeginBlendMode(Int32(BLEND_ALPHA_PREMULTIPLY.rawValue))
            BeginShaderMode(maskShader)
                // the target has the size of the source: one to one, so every
                // fragment reads the very texel it stands for
                DrawTextureRec(source, uprightSource(source), Vector2(x: 0, y: 0), .white)
            EndShaderMode()
            EndBlendMode()
        EndTextureMode()
    }

    /// Fills the screen with the light, leaving the mask of the scene dark.
    /// Drawn before the scene itself, which goes on top of it.
    static func draw(appState: AppStateData) {
        let lamp = appState.lamp
        // dimmed here rather than in the shader: the strip and the screen under
        // it are painted by two different means, and both have to arrive at the
        // very same eight bit color or the seam between them would show
        let color = ColorBrightness(
            LAMP_COLORS[lamp.colorIndex % LAMP_COLORS.count],
            lamp.intensity - 1.0,
        )

        // the clock and the events only live in the content strip, the rest of
        // the screen is a plain field of light with nothing to cut out of it
        DrawRectangleV(
            Vector2(x: 0, y: CONTENT_HEIGHT),
            Vector2(x: SCREEN_WIDTH, y: SCREEN_HEIGHT - CONTENT_HEIGHT),
            color,
        )

        var lampColor = Vector4(
            x: Float(color.r) / 255.0,
            y: Float(color.g) / 255.0,
            z: Float(color.b) / 255.0,
            w: 1.0,
        )

        SetShaderValue(lampShader, lampColorLoc, &lampColor, Int32(SHADER_UNIFORM_VEC4.rawValue))

        BeginShaderMode(lampShader)
            // the mask covers the strip one to one, so the quad carries the
            // coordinates of it and the shader has no mapping left to get wrong
            DrawTextureRec(
                maskTexture.texture,
                uprightSource(maskTexture.texture),
                Vector2(x: 0, y: 0),
                .white,
            )
        EndShaderMode()
    }
}
