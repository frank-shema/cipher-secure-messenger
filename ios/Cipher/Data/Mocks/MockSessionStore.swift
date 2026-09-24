import CipherCore
import Foundation

/// In-memory `SessionStore` for previews: optionally pre-loaded so a preview can start signed in.
actor MockSessionStore: SessionStore {
    private var session: Session?

    init(session: Session? = nil) {
        self.session = session
    }

    func load() async throws -> Session? { session }

    func save(_ session: Session) async throws {
        self.session = session
    }

    func clear() async throws {
        session = nil
    }
}
