import Foundation
import CRayLib

@MainActor enum UIFontName: CaseIterable {
    case unscii16, unscii8, silkscreen3x7
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
        case .unscii16: GetFontDefault()
        case .unscii8: GetFontDefault()
        case .silkscreen3x7: GetFontDefault()
    }
}

@MainActor
class UIFonts {
    private let unscii16FontPath: String
    private let unscii8FontPath: String
    private let silkscreen3x7FontPath: String

    init() {
        guard let unscii16FontPath = Bundle.module.path(forResource: "unscii-16", ofType: "ttf", inDirectory: "fonts"),
            let unscii8FontPath = Bundle.module.path(forResource: "unscii-8", ofType: "ttf", inDirectory: "fonts"),
            let silkscreen3x7FontPath = Bundle.module.path(forResource: "silkscreen-3x7", ofType: "ttf", inDirectory: "fonts")
        else {
            fatalError("Font not found")
        }
        self.unscii16FontPath = unscii16FontPath
        self.unscii8FontPath = unscii8FontPath
        self.silkscreen3x7FontPath = silkscreen3x7FontPath
    }

    func load() {
        uiFonts = UIFontsList { name in
            switch name {
                case .unscii16: LoadFontEx(unscii16FontPath, 16, nil, 250)
                case .unscii8: LoadFontEx(unscii8FontPath, 8, nil, 250)
                case .silkscreen3x7: LoadFontEx(silkscreen3x7FontPath, 9, nil, 250)
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