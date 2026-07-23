import Foundation
import CRayLib

@MainActor enum UISoundName: CaseIterable {
    case eventAlarm, eventApproaching
}

@MainActor private struct UISoundsList {
    private let sounds: [UISoundName: Sound]

    init(soundFor: (UISoundName) -> Sound) {
        var result: [UISoundName: Sound] = [:]
        for name in UISoundName.allCases {
            result[name] = soundFor(name)
        }
        self.sounds = result
    }

    subscript(name: UISoundName) -> Sound {
        sounds[name]!
    }
}

@MainActor private var uiSounds = UISoundsList { name in
    switch name {
        case .eventAlarm: LoadSound("")
        case .eventApproaching: LoadSound("")
    }
}

@MainActor
class UISounds {
    private let eventAlarmPath: String
    private let eventApproachingPath: String

    init() {
        guard let eventAlarmPath = Bundle.module.path(forResource: "event-alarm", ofType: "wav", inDirectory: "sounds"),
            let eventApproachingPath = Bundle.module.path(forResource: "event-approaching-alarm", ofType: "wav", inDirectory: "sounds")
        else {
            fatalError("Sound not found")
        }
        self.eventAlarmPath = eventAlarmPath
        self.eventApproachingPath = eventApproachingPath
    }

    func load() {
        uiSounds = UISoundsList { name in
            switch name {
                case .eventAlarm: LoadSound(eventAlarmPath)
                case .eventApproaching: LoadSound(eventApproachingPath)
            }
        }
    }

    func unload() {
        for name in UISoundName.allCases {
            UnloadSound(uiSounds[name])
        }
    }

    static func getSound(_ name: UISoundName) -> Sound {
        return uiSounds[name]
    }
}