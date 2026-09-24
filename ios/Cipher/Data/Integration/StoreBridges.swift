import CipherCore
import CipherPersistence
import Foundation

/// Keeps the relay's copy of an incoming envelope next to the decrypted message. Outgoing envelopes
/// are mirrored automatically when queued; incoming ones are attached by the runtime that received
/// them, because the domain `Message` deliberately carries no ciphertext.
protocol RawEnvelopeRecording: Sendable {
    func attachRawEnvelope(messageId: MessageID, envelope: Envelope) async throws
}

extension PersistenceStore: RawEnvelopeRecording {}

/// `EnvelopeProviding` over the account store, with the vault as the second chance: an envelope seen
/// on the wire but not yet attached to its row is attached now, so the next flip reads from disk.
struct StoredEnvelopeProvider: EnvelopeProviding {
    private let store: PersistenceStore
    private let vault: EnvelopeVault

    init(store: PersistenceStore, vault: EnvelopeVault) {
        self.store = store
        self.vault = vault
    }

    func envelope(for messageId: MessageID) async throws -> Envelope? {
        if let data = try await store.rawEnvelope(messageId: messageId),
           let stored = try? WireJSON.decode(Envelope.self, from: data) {
            return stored
        }
        guard let remembered = await vault.envelope(for: messageId) else { return nil }
        do {
            try await store.attachRawEnvelope(messageId: messageId, envelope: remembered)
        } catch {
            AppLog.messaging.debug("envelope for \(messageId.description, privacy: .public) kept in memory only")
        }
        return remembered
    }
}
