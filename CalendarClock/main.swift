import CRayLib;

let configFlags = FLAG_WINDOW_UNDECORATED.rawValue | FLAG_WINDOW_RESIZABLE.rawValue;
SetConfigFlags(configFlags);

InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "");
SetWindowPosition(0, 0);
SetTargetFPS(60);

while !WindowShouldClose() {
    BeginDrawing();
    ClearBackground(COLOR_RAYWHITE);
    
    let text = "Calendar Clock";
    let fontSize: Int32 = 20;
    let textWidth = MeasureText(text, fontSize);
    let x = (GetScreenWidth() / 2) - (textWidth / 2);
    let y = (GetScreenHeight() / 2) - (fontSize / 2);
    
    DrawText(text, x, y, fontSize, COLOR_DARKGRAY);
    
    EndDrawing();
}

CloseWindow();
