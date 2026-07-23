import Foundation
import CRayLib

@MainActor
struct Renderer {
    private let appState: AppState
    private let uiFonts: UIFonts
    private let uiSounds: UISounds
    private let uiShaders: UIShaders

    init(appState: AppState) {
        self.appState = appState
        self.uiFonts = UIFonts()
        self.uiSounds = UISounds()
        self.uiShaders = UIShaders()
    }

    func start() {
        let configFlags = FLAG_WINDOW_UNDECORATED.rawValue
        SetConfigFlags(configFlags)
        #if os(macOS)
            SetConfigFlags(FLAG_WINDOW_HIGHDPI.rawValue)
        #endif

        InitWindow(Int32(SCREEN_WIDTH), Int32(SCREEN_HEIGHT), "Calendar Clock")
        SetTargetFPS(UI_FPS)
        InitAudioDevice()

        #if DEBUG
            SetExitKey(Int32(KEY_Q.rawValue))
        #else 
            SetExitKey(Int32(KEY_NULL.rawValue))
        #endif
        
        uiFonts.load()
        uiSounds.load()
        uiShaders.load()

        defer {
            uiFonts.unload()
            uiSounds.unload()
            uiShaders.unload()
            CloseWindow()
        }

        // let target = LoadRenderTexture(Int32(SCREEN_WIDTH), Int32(CONTENT_HEIGHT))
        // let shader = UIShaders.getShader(.waveEffect)

        while !WindowShouldClose() {
            // // 2. Draw scene to render texture
            // BeginTextureMode(target)
            //     ClearBackground(.rayWhite)
            //     DrawRectangle(50, 24, 80, 80, .darkBlue)
            //     DrawCircle(250, 64, 40, .maroon)
            //     DrawText("SWIFT SHADER RUNNING AT 1024x128", 340, 54, 20, .black)
            // EndTextureMode()

            // BeginDrawing()
            //     ClearBackground(.black)

            //     BeginShaderMode(shader)
            //         // Note: -Float(target.texture.height) flips the texture right-side up
            //         let sourceRec = Rectangle(x: 0, y: 0, width: Float(target.texture.width), height: -Float(target.texture.height))
            //         let position = Vector2(x: 0, y: 0)
            //         DrawTextureRec(target.texture, sourceRec, position, .white)
            //     EndShaderMode()

            //     DrawFPS(10, 10)
            // EndDrawing()

            BeginDrawing()
            ClearBackground(.black)

            CalendarView.draw(appState: appState)

            EndDrawing()
        }
    }
}