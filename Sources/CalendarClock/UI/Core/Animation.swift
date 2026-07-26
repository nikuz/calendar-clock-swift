import Foundation

@MainActor
enum Animation {
    private static let c1: Float = 1.70158
    private static let c2: Float = c1 * 1.525
    private static let c3: Float = c1 + 1
    private static let c4: Float = (2 * Float.pi) / 3
    private static let c5: Float = (2 * Float.pi) / 4.5

    enum EasingFunction {
        case linear
        case easeInQuad,    easeOutQuad,    easeInOutQuad
        case easeInCubic,   easeOutCubic,   easeInOutCubic
        case easeInQuart,   easeOutQuart,   easeInOutQuart
        case easeInQuint,   easeOutQuint,   easeInOutQuint
        case easeInSine,    easeOutSine,    easeInOutSine
        case easeInExpo,    easeOutExpo,    easeInOutExpo
        case easeInCirc,    easeOutCirc,    easeInOutCirc
        case easeInBack,    easeOutBack,    easeInOutBack
        case easeInElastic, easeOutElastic, easeInOutElastic
        case easeInBounce,  easeOutBounce,  easeInOutBounce
    }

    private static func bounceOut(_ x: Float) -> Float {
        let n1: Float = 7.5625
        let d1: Float = 2.75
        var x = x

        if (x < 1 / d1) {
            return n1 * x * x
        } else if (x < 2 / d1) {
            x -= 1.5 / d1
            return n1 * x * x + 0.75
        } else if (x < 2.5 / d1) {
            x -= 2.25 / d1
            return n1 * x * x + 0.9375
        } else {
            x -= 2.625 / d1
            return n1 * x * x + 0.984375
        }
    }

    static func animateWith(value x: Float, _ easingFunction: EasingFunction) -> Float {
        switch easingFunction {
            case .linear: return x
            case .easeInQuad: 
                return x * x
            
            case .easeOutQuad: 
                return 1 - (1 - x) * (1 - x)
            
            case .easeInOutQuad: 
                return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
            
            case .easeInCubic: 
                return x * x * x
            
            case .easeOutCubic: 
                return 1 - pow(1 - x, 3)
            
            case .easeInOutCubic: 
                return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
            
            case .easeInQuart: 
                return x * x * x * x
            
            case .easeOutQuart: 
                return 1 - pow(1 - x, 4)
            
            case .easeInOutQuart: 
                return x < 0.5 ? 8 * x * x * x * x : 1 - pow(-2 * x + 2, 4) / 2
            
            case .easeInQuint: 
                return x * x * x * x * x
            
            case .easeOutQuint: 
                return 1 - pow(1 - x, 5)
            
            case .easeInOutQuint: 
                return x < 0.5 ? 16 * x * x * x * x * x : 1 - pow(-2 * x + 2, 5) / 2
            
            case .easeInSine: 
                return 1 - cos((x * Float.pi) / 2)
            
            case .easeOutSine: 
                return sin((x * Float.pi) / 2)
            
            case .easeInOutSine: 
                return -(cos(Float.pi * x) - 1) / 2
            
            case .easeInExpo: 
                return x == 0 ? 0 : pow(2, 10 * x - 10)
            
            case .easeOutExpo: 
                return x == 1 ? 1 : 1 - pow(2, -10 * x)
            
            case .easeInOutExpo: 
                return x == 0
                    ? 0
                    : x == 1
                    ? 1
                    : x < 0.5
                    ? pow(2, 20 * x - 10) / 2
                    : (2 - pow(2, -20 * x + 10)) / 2
            
            case .easeInCirc: 
                return 1 - sqrt(1 - pow(x, 2))
            
            case .easeOutCirc: 
                return sqrt(1 - pow(x - 1, 2))
            
            case .easeInOutCirc: 
                return x < 0.5
                    ? (1 - sqrt(1 - pow(2 * x, 2))) / 2
                    : (sqrt(1 - pow(-2 * x + 2, 2)) + 1) / 2
            
            case .easeInBack: 
                return c3 * x * x * x - c1 * x * x
            
            case .easeOutBack: 
                return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
            
            case .easeInOutBack: 
                return x < 0.5
                    ? (pow(2 * x, 2) * ((c2 + 1) * 2 * x - c2)) / 2
                    : (pow(2 * x - 2, 2) * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2
            
            case .easeInElastic: 
                return x == 0
                    ? 0
                    : x == 1
                    ? 1
                    : -pow(2, 10 * x - 10) * sin((x * 10 - 10.75) * c4)
            
            case .easeOutElastic: 
                return x == 0
                    ? 0
                    : x == 1
                    ? 1
                    : pow(2, -10 * x) * sin((x * 10 - 0.75) * c4) + 1
            
            case .easeInOutElastic: 
                return x == 0
                    ? 0
                    : x == 1
                    ? 1
                    : x < 0.5
                    ? -(pow(2, 20 * x - 10) * sin((20 * x - 11.125) * c5)) / 2
                    : (pow(2, -20 * x + 10) * sin((20 * x - 11.125) * c5)) / 2 + 1
            
            case .easeInBounce: 
                return 1 - bounceOut(1.0 - x)
            
            case .easeOutBounce: return bounceOut(x)
            case .easeInOutBounce: 
                return x < 0.5
                    ? (1 - bounceOut(1 - 2 * x)) / 2
                    : (1 + bounceOut(2 * x - 1)) / 2
            
        }
    }
}