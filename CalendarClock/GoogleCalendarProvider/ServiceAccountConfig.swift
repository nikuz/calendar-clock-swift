struct ServiceAccountConfig: Decodable {
    let type: String
    let projectId: String
    let privateKeyId: String
    let privateKey: String
    let clientEmail: String
    let clientId: String
    let authUri: String
    let tokenUri: String
    let authProviderX509CertUrl: String
    let clientX509CertUrl: String
    let universeDomain: String
}