import Foundation
import CRayLib

@MainActor enum UISoundName: String, CaseIterable {
    case eventAlarm = "event-alarm"
    case eventApproaching = "event-approaching-alarm"
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

@MainActor private var uiSounds = UISoundsList { _ in Sound() }

@MainActor
class UISounds {
    private func getSoundPath(for soundName: UISoundName) -> String {
        guard
            let path = Bundle.module.path(
                forResource: soundName.rawValue,
                ofType: "wav",
                inDirectory: "sounds"
            )
        else {
            fatalError("Missing sound '\(soundName.rawValue)'")
        }

        return path
    }

    func load() {
        uiSounds = UISoundsList { name in
            LoadSound(getSoundPath(for: name))
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