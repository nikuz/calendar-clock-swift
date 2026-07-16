import CRayLib

@MainActor
struct Renderer {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func start() {
        let configFlags = FLAG_WINDOW_UNDECORATED.rawValue | FLAG_WINDOW_RESIZABLE.rawValue
        SetConfigFlags(UInt32(configFlags))

        InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Calendar Clock")
        SetTargetFPS(60)

        defer {
            CloseWindow()
        }

        while !WindowShouldClose() && !KEY_Q.isPressed {
            BeginDrawing()
            ClearBackground(COLOR_BLACK)

            CalendarView.draw(appState: appState)

            EndDrawing()
        }
    }
}