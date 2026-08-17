import Foundation
import CRayLib

@MainActor
enum CalendarView {
    // static private let animationDuration = 1.0 // seconds
    // static private var animationStartTime = GetTime()
    // static private var animationDirection: Float = 1
    static private var eventsCards: [CalendarEventCardComponent?] = []
    static private var eventsCardsLoadTime: Double = 0
    static private var eventsNavigation: CalendarUIUtils.EventsNavigation?
    static private var selectedEventIndex: Int?

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

                self.handleKeyboardShortcuts(
                    appState: appState,
                    events: payload.events,
                    eventsOrder: eventsOrder,
                    time: time,
                )

                CalendarBackground.draw(time: time, appState: _appState)
                CalendarActiveEventAlarmEffect.draw(
                    time: time,
                    appState: _appState,
                    eventsOrder: eventsOrder,
                    eventsNavigation: eventsNavigation,
                )
                // draw time line behind the active event
                if eventsOrder.activeEvent != nil {
                    CalendarTimeComponent.draw(
                        time: time,
                        appState: _appState,
                        eventsOrder: eventsOrder,
                        eventsNavigation: eventsNavigation,
                    )
                }
                CalendarActiveEventAlarm.play(appState: _appState, eventsOrder: eventsOrder)

                // events cards are created only when the list of events changes,
                // after that only their dynamic properties are updated
                if eventsCardsLoadTime != payload.loadTime {
                    eventsCardsLoadTime = payload.loadTime
                    eventsCards = payload.positionedEvents.enumerated().map { index, event in
                        CalendarEventCardComponent(
                            positionedEvent: event,
                            index: index,
                            startOfDay: time.startOfDay,
                        )
                    }
                }

                let eventsCardsContext = CalendarEventCardComponent.Context(
                    time: time,
                    appState: _appState,
                    eventsOrder: eventsOrder,
                    eventsNavigation: eventsNavigation,
                    selectedEventIndex: selectedEventIndex,
                )
                let highlightedEventIndex = eventsNavigation?.eventIndex
                var outsideLeftEdgeIndex: Int = 0
                var outsideRightEdgeIndex: Int = 0

                for index in eventsCards.indices {
                    eventsCards[index]?.update(
                        context: eventsCardsContext,
                        leftEdgeCounter: &outsideLeftEdgeIndex,
                        rightEdgeCounter: &outsideRightEdgeIndex,
                    )
                    // the highlighted event is drawn on top of the time line
                    if index != highlightedEventIndex {
                        eventsCards[index]?.draw()
                    }
                }

                // draw time above event border if time is outside active event boundaries
                if eventsOrder.activeEvent == nil {
                    CalendarTimeComponent.draw(
                        time: time,
                        appState: _appState,
                        eventsOrder: eventsOrder,
                        eventsNavigation: eventsNavigation,
                    )
                }

                // selected or highlighted event
                if let highlightedEventIndex, eventsCards.indices.contains(highlightedEventIndex) {
                    eventsCards[highlightedEventIndex]?.draw()
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

    static func handleKeyboardShortcuts(
        appState: AppState,
        events: [CalendarEvent],
        eventsOrder: CalendarUIUtils.EventsOrder,
        time: CalendarUIUtils.TimeInfo,
    ) {
        if KEY_ESCAPE.isPressed {
            if eventsNavigation != nil {
                eventsNavigation = nil
                selectedEventIndex = nil
            } else if let flashingEvent = eventsOrder.activeEvent ?? eventsOrder.approachingEvent {
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
                events: events,
                eventsOrder: eventsOrder,
                eventsNavigation: eventsNavigation,
                direction: KEY_LEFT.isPressed ? .left : .right,
            )
            if eventsNavigation?.eventIndex != selectedEventIndex {
                selectedEventIndex = nil
            }
        }
        if let eventsNavigation, KEY_ENTER.isPressed {
            selectedEventIndex = eventsNavigation.eventIndex
        }
    }
}