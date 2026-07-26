import Foundation
import CRayLib

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
                if let flashingEvent = activeEvent ?? approachingEvent, KEY_ESCAPE.isPressed {
                    appState.update { state in
                        state.calendar.updatePayload { payload in
                            payload.confirmedApproachingEventId = flashingEvent.event.id
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
                
                for (index, event) in payload.positionedEvents.enumerated() {
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