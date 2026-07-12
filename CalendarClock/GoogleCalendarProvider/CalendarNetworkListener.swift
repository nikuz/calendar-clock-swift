import NIO
import NIOHTTP1

final class CalendarWebhookServer {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private var channel: Channel?
    private let port: Int
    private let onChannelIdReceived: (String) async throws -> Void

    init(port: Int, onChannelIdReceived: @escaping (String) async throws -> Void) {
        self.port = port
        self.onChannelIdReceived = onChannelIdReceived
    }

    func start() throws {
        let bootstrap = ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(WebhookHandler(onMatch: self.onChannelIdReceived))
                }
            }

        channel = try bootstrap.bind(host: "0.0.0.0", port: self.port).wait()
        print("Server running on port \(self.port) (background thread).")
    }

    func stop() {
        try? group.syncShutdownGracefully()
    }
}

// MARK: - HTTP Handler
private final class WebhookHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    let onMatch: (String) async throws -> Void

    init(onMatch: @escaping (String) async throws -> Void) {
        self.onMatch = onMatch
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)

        if case .head(let head) = reqPart {
            // Check for POST method and the target header
            if head.method == .POST, let channelId = head.headers.first(name: "X-Goog-Channel-Id") {
                Task {
                    try await onMatch(channelId)
                }
            }

            // Respond with 200 OK so the Google webhook doesn't timeout/retry
            var headers = HTTPHeaders()
            headers.add(name: "Content-Length", value: "0")
            let responseHead = HTTPResponseHead(
                version: head.version, status: .ok, headers: headers)

            context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        }
    }
}