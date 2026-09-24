import Foundation

// `/api/v1/auth/*` (PROTOCOL.md §1.1). None of these carry a Bearer token: they are the routes that
// mint one, and sending a stale token to them could only confuse a proxy.

/// `POST /auth/register` → 201 `AuthResponse`.
public struct RegisterEndpoint: Endpoint {
    public typealias Response = AuthResponseDTO

    public var request: RegisterRequest

    public init(_ request: RegisterRequest) {
        self.request = request
    }

    public var path: String { "auth/register" }
    public var method: HTTPMethod { .post }
    public var body: RequestBody { .json(request) }
    public var requiresAuth: Bool { false }
}

/// `POST /auth/login` → 200 `AuthResponse`.
public struct LoginEndpoint: Endpoint {
    public typealias Response = AuthResponseDTO

    public var request: LoginRequest

    public init(_ request: LoginRequest) {
        self.request = request
    }

    public var path: String { "auth/login" }
    public var method: HTTPMethod { .post }
    public var body: RequestBody { .json(request) }
    public var requiresAuth: Bool { false }
}

/// `POST /auth/refresh` → 200 `AuthResponse` with a rotated refresh token.
public struct RefreshEndpoint: Endpoint {
    public typealias Response = AuthResponseDTO

    public var request: RefreshTokenRequest

    public init(_ request: RefreshTokenRequest) {
        self.request = request
    }

    public var path: String { "auth/refresh" }
    public var method: HTTPMethod { .post }
    public var body: RequestBody { .json(request) }
    public var requiresAuth: Bool { false }
}

/// `POST /auth/logout` → 204.
public struct LogoutEndpoint: Endpoint {
    public typealias Response = Empty

    public var request: RefreshTokenRequest

    public init(_ request: RefreshTokenRequest) {
        self.request = request
    }

    public var path: String { "auth/logout" }
    public var method: HTTPMethod { .post }
    public var body: RequestBody { .json(request) }
    public var requiresAuth: Bool { false }
}
