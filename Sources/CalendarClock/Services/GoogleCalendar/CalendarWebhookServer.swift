import Foundation
import FlyingFox

actor CalendarWebhookServer {
    private let server: HTTPServer
    private let port: UInt16
    private let ngrokCredentials: NgrokCredentials
    private let onChannelIdReceived: @Sendable (String) async throws -> Void
    private var serverTask: Task<Void, Error>?

    init(
        port: UInt16,
        ngrokCredentials: NgrokCredentials,
        onChannelIdReceived: @escaping @Sendable (String) async throws -> Void
    ) {
        self.port = port
        self.ngrokCredentials = ngrokCredentials
        self.onChannelIdReceived = onChannelIdReceived
        self.server = HTTPServer(port: port)
    }

    func start() async throws {
        await server.appendRoute("POST *") { [ngrokCredentials, onMatch = onChannelIdReceived] request in
            guard let channelId = request.headers[.init("x-goog-channel-id")],
                let authToken = request.headers[.init("x-goog-channel-token")],
                authToken.hasPrefix("Basic ")
            else {
                return HTTPResponse(statusCode: .ok)
            }

            let base64Part = authToken.dropFirst("Basic ".count)
            guard let decoded = Data(base64Encoded: String(base64Part)),
                let credentials = String(data: decoded, encoding: .utf8),
                let colonIndex = credentials.firstIndex(of: ":")
            else {
                return HTTPResponse(statusCode: .ok)
            }

            let user = String(credentials[..<colonIndex])
            let password = String(credentials[credentials.index(after: colonIndex)...])

            if user == ngrokCredentials.user && password == ngrokCredentials.password {
                Task {
                    do {
                        try await onMatch(channelId)
                    } catch {
                        print("Webhook processing failed: \(error)")
                    }
                }
            }
            return HTTPResponse(statusCode: .ok)
        }

        serverTask = Task {
            try await server.run()
        }

        try await server.waitUntilListening()
        print("Server running on port \(self.port) (background Task).")
    }

    func stop() async {
        await server.stop()
        serverTask?.cancel()
    }
}