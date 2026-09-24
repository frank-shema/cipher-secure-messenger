import CipherCore
import Foundation

/// Raised by a production port whose concrete implementation has not been plugged into
/// `ProductionFactories` yet. Surfacing this as a typed, localized error (instead of a crash) keeps the
/// shell usable while modules land one by one, and makes the missing piece obvious in a banner.
enum IntegrationError: Error, LocalizedError, Hashable, Sendable {
    case notWired(component: String)

    var errorDescription: String? {
        switch self {
        case .notWired(let component):
            String(localized: "error.integration.notWired", defaultValue: "This build is missing a component:")
                + " \(component)"
        }
    }
}

/// Stand-in for `CipherNetworking.RemoteAuthGateway` until it is wired.
struct NotWiredAuthGateway: AuthGateway {
    private let component = "CipherNetworking.RemoteAuthGateway"

    func register(username: String, password: String, displayName: String?) async throws -> Session {
        throw IntegrationError.notWired(component: component)
    }

    func login(username: String, password: String) async throws -> Session {
        throw IntegrationError.notWired(component: component)
    }

    func refresh(refreshToken: String) async throws -> Session {
        throw IntegrationError.notWired(component: component)
    }

    func logout(refreshToken: String) async throws {
        throw IntegrationError.notWired(component: component)
    }
}

/// Stand-in for `CipherNetworking.RemoteKeyDirectoryGateway` until it is wired.
struct NotWiredKeyDirectoryGateway: KeyDirectoryGateway {
    private let component = "CipherNetworking.RemoteKeyDirectoryGateway"

    func uploadKeys(_ upload: PublicKeyBundleUpload) async throws -> PublicKeyBundle {
        throw IntegrationError.notWired(component: component)
    }

    func rotateKeys(_ upload: PublicKeyBundleUpload) async throws -> PublicKeyBundle {
        throw IntegrationError.notWired(component: component)
    }

    func fetchKeys(userId: UserID) async throws -> RemoteKeyBundle {
        throw IntegrationError.notWired(component: component)
    }

    func lookup(username: String) async throws -> RemoteKeyBundle {
        throw IntegrationError.notWired(component: component)
    }
}

/// Stand-in for `CipherCrypto.KeychainIdentityKeyStore` until it is wired.
struct NotWiredIdentityKeyStore: IdentityKeyStore {
    private let component = "CipherCrypto.KeychainIdentityKeyStore"

    func hasIdentity() async throws -> Bool {
        throw IntegrationError.notWired(component: component)
    }

    func createIdentity() async throws -> PublicKeyBundleUpload {
        throw IntegrationError.notWired(component: component)
    }

    func publicKeys() async throws -> PublicKeyBundleUpload {
        throw IntegrationError.notWired(component: component)
    }

    func deleteIdentity() async throws {
        throw IntegrationError.notWired(component: component)
    }
}
