struct AppStateBrightness: Sendable {
    let rawValue: Double
    let factor: Float

    private let BRIGHTNESS_MIN: Float = 0.0
    private let BRIGHTNESS_MAX: Float = 40.0

    init(_ rawValue: Double) {
        self.rawValue = rawValue
        let factor = Utilities.remapValue(
            value: Float(rawValue),
            inMin: BRIGHTNESS_MIN,
            inMax: BRIGHTNESS_MAX,
            outMin: -1,
            outMax: 0
        )
        self.factor = max(factor, -0.95)
    }
}