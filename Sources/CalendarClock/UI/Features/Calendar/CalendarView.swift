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
                let activeEventProps = CalendarUIUtils.getActiveCalendarEvent(events: payload.events, time: time)
                if let activeEvent = activeEventProps.1, KEY_ESCAPE.isPressed {
                    appState.update { state in
                        state.calendar.updatePayload { payload in 
                            payload.confirmedApproachingEventId = activeEvent.id
                        }
                    }
                }
                CalendarTimeComponent.draw(
                    time: time, 
                    appState: _appState,
                    activeEventIndex: activeEventProps.0,
                )
                for (index, event) in payload.events.enumerated() {
                    CalendarEventCardComponent.draw(
                        event: event, 
                        index: index, 
                        time: time, 
                        appState: _appState
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