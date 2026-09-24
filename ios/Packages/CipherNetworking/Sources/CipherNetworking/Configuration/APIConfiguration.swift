import Foundation

/// Where the relay lives. Defaults target a relay running on the same Mac as the simulator; a device on
/// the LAN overrides `baseURL` from Settings. Production deployments must use `https`/`wss`, which is why
/// `isTransportSecure` exists: the app can warn when a non-loopback host is reached in the clear.
public struct APIConfiguration: Hashable, Sendable {
    /// Scheme, host and port of the REST API, without the `/api/v1` path.
    public var baseURL: URL
    /// Full WebSocket endpoint, including the `/ws` path.
    public var webSocketURL: URL

    public init(baseURL: URL, webSocketURL: URL) {
        self.baseURL = baseURL
        self.webSocketURL = webSocketURL
    }

    /// Builds both URLs from one server address by mirroring the scheme (`http`→`ws`, `https`→`wss`).
    /// Returns nil for anything that is not an absolute http(s) URL, so a typo in Settings cannot
    /// silently point the app at nothing.
    public init?(serverURL: URL) {
        guard let scheme = serverURL.scheme?.lowercased(), let host = serverURL.host(), !host.isEmpty else { return nil }
        let socketScheme: String
        switch scheme {
        case "http": socketScheme = "ws"
        case "https": socketScheme = "wss"
        default: return nil
        }
        var rest = URLComponents()
        rest.scheme = scheme
        rest.host = host
        rest.port = serverURL.port
        var socket = rest
        socket.scheme = socketScheme
        socket.path = "/ws"
        guard let baseURL = rest.url, let webSocketURL = socket.url else { return nil }
        self.init(baseURL: baseURL, webSocketURL: webSocketURL)
    }

    /// Convenience for a Settings text field.
    public init?(serverURLString: String) {
        guard let url = URL(string: serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        self.init(serverURL: url)
    }

    /// The relay on the local machine: what the simulator talks to out of the box.
    public static let localhost = APIConfiguration(
        baseURL: StaticURL.make("http://localhost:8080"),
        webSocketURL: StaticURL.make("ws://localhost:8080/ws")
    )

    public static let `default` = localhost

    /// `baseURL` plus the versioned REST prefix; every endpoint path is appended to this.
    public var apiBaseURL: URL {
        baseURL.appending(path: CipherNetworking.restBasePath)
    }

    /// True when both channels are TLS-protected. Loopback traffic is exempt from the warning the app
    /// shows because it never leaves the machine.
    public var isTransportSecure: Bool {
        baseURL.scheme?.lowercased() == "https" && webSocketURL.scheme?.lowercased() == "wss"
    }

    public var isLoopback: Bool {
        let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1"]
        return loopbackHosts.contains(baseURL.host()?.lowercased() ?? "")
    }
}

/// Parses compile-time URL literals. Failing here is a programmer error in a string constant, never a
/// runtime condition, so it is the one place a precondition is preferable to an optional.
enum StaticURL {
    static func make(_ literal: StaticString) -> URL {
        let string = String(describing: literal)
        guard let url = URL(string: string) else {
            preconditionFailure("Static URL literal is malformed: \(string)")
        }
        return url
    }
}
