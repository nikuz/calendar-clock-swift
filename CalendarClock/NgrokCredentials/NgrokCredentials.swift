import Foundation

private let ngrokCredentialsFilePath = "config/ngrok-credentials.json"

private enum NgrokCredentialsError: Error {
    case ngrokCredentialsFileNotFound
}

struct NgrokCredentials: Codable {
    let domainURL: String
    let user: String
    let password: String

    init() async throws {
        let ngrokCredentialsData = URL(fileURLWithPath: ngrokCredentialsFilePath)
        guard FileManager.default.fileExists(atPath: ngrokCredentialsData.path) else {
            throw NgrokCredentialsError.ngrokCredentialsFileNotFound
        }
        let ngrokCredentialsJson = try Data(contentsOf: ngrokCredentialsData)
        let ngrokCredentials = try JSONDecoder().decode(NgrokCredentials.self, from: ngrokCredentialsJson)
        
        domainURL = ngrokCredentials.domainURL
        user = ngrokCredentials.user
        password = ngrokCredentials.password
    }
}