/// The screen turned into a lamp: a solid field of light the clock and the
/// events are cut out of, see `CalendarLampComponent`.
struct AppStateLamp: Sendable {
    static let brightnessMin = 1
    static let brightnessMax = 100

    var isActive = false
    /// Percent of the full intensity of the current color, 1...100.
    var brightness = brightnessMax
    /// Index into `LAMP_COLORS`, the dial always starts on the first one.
    var colorIndex = 0

    /// The brightness the lamp is lit at when it is turned on: the brightness
    /// the rest of the application is drawn with, so turning the lamp on in a
    /// dark room doesn't blind anyone.
    ///
    /// The global brightness is a factor in the -1...0 range, where 0 is the
    /// full intensity, see `AppStateBrightness`.
    static func brightness(for globalBrightnessFactor: Float) -> Int {
        // rounded: the factor is a float, and truncating it loses a whole step
        let percent = Int(((1 + globalBrightnessFactor) * 100).rounded())
        return min(max(percent, brightnessMin), brightnessMax)
    }
}
