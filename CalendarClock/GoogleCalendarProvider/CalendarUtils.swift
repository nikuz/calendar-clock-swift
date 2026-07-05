import Foundation
import Security

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

    static func pemToDER(_ pem: String) throws -> Data {
        let keyString =
            pem
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") }
            .joined()

        guard var keyData = Data(base64Encoded: keyString, options: .ignoreUnknownCharacters) else {
            throw PEMError.invalidFormat
        }

        let pkcs8HeaderLength = 26
        if keyData.count > pkcs8HeaderLength && keyData[0] == 0x30 {
            // Check if it's likely a PKCS#8 header (0x30 is the ASN.1 sequence tag)
            // By dropping the first 26 bytes, we hand Apple the raw PKCS#1 data it expects.
            keyData = keyData.subdata(in: pkcs8HeaderLength..<keyData.count)
        }

        return keyData
    }

    static func signRS256(_ input: String, privateKeyPEM: String) throws -> Data {
        let der = try pemToDER(privateKeyPEM)  // strip header/footer, base64-decode
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048,
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, &error)
        else {
            throw error!.takeRetainedValue()
        }
        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
        guard SecKeyIsAlgorithmSupported(key, .sign, algorithm) else {
            throw error!.takeRetainedValue()
        }
        guard
            let signature = SecKeyCreateSignature(
                key,
                algorithm,
                input.data(using: .utf8)! as CFData,
                &error
            )
        else {
            throw error!.takeRetainedValue()
        }
        return signature as Data
    }
}