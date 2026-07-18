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
        let configFlags = FLAG_WINDOW_UNDECORATED.rawValue | FLAG_WINDOW_RESIZABLE.rawValue
        SetConfigFlags(UInt32(configFlags))

        InitWindow(Int32(SCREEN_WIDTH), Int32(SCREEN_HEIGHT), "Calendar Clock")
        SetTargetFPS(UI_FPS)
        
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