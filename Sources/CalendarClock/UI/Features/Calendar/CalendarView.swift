import Foundation
import CRayLib

@MainActor
struct CalendarView {
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
                ActiveEventAlarmEffect.draw(time: time, appState: _appState, eventsOrder: eventsOrder)
                CalendarTimeComponent.draw(
                    time: time, 
                    appState: _appState,
                    eventsOrder: eventsOrder,
                )
                for (index, event) in payload.positionedEvents.enumerated() {
                    CalendarEventCardComponent.draw(
                        positionedEvent: event, 
                        index: index, 
                        time: time, 
                        appState: _appState,
                        eventsOrder: eventsOrder
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
    }
}