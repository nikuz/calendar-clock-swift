import Foundation
import CRayLib

@MainActor
enum CalendarActiveEventAlarm {
    private static let maxAlarmDuration = 60.0 // seconds
    private static var alarmStarted = false
    private static var alarmStartTime = 0.0
    private static var lastActiveEventIndex: Int?
    
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

        // prevent playing both the approaching and the alarm sounds simultaneously
        if IsSoundPlaying(eventApproachingSound) {
            if alarmStarted {
                resetAlarm()
            }
            return
        }

        let alarmDuration = GetTime() - alarmStartTime
        if let activeEvent = eventsOrder.activeEvent {
            if alarmStarted && lastActiveEventIndex != activeEvent.index {
                resetAlarm()
            }
            if (
                activeEvent.event.id != confirmedEvent 
                && alarmDuration < maxAlarmDuration 
                && !IsSoundPlaying(eventAlarmSound)
            ) {
                if !alarmStarted {
                    startAlarm(activeEvent.index)
                }
                PlaySound(eventAlarmSound)
            } else if (
                activeEvent.event.id == confirmedEvent 
                && IsSoundPlaying(eventAlarmSound)
            ) {
                StopSound(eventAlarmSound)
            }
        } else {
            if IsSoundPlaying(eventAlarmSound) {
                StopSound(eventAlarmSound)
            }
            if alarmStarted {
                resetAlarm()
            }
        }
    }

    private static func startAlarm(_ activeEventIndex: Int) {
        alarmStarted = true
        alarmStartTime = GetTime()
        lastActiveEventIndex = activeEventIndex
    }

    private static func resetAlarm() {
        alarmStarted = false
        alarmStartTime = GetTime()
        lastActiveEventIndex = nil
    }
}