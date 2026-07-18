import Foundation
import CRayLib

@MainActor
struct CalendarView {
    static func draw(appState: AppState) {
        let _appState = appState.current
        let time = CalendarUIUtils.getTime()

        CalendarTimeComponent.draw(time: time, appState: _appState)

        switch appState.current.calendar {
            case .loading:
                CalendarLoadingComponent.draw()

            case .loaded(let events):
                for (_, event) in events.enumerated() {
                    CalendarEventCardComponent.draw(
                        event: event, 
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
        }
    }
}