let SCREEN_WIDTH: Float = 1024 // px
#if os(macOS)
    let SCREEN_HEIGHT: Float = 128 // px
#else
    let SCREEN_HEIGHT: Float = 768 // px
#endif
let CONTENT_HEIGHT: Float = 128 // px

let UI_FPS: Int32 = 10

let DAY_START_TIME: Float = 6 * 60 + 30 // minutes
let DAY_END_TIME: Float = 21 * 60 // minutes

let EVENTS_ZOOM = 1.35 // times

let MORNING_HOUR = 7
let EVENING_HOUR = 20