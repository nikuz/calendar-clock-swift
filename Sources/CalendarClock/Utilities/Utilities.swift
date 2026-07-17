enum Utilities {
    static func remapValue<T: BinaryFloatingPoint>(
        value: T,
        inMin: T,
        inMax: T,
        outMin: T,
        outMax: T,
    ) -> T {
        if (value < inMin) {
            return outMin
        }
        if (value > inMax) {
            return outMax
        }

        return (
            ((value - inMin) * (outMax - outMin)) / (inMax - inMin)
        ) + outMin
    }
    static func remapValue<T: BinaryInteger>(
        value: T,
        inMin: T,
        inMax: T,
        outMin: T,
        outMax: T,
    ) -> T {
        if (value < inMin) {
            return outMin
        }
        if (value > inMax) {
            return outMax
        }

        return (
            ((value - inMin) * (outMax - outMin)) / (inMax - inMin)
        ) + outMin
    }
}