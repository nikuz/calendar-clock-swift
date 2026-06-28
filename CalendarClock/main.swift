import CRayLib

let configFlags = FLAG_WINDOW_UNDECORATED.rawValue | FLAG_WINDOW_RESIZABLE.rawValue
SetConfigFlags(configFlags)

InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "")
SetTargetFPS(60)

while !WindowShouldClose() && !KEY_Q.isPressed {
    BeginDrawing()
    ClearBackground(COLOR_BLACK)
    
    let text = "Calendar Clock"
    let fontSize: Int32 = 20
    let textWidth = MeasureText(text, fontSize)
    let x = (SCREEN_WIDTH / 2) - (textWidth / 2)
    let y = (CONTENT_HEIGHT / 2) - (fontSize / 2)

    DrawText(text, x, y, fontSize, COLOR_YELLOW)
    
    EndDrawing()
}

CloseWindow()
