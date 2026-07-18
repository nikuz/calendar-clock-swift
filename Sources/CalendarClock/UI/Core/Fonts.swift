import Foundation
import CRayLib

@MainActor enum UIFontName: CaseIterable {
    case unscii16, unscii8, tiny5
}

@MainActor private struct UIFontsList {
    private let fonts: [UIFontName: Font]

    init(fontFor: (UIFontName) -> Font) {
        var result: [UIFontName: Font] = [:]
        for name in UIFontName.allCases {
            result[name] = fontFor(name)
        }
        self.fonts = result
    }

    subscript(name: UIFontName) -> Font {
        fonts[name]!
    }
}

@MainActor private var uiFonts = UIFontsList { name in
    switch name {
        case .unscii16: return GetFontDefault()
        case .unscii8: return GetFontDefault()
        case .tiny5: return GetFontDefault()
    }
}

@MainActor
class UIFonts {
    private let unscii16FontPath: String
    private let unscii8FontPath: String
    private let tiny5FontPath: String

    init() {
        guard let unscii16FontPath = Bundle.module.path(forResource: "unscii-16", ofType: "ttf", inDirectory: "fonts"),
            let unscii8FontPath = Bundle.module.path(forResource: "unscii-8", ofType: "ttf", inDirectory: "fonts"),
            let tiny5FontPath = Bundle.module.path(forResource: "Tiny5", ofType: "ttf", inDirectory: "fonts")
        else {
            fatalError("Font not found")
        }
        self.unscii16FontPath = unscii16FontPath
        self.unscii8FontPath = unscii8FontPath
        self.tiny5FontPath = tiny5FontPath
    }

    func load() {
        uiFonts = UIFontsList { name in
            switch name {
                case .unscii16: return LoadFont(unscii16FontPath)
                case .unscii8: return LoadFont(unscii8FontPath)
                case .tiny5: return LoadFont(tiny5FontPath)
            }
        }
    }

    func unload() {
        for name in UIFontName.allCases {
            UnloadFont(uiFonts[name])
        }
    }

    static func getFont(_ name: UIFontName) -> Font {
        return uiFonts[name]
    }
}