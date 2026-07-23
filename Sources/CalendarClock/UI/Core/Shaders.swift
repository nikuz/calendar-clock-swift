import Foundation
import CRayLib

@MainActor enum UIShaderName: CaseIterable {
    case waveEffect
}

@MainActor private struct UIShadersList {
    private let shaders: [UIShaderName: Shader]

    init(shaderFor: (UIShaderName) -> Shader) {
        var result: [UIShaderName: Shader] = [:]
        for name in UIShaderName.allCases {
            result[name] = shaderFor(name)
        }
        self.shaders = result
    }

    subscript(name: UIShaderName) -> Shader {
        shaders[name]!
    }
}

@MainActor private var uiShaders = UIShadersList { name in
    switch name {
        case .waveEffect: Shader()
    }
}

@MainActor
class UIShaders {
    private let waveEffectPath: String

    init() {
        guard let waveEffectPath = Bundle.module.path(forResource: "wave-effect", ofType: "fs", inDirectory: "shaders")
        else {
            fatalError("Shader not found")
        }
        self.waveEffectPath = waveEffectPath
    }

    func load() {
        uiShaders = UIShadersList { name in
            switch name {
                case .waveEffect: return LoadShader(nil, waveEffectPath)
            }
        }
    }

    func unload() {
        for name in UIShaderName.allCases {
            UnloadShader(uiShaders[name])
        }
    }

    static func getShader(_ name: UIShaderName) -> Shader {
        return uiShaders[name]
    }
}