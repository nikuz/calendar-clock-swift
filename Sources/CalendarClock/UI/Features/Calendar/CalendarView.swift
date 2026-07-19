import Foundation
import CRayLib

@MainActor
struct CalendarView {
    static func draw(appState: AppState) {
        let _appState = appState.current
        let time = CalendarUIUtils.getTime()

        switch _appState.calendar {
            case .loading:
                CalendarLoadingComponent.draw()
                CalendarTimeComponent.draw(time: time, appState: _appState)

            case .loaded(let events):
                CalendarTimeComponent.draw(time: time, appState: _appState)
                for (index, event) in events.enumerated() {
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