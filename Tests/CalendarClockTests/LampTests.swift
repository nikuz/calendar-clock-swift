import Testing
@testable import CalendarClock

struct LampTests {
    @Test func lampStartsOffAndOnTheFirstColorOfTheDial() {
        let state = AppState()

        let lamp = state.current.lamp

        #expect(lamp.isActive == false)
        #expect(lamp.colorIndex == 0)
    }

    /// The light the lamp always comes on with: 2700K, see `LAMP_COLORS`.
    @Test func theFirstColorOfTheDialIsWarmWhite() {
        let warmWhite = LAMP_COLORS[0]

        #expect(warmWhite.r == 255)
        #expect(warmWhite.g == 169)
        #expect(warmWhite.b == 87)
    }

    @Test func brightnessFollowsTheGlobalBrightnessOfTheApplication() {
        // the global brightness is a factor in the -1...0 range, where 0 is
        // the full intensity
        #expect(AppStateLamp.brightness(for: -0.3) == 70)
        #expect(AppStateLamp.brightness(for: -0.85) == 15)
    }

    /// A pitch dark room would otherwise turn the lamp on at nothing at all.
    @Test func brightnessNeverFallsBelowTheLowestStepOfTheDial() {
        #expect(AppStateLamp.brightness(for: -1) == AppStateLamp.brightnessMin)
    }

    /// The last few percent glitch the panel of the Raspberry Pi, nothing is
    /// allowed to reach them: not the dial, and not a bright room either.
    @Test func brightnessNeverReachesTheFullIntensityOfTheColor() {
        #expect(AppStateLamp.brightnessMax == 95)
        #expect(AppStateLamp.brightness(for: 0) == AppStateLamp.brightnessMax)
        #expect(AppStateLamp().brightness <= AppStateLamp.brightnessMax)
    }

    @Test func intensityIsTheBrightnessAsAShareOfTheFullColor() {
        var lamp = AppStateLamp()

        lamp.brightness = 95
        #expect(lamp.intensity == 0.95)

        lamp.brightness = 1
        #expect(lamp.intensity == 0.01)
    }
}
