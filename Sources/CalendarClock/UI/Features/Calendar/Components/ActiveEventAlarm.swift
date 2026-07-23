import Foundation
import CRayLib

@MainActor
struct ActiveEventAlarm {
    static func play(
        appState: AppStateData,
        eventsOrder: CalendarUIUtils.EventsOrder,
    ) {
        let eventApproachingSound = UISounds.getSound(.eventApproaching)
        let eventAlarmSound = UISounds.getSound(.eventAlarm)
        let confirmedEvent = appState.calendar.confirmedApproachingEventId

        if let approachingEvent = eventsOrder.approachingEvent {
            if approachingEvent.event.id != confirmedEvent && !IsSoundPlaying(eventApproachingSound) {
                PlaySound(eventApproachingSound)
            } else if approachingEvent.event.id == confirmedEvent && IsSoundPlaying(eventApproachingSound) {
                StopSound(eventApproachingSound)
            }
        } else if IsSoundPlaying(eventApproachingSound) {
            StopSound(eventApproachingSound)
        }

        if let activeEvent = eventsOrder.activeEvent {
            if activeEvent.event.id != confirmedEvent && !IsSoundPlaying(eventAlarmSound) {
                PlaySound(eventAlarmSound)
            } else if activeEvent.event.id == confirmedEvent && IsSoundPlaying(eventAlarmSound) {
                StopSound(eventAlarmSound)
            }
        } else if IsSoundPlaying(eventAlarmSound) {
            StopSound(eventAlarmSound)
        }
    }
}