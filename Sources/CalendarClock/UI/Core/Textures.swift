import Foundation
import CRayLib

@MainActor enum UITextureName: String, CaseIterable {
    case mountainsNight = "mountains-night"
}

@MainActor private struct UITexturesList {
    private let textures: [UITextureName: Texture2D]

    init(textureFor: (UITextureName) -> Texture2D) {
        var result: [UITextureName: Texture2D] = [:]
        for name in UITextureName.allCases {
            result[name] = textureFor(name)
        }
        self.textures = result
    }

    subscript(name: UITextureName) -> Texture2D {
        textures[name]!
    }
}

@MainActor private var uiTextures = UITexturesList { _ in Texture2D() }

@MainActor
class UITextures {
    private func getTexturePath(for textureName: UITextureName) -> String {
        guard
            let path = Bundle.module.path(
                forResource: textureName.rawValue,
                ofType: "png",
                inDirectory: "textures"
            )
        else {
            fatalError("Missing texture '\(textureName.rawValue)'")
        }

        return path
    }

    func load() {
        uiTextures = UITexturesList { name in
            LoadTexture(getTexturePath(for: name))
        }
    }

    func unload() {
        for name in UITextureName.allCases {
            UnloadTexture(uiTextures[name])
        }
    }

    static func getTexture(_ name: UITextureName) -> Texture2D {
        return uiTextures[name]
    }
}