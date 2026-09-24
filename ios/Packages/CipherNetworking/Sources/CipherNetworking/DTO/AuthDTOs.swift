import CipherCore
import Foundation

/// `POST /auth/register` body (PROTOCOL.md §1.1). `displayName` is omitted from the JSON when nil so
/// the relay applies its own default (the username).
public struct RegisterRequest: Hashable, Encodable, Sendable {
    public var username: String
    public var password: String
    public var displayName: String?

    public init(username: String, password: String, displayName: String?) {
        self.username = username
        self.password = password
        self.displayName = displayName
    }
}

/// `POST /auth/login` body.
public struct LoginRequest: Hashable, Encodable, Sendable {
    public var username: String
    public var password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// `POST /auth/refresh` and `POST /auth/logout` share this body.
public struct RefreshTokenRequest: Hashable, Encodable, Sendable {
    public var refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

/// The `user` object inside `AuthResponse`.
public struct UserDTO: Hashable, Codable, Sendable {
    public var id: UserID
    public var username: String
    public var displayName: String

    public init(id: UserID, username: String, displayName: String) {
        self.id = id
        self.username = username
        self.displayName = displayName
    }

    public func toDomain() -> User {
        User(id: id, username: username, displayName: displayName)
    }
}

/// `AuthResponse` (PROTOCOL.md §1.1). `accessTokenExpiresIn` is relative seconds; it becomes an absolute
/// expiry at the moment the request was *started*, which errs on the early side and keeps a request from
/// leaving with a token that expires in flight.
public struct AuthResponseDTO: Hashable, Decodable, Sendable, APIResponse {
    public var user: UserDTO
    public var accessToken: String
    public var refreshToken: String
    public var accessTokenExpiresIn: Int

    public init(user: UserDTO, accessToken: String, refreshToken: String, accessTokenExpiresIn: Int) {
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessTokenExpiresIn = accessTokenExpiresIn
    }

    public func toDomain(issuedAt: Date) -> Session {
        Session(
            user: user.toDomain(),
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessTokenExpiresAt: issuedAt.addingTimeInterval(TimeInterval(accessTokenExpiresIn))
        )
    }
}
