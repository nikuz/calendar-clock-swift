import Foundation
import CRayLib

@MainActor
enum CalendarView {
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
                if eventsOrder.prevEvent != nil && KEY_LEFT.isPressed {
                    eventsNavigation = CalendarUIUtils.getEventsNavigation(time, eventsOrder.prevEvent)
                }
                if eventsOrder.nextEvent != nil && KEY_RIGHT.isPressed {
                    eventsNavigation = CalendarUIUtils.getEventsNavigation(time, eventsOrder.nextEvent)
                }

                CalendarBackground.draw(time: time, appState: _appState)
                ActiveEventAlarmEffect.draw(time: time, appState: _appState, eventsOrder: eventsOrder)
                CalendarTimeComponent.draw(
                    time: time, 
                    appState: _appState,
                    eventsOrder: eventsOrder,
                )
                ActiveEventAlarm.play(appState: _appState, eventsOrder: eventsOrder)

                var outsideIndex: Int32 = 0
                for (index, event) in payload.positionedEvents.enumerated() {
                    CalendarEventCardComponent.draw(
                        positionedEvent: event, 
                        index: index, 
                        time: time, 
                        appState: _appState,
                        eventsOrder: eventsOrder,
                        outsideIndex: outsideIndex,
                    ) {
                        outsideIndex += 1
                    }
                }

            case .failed(let error):
                CalendarErrorComponent.draw(
                    error: error, 
                    time: time, 
                    appState: _appState
                )
                CalendarTimeComponent.draw(time: time, appState: _appState)
        }
    }

}