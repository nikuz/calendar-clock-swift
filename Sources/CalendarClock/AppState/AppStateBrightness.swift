struct AppStateBrightness: Sendable {
    let rawValue: Double
    let nightFactor: Float
    let dayFactor: Float

    private let BRIGHTNESS_MIN: Float = 0.0
    private let BRIGHTNESS_MAX: Float = 30.0

    init(_ rawValue: Double) {
        self.rawValue = rawValue
        let factor = Utilities.remapValue(
            value: Float(rawValue),
            inMin: BRIGHTNESS_MIN,
            inMax: BRIGHTNESS_MAX,
            outMin: -1,
            outMax: 0
        )
        self.dayFactor = min(max(factor, -0.70), -0.3)
        self.nightFactor = min(max(factor, -0.85), -0.5)
    }
}