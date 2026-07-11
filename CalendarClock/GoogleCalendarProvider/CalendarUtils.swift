import Foundation
import CryptoExtras

enum PEMError: Error {
    case invalidFormat
}

class CalendarUtils {
    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return base64URLEncode(data)
    }

    static func signRS256(_ input: String, privateKeyPEM: String) throws -> Data {
        let privateKey = try _RSA.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        let signature = try privateKey.signature(
            for: Data(input.utf8),
            padding: .insecurePKCS1v1_5  // this is RS256's PKCS#1 v1.5 padding, despite the scary name
        )
        return Data(signature.rawRepresentation)
    }
}