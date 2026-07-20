import Foundation
import CRayLib

@MainActor
struct Renderer {
    private let appState: AppState
    private let uiFonts: UIFonts

    init(appState: AppState) {
        self.appState = appState
        self.uiFonts = UIFonts()
    }

    func start() {
        let configFlags = FLAG_WINDOW_UNDECORATED.rawValue
        SetConfigFlags(configFlags)
        #if os(macOS)
            SetConfigFlags(FLAG_WINDOW_HIGHDPI.rawValue)
        #endif

        InitWindow(Int32(SCREEN_WIDTH), Int32(SCREEN_HEIGHT), "Calendar Clock")
        SetTargetFPS(UI_FPS)
        SetExitKey(Int32(KEY_NULL.rawValue))
        
        uiFonts.load()

        defer {
            uiFonts.unload()
            CloseWindow()
        }

        while !WindowShouldClose() && !KEY_Q.isPressed {
            BeginDrawing()
            ClearBackground(.black)

            CalendarView.draw(appState: appState)

            EndDrawing()
        }
    }
}