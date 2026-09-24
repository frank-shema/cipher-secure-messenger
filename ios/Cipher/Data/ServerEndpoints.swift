import Foundation

/// Where the relay lives. The default is the hosted demo relay so a fresh install works with no setup;
/// `make up` users switch to `localhost` through the Settings override. Production deployments use
/// https/wss; the demo relay is plain http, which is why Info.plist relaxes App Transport Security.
struct ServerEndpoints: Hashable, Sendable {
    let baseURL: URL
    let webSocketURL: URL

    /// The publicly hosted demo relay (see docs/DEPLOYMENT.md).
    static let hosted = ServerEndpoints(
        baseURL: URL(string: "http://104.248.131.165:8080") ?? URL(fileURLWithPath: "/"),
        webSocketURL: URL(string: "ws://104.248.131.165:8080/ws") ?? URL(fileURLWithPath: "/")
    )

    /// `http://localhost:8080` / `ws://localhost:8080/ws`, the relay started by `make up`.
    static let localhost = ServerEndpoints(
        baseURL: URL(string: "http://localhost:8080") ?? URL(fileURLWithPath: "/"),
        webSocketURL: URL(string: "ws://localhost:8080/ws") ?? URL(fileURLWithPath: "/")
    )

    /// Parses a person-typed base URL such as `http://192.168.1.20:8080` and derives the WebSocket URL
    /// from it (`http` → `ws`, `https` → `wss`, path `/ws`), so only one field needs to be right.
    static func parse(_ raw: String) -> ServerEndpoints? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty
        else { return nil }
        components.scheme = scheme
        components.query = nil
        components.fragment = nil
        components.path = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        guard let base = components.url else { return nil }
        components.scheme = scheme == "https" ? "wss" : "ws"
        components.path += "/ws"
        guard let socket = components.url else { return nil }
        return ServerEndpoints(baseURL: base, webSocketURL: socket)
    }

    /// The override wins only when it parses; a half-typed value never silently breaks connectivity.
    static func resolve(override: String?) -> ServerEndpoints {
        guard let override, let parsed = parse(override) else { return .hosted }
        return parsed
    }
}
