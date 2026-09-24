import CipherCore
import Foundation

/// Tiny preview wiring for the trust feature: a seeded in-memory store plus the real evaluator with
/// the always-on metadata policy, so previews score exactly like production does.
@MainActor
enum TrustPreview {
    enum Scenario {
        case verified
        case unverified
        case keyChanged
    }

    static func viewModel(_ scenario: Scenario) -> TrustRingViewModel {
        let now = PreviewMessaging.frozenNow
        let store = PreviewMessagingStore.seeded(now: now)
        let conversations = MessagingFixtures.conversations(now: now)
        let conversation: Conversation
        switch scenario {
        case .verified:
            conversation = conversations.first { $0.contact.trust.isVerified } ?? PreviewMessaging.sampleConversation
        case .unverified:
            conversation = conversations.first { $0.contact.trust == .unverified } ?? PreviewMessaging.sampleConversation
        case .keyChanged:
            conversation = conversations.first { $0.contact.trust.needsAttention } ?? PreviewMessaging.sampleConversation
        }
        let evaluator = EvaluateTrustUseCase(conversations: store, preferences: AlwaysOnMetadataStripping())
        return TrustRingViewModel(conversation: conversation, evaluator: evaluator, contacts: store)
    }
}
