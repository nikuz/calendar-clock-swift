import Foundation
import CRayLib

@MainActor
struct Renderer {
    private let appState: AppState
    private let unscii16FontPath: String
    private let unscii8FontPath: String
    private let tiny5FontPath: String

    init(appState: AppState) {
        self.appState = appState
        guard let unscii16FontPath = Bundle.module.path(forResource: "unscii-16", ofType: "ttf", inDirectory: "fonts"),
            let unscii8FontPath = Bundle.module.path(forResource: "unscii-8", ofType: "ttf", inDirectory: "fonts"),
            let tiny5FontPath = Bundle.module.path(forResource: "Tiny5", ofType: "ttf", inDirectory: "fonts") else {
            fatalError("Font not found")
        }
        self.unscii16FontPath = unscii16FontPath
        self.unscii8FontPath = unscii8FontPath
        self.tiny5FontPath = tiny5FontPath
    }

    func start() {
        let configFlags = FLAG_WINDOW_UNDECORATED.rawValue | FLAG_WINDOW_RESIZABLE.rawValue
        SetConfigFlags(UInt32(configFlags))

        InitWindow(Int32(SCREEN_WIDTH), Int32(SCREEN_HEIGHT), "Calendar Clock")
        SetTargetFPS(60)
        
        let fonts = [
            "unscii16": LoadFont(unscii16FontPath),
            "unscii8": LoadFont(unscii8FontPath),
            "tiny5": LoadFont(tiny5FontPath),
        ]

        defer {
            for font in fonts {
                UnloadFont(font.value)
            }
            CloseWindow()
        }

        while !WindowShouldClose() && !KEY_Q.isPressed {
            BeginDrawing()
            ClearBackground(.black)

            // #if DEBUG
            //     DrawRectangle(0, 0, SCREEN_WIDTH, CONTENT_HEIGHT, .darkGray)
            // #endif

            CalendarView.draw(appState: appState, fonts: fonts)

            EndDrawing()
        }
    }
}