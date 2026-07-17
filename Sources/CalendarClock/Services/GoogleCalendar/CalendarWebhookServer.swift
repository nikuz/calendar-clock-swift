import Foundation
import NIO
import NIOHTTP1

final class CalendarWebhookServer {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private var channel: Channel?
    private let port: Int
    private let ngrokCredentials: NgrokCredentials
    private let onChannelIdReceived: @Sendable (String) async throws -> Void

    init(
        port: Int, 
        ngrokCredentials: NgrokCredentials, 
        onChannelIdReceived: @escaping @Sendable (String) async throws -> Void
    ) {
        self.port = port
        self.ngrokCredentials = ngrokCredentials
        self.onChannelIdReceived = onChannelIdReceived
    }

    func start() throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [ngrokCredentials = self.ngrokCredentials, onMatch = self.onChannelIdReceived] channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(WebhookHandler(
                        ngrokCredentials: ngrokCredentials,
                        onMatch: onMatch
                    ))
                }
            }

        channel = try bootstrap.bind(host: "0.0.0.0", port: self.port).wait()
        print("Server running on port \(self.port) (background thread).")
    }

    func stop() {
        do {
            try channel?.close().wait()
        } catch {
            print("Error closing channel: \(error)")
        }
        try? group.syncShutdownGracefully()
    }
}

// MARK: - HTTP Handler
private final class WebhookHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    let ngrokCredentials: NgrokCredentials
    let onMatch: @Sendable (String) async throws -> Void

    init(ngrokCredentials: NgrokCredentials, onMatch: @escaping @Sendable (String) async throws -> Void) {
        self.ngrokCredentials = ngrokCredentials
        self.onMatch = onMatch
    }

    func respondOK(_ context: ChannelHandlerContext, _ head: HTTPRequestHead) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Length", value: "0")
        let responseHead = HTTPResponseHead(
            version: head.version, status: .ok, headers: headers)

        context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)

        if case .head(let head) = reqPart {
            guard head.method == .POST else {
                respondOK(context, head)
                return
            }

            guard let channelId = head.headers.first(name: "x-goog-channel-id"),
                  let authToken = head.headers.first(name: "x-goog-channel-token"),
                  authToken.hasPrefix("Basic ") else {
                respondOK(context, head)
                return
            }

            let base64Part = authToken.dropFirst("Basic ".count)
            guard let decoded = Data(base64Encoded: String(base64Part)),
                  let credentials = String(data: decoded, encoding: .utf8),
                  let colonIndex = credentials.firstIndex(of: ":") else {
                respondOK(context, head)
                return
            }

            let user = String(credentials[..<colonIndex])
            let password = String(credentials[credentials.index(after: colonIndex)...])

            if user == self.ngrokCredentials.user && password == self.ngrokCredentials.password {
                Task {
                    do {
                        try await onMatch(channelId)
                    } catch {
                        print("Webhook processing failed: \(error)")
                    }
                }
            }

            // Respond with 200 OK so the Google webhook doesn't timeout/retry
            respondOK(context, head)
        }
    }
}