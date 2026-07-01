import CRayLib

let configFlags = FLAG_WINDOW_UNDECORATED.rawValue | FLAG_WINDOW_RESIZABLE.rawValue
SetConfigFlags(configFlags)

InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "")
SetTargetFPS(60)

let calendarProvider = try GoogleCalendarProvider()
let events = try await calendarProvider.fetchEvents()

for event in events {
    print(event.summary ?? "(untitled)", event.start.date ?? "unknown date")
}

var showBox = false

while !WindowShouldClose() && !KEY_Q.isPressed {
    BeginDrawing()
    ClearBackground(COLOR_BLACK)
    
    let text = "Calendar Clock"
    let fontSize: Int32 = 20
    let textWidth = MeasureText(text, fontSize)
    let x = (SCREEN_WIDTH / 2) - (textWidth / 2)
    let y = (CONTENT_HEIGHT / 2) - (fontSize / 2)

    DrawText(text, x, y, fontSize, COLOR_YELLOW)
    
    let buttonClicked = GuiButton(Rectangle(x: 5, y: 5, width: 160, height: 40), "Click Me!")
    
    if buttonClicked != 0 {
        print("Button was clicked!")
    }
    
    EndDrawing()
}

CloseWindow()
