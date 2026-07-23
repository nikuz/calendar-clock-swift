import Foundation
import CRayLib

struct UIFontParams {
    let name: String
    let format: String
    let size: Float
}

enum UIFont: CaseIterable {
    case unscii16, unscii8, silkscreen3x7

    var params: UIFontParams {
        switch self {
        case .unscii16:
            UIFontParams(name: "unscii-16", format: "ttf", size: 16)
        case .unscii8:
            UIFontParams(name: "unscii-8", format: "ttf", size: 8)
        case .silkscreen3x7:
            UIFontParams(name: "silkscreen-3x7", format: "ttf", size: 9)
        }
    }
}

private struct UIFontsList {
    private let fonts: [UIFont: Font]

    init(fontFor: (UIFont) -> Font) {
        var result: [UIFont: Font] = [:]
        for name in UIFont.allCases {
            result[name] = fontFor(name)
        }
        self.fonts = result
    }

    subscript(name: UIFont) -> Font {
        fonts[name]!
    }
}

@MainActor private var uiFonts = UIFontsList { _ in GetFontDefault() }

@MainActor
class UIFonts {
    private func getFontPath(for font: UIFont) -> String {
        guard
            let path = Bundle.module.path(
                forResource: font.params.name,
                ofType: font.params.format,
                inDirectory: "fonts"
            )
        else {
            fatalError("Missing font '\(font.params.name)'")
        }

        return path
    }

    func load() {
        uiFonts = UIFontsList { fontItem in
            LoadFontEx(getFontPath(for: fontItem), Int32(fontItem.params.size), nil, 250)
        }
    }

    func unload() {
        for name in UIFont.allCases {
            UnloadFont(uiFonts[name])
        }
    }

    static func getFont(_ name: UIFont) -> Font {
        return uiFonts[name]
    }
}