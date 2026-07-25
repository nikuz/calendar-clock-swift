import Foundation

#if canImport(Security)
    import Security
#elseif os(Linux)
    import COpenSSL
#endif

enum PEMError: Error {
    case invalidFormat
    case openSSLError(String)
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

    #if canImport(Security)
        // Helper used only on macOS/iOS to manually unwrap PKCS#8 keys
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
    #endif

    static func signRS256(_ input: String, privateKeyPEM: String) throws -> Data {
        #if canImport(Security)
            // ==========================================
            // macOS / iOS Implementation (Security.framework)
            // ==========================================
            let der = try pemToDER(privateKeyPEM)
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                kSecAttrKeySizeInBits as String: 2048,
            ]
            
            var error: Unmanaged<CFError>?
            guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, &error) else {
                throw error!.takeRetainedValue()
            }
            
            let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
            guard SecKeyIsAlgorithmSupported(key, .sign, algorithm) else {
                // Fallback in case error is somehow nil here, though Unmanaged usually guarantees it if the call fails
                throw PEMError.invalidFormat 
            }
            
            guard let signature = SecKeyCreateSignature(
                    key,
                    algorithm,
                    input.data(using: .utf8)! as CFData,
                    &error
                )
            else {
                throw error!.takeRetainedValue()
            }
            return signature as Data
        
        #elseif os(Linux)
            // ==========================================
            // Linux Implementation (OpenSSL)
            // ==========================================
            var pemCopy = privateKeyPEM
            let bio = pemCopy.withUTF8 { buffer in
                BIO_new_mem_buf(buffer.baseAddress, Int32(buffer.count))
            }
            guard let bio = bio else { throw PEMError.openSSLError("Failed to allocate memory buffer") }
            defer { BIO_free(bio) }

            // OpenSSL natively handles PKCS#1 and PKCS#8 keys
            let pkey = PEM_read_bio_PrivateKey(bio, nil, nil, nil)
            guard let pkey = pkey else { throw PEMError.invalidFormat }
            defer { EVP_PKEY_free(pkey) }

            let ctx = EVP_MD_CTX_new()
            guard let ctx = ctx else { throw PEMError.openSSLError("Failed to create digest context") }
            defer { EVP_MD_CTX_free(ctx) }

            if EVP_DigestSignInit(ctx, nil, EVP_sha256(), nil, pkey) != 1 {
                throw PEMError.openSSLError("Failed to initialize signing")
            }

            let inputData = Data(input.utf8)
            let updateSuccess = inputData.withUnsafeBytes { buffer -> Int32 in
                EVP_DigestSignUpdate(ctx, buffer.baseAddress, buffer.count)
            }
            guard updateSuccess == 1 else { throw PEMError.openSSLError("Failed to update digest") }

            var sigLen: Int = 0
            if EVP_DigestSignFinal(ctx, nil, &sigLen) != 1 {
                throw PEMError.openSSLError("Failed to calculate signature length")
            }

            var signature = Data(count: sigLen)
            let finalSuccess = signature.withUnsafeMutableBytes { buffer -> Int32 in
                EVP_DigestSignFinal(ctx, buffer.bindMemory(to: UInt8.self).baseAddress, &sigLen)
            }
            guard finalSuccess == 1 else { throw PEMError.openSSLError("Failed to finalize signature") }

            return signature.prefix(upTo: sigLen)

        #else
            fatalError("Unsupported platform")
        #endif
    }
}