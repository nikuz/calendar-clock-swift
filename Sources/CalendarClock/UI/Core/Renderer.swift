import Foundation
import CRayLib

@MainActor
struct Renderer {
    private let appState: AppState
    private let uiFonts: UIFonts
    private let uiSounds: UISounds

    init(appState: AppState) {
        self.appState = appState
        self.uiFonts = UIFonts()
        self.uiSounds = UISounds()
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

        defer {
            uiFonts.unload()
            uiSounds.unload()
            CloseWindow()
        }

        while !WindowShouldClose() {
            BeginDrawing()
            ClearBackground(.black)

            CalendarView.draw(appState: appState)

            EndDrawing()
        }
    }
}