import Foundation
import CRayLib

@MainActor private let shader = UIShaders.getShader(.scanlines)
@MainActor private let backgroundTexture = LoadRenderTexture(Int32(SCREEN_WIDTH), Int32(CONTENT_HEIGHT))
@MainActor private let blurTexture = LoadRenderTexture(Int32(SCREEN_WIDTH), Int32(CONTENT_HEIGHT))
@MainActor private var horizontal = Vector2(x: 1.0, y: 0.0)
@MainActor private var vertical = Vector2(x: 0.0, y: 1.0)
@MainActor private var disableGrayscale: Int32 = 0
@MainActor private var enableGrayscale: Int32 = 1

@MainActor
enum CalendarView {
    // static private let animationDuration = 1.0 // seconds
    // static private var animationStartTime = GetTime()
    // static private var animationDirection: Float = 1
    static private var eventsNavigation: CalendarUIUtils.EventsNavigation?

    static func draw(appState: AppState) {
        let _appState = appState.current
        let time = CalendarUIUtils.getTime()
        let isNightTime = CalendarUIUtils.isNightTime(time)

        if isNightTime {
            CalendarTimeComponent.draw(time: time, appState: _appState)
            return
        }

        switch _appState.calendar {
            case .loading:
                CalendarLoadingComponent.draw()
                CalendarTimeComponent.draw(time: time, appState: _appState)

            case .loaded(let payload):
                let eventsOrder = CalendarUIUtils.getEventsOrder(events: payload.events, time: time)
                let activeEvent = eventsOrder.activeEvent
                let approachingEvent = eventsOrder.approachingEvent

                if KEY_ESCAPE.isPressed {
                    if eventsNavigation != nil {
                        eventsNavigation = nil
                    } else if let flashingEvent = activeEvent ?? approachingEvent {
                        appState.update { state in
                            state.calendar.updatePayload { payload in
                                payload.confirmedApproachingEventId = flashingEvent.event.id
                            }
                        }
                    }
                }
                if KEY_B.isPressed {
                    appState.update { state in
                        state.backgroundVisible = !state.backgroundVisible
                    }
                }
                if KEY_LEFT.isPressed || KEY_RIGHT.isPressed {
                    eventsNavigation = CalendarUIUtils.getEventsNavigation(
                        time: time, 
                        events: payload.events,
                        eventsOrder: eventsOrder,
                        eventsNavigation: eventsNavigation,
                        direction: KEY_LEFT.isPressed ? .left : .right,
                    )
                }

                CalendarBackground.draw(time: time, appState: _appState)
                CalendarActiveEventAlarmEffect.draw(
                    time: time, 
                    appState: _appState, 
                    eventsOrder: eventsOrder,
                    eventsNavigation: eventsNavigation,
                )
                CalendarTimeComponent.draw(
                    time: time, 
                    appState: _appState,
                    eventsOrder: eventsOrder,
                    eventsNavigation: eventsNavigation,
                )
                CalendarActiveEventAlarm.play(appState: _appState, eventsOrder: eventsOrder)

                var outsideLeftEdgeIndex = 0
                var outsideRightEdgeIndex = 0
                
                if eventsNavigation != nil {
                    BeginTextureMode(backgroundTexture)
                    ClearBackground(.blank) 
                }
                for (index, event) in payload.positionedEvents.enumerated() {
                    if let eventsNavigation, eventsNavigation.eventIndex == index {
                        continue
                    }
                    CalendarEventCardComponent.draw(
                        positionedEvent: event, 
                        index: index, 
                        time: time, 
                        appState: _appState,
                        eventsOrder: eventsOrder,
                        eventsNavigation: eventsNavigation,
                        outsideLeftEdgeIndex: &outsideLeftEdgeIndex,
                        outsideRightEdgeIndex: &outsideRightEdgeIndex,
                    )
                }
                if eventsNavigation != nil {
                    EndTextureMode();
                    BeginShaderMode(shader)
                        let sourceRec = Rectangle(
                            x: 0,
                            y: 0,
                            width: Float(backgroundTexture.texture.width),
                            height: -Float(backgroundTexture.texture.height)
                        )
                        let position = Vector2(x: 0, y: 0)
                        DrawTextureRec(backgroundTexture.texture, sourceRec, position, .white)
                    EndShaderMode()
                }

                // selected event
                if let eventsNavigation {
                    CalendarEventCardComponent.draw(
                        positionedEvent: payload.positionedEvents[eventsNavigation.eventIndex],
                        index: eventsNavigation.eventIndex,
                        time: time,
                        appState: _appState,
                        eventsOrder: eventsOrder,
                        eventsNavigation: eventsNavigation,
                        outsideLeftEdgeIndex: &outsideLeftEdgeIndex,
                        outsideRightEdgeIndex: &outsideRightEdgeIndex,
                        isSelected: true,
                    )
                }

            case .failed(let error):
                CalendarErrorComponent.draw(
                    error: error, 
                    time: time, 
                    appState: _appState
                )
                CalendarTimeComponent.draw(time: time, appState: _appState)
        }

        // let elapsedTime = (GetTime() - animationStartTime) / animationDuration
        // let animationProgress = Animation.animateWith(value: Float(elapsedTime), .easeInCubic) * 100
        // let cubeSize: Float = 20.0;
        // var x: Float = 0
        // x = (SCREEN_WIDTH - cubeSize) / 100 * animationProgress
        // if animationDirection == -1 {
        //     x = SCREEN_WIDTH - cubeSize - x
        // }
        // DrawRectangleV(Vector2(x: x, y: 0), Vector2(x: cubeSize, y: 20), .red)

        // if elapsedTime >= 1.0 {
        //     animationStartTime = GetTime()
        //     animationDirection = animationDirection * -1
        // }
    }

}