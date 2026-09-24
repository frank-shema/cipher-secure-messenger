import Foundation

/// Where the relay lives. The simulator default is the local Spring Boot relay; a physical device points
/// at the Mac's LAN address through the Settings override. Production deployments use https/wss; the
/// `NSAllowsLocalNetworking` exception in Info.plist only relaxes ATS for local addresses.
struct ServerEndpoints: Hashable, Sendable {
    let baseURL: URL
    let webSocketURL: URL

    /// `http://localhost:8080` / `ws://localhost:8080/ws`, the relay's development defaults.
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
        guard let override, let parsed = parse(override) else { return .localhost }
        return parsed
    }
}
