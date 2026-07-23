import Foundation
import CRayLib

@MainActor
enum UIShaderName: String, CaseIterable {
    case waveEffect = "wave-effect"
}

@MainActor
private struct UIShadersList {
    private let shaders: [UIShaderName: Shader]

    init(shaderFor: (UIShaderName) -> Shader) {
        var shaders: [UIShaderName: Shader] = [:]

        for shader in UIShaderName.allCases {
            shaders[shader] = shaderFor(shader)
        }

        self.shaders = shaders
    }

    subscript(name: UIShaderName) -> Shader {
        shaders[name]!
    }
}

@MainActor
private var uiShaders = UIShadersList { _ in
    Shader()
}

@MainActor
final class UIShaders {
    private let shaderDirectory: String

    init() {
        #if os(Linux)
            shaderDirectory = "shaders/glsl100"
        #else
            shaderDirectory = "shaders/glsl330"
        #endif
    }

    private func fragmentShaderPath(for shader: UIShaderName) -> String {
        guard
            let path = Bundle.module.path(
                forResource: shader.rawValue,
                ofType: "fs",
                inDirectory: shaderDirectory
            )
        else {
            fatalError("Missing shader '\(shader.rawValue)' in \(shaderDirectory)")
        }

        return path
    }

    func load() {
        uiShaders = UIShadersList { shader in
            LoadShader(nil, fragmentShaderPath(for: shader))
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