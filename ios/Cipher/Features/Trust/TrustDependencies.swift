import CipherCore
import Foundation

/// Scores one conversation (`EvaluateTrustUseCase`). A narrow port, like the chat feature's, so the
/// sheet can be previewed with a fixed preference set and tested without a repository.
protocol TrustEvaluating: Sendable {
    func execute(conversation: Conversation) async -> TrustReport
}

extension EvaluateTrustUseCase: TrustEvaluating {}

/// Metadata stripping is not a switch in Cipher: the attachments pipeline removes EXIF, GPS and
/// camera fields from every photo before it is sealed, unconditionally. The trust evaluator still
/// takes the signal as an input so a future build could expose a toggle, but today the honest answer
/// is always "on", and this reader says so without touching UserDefaults.
struct AlwaysOnMetadataStripping: PrivacyPreferencesReader {
    func isMetadataStrippingEnabled() async -> Bool {
        true
    }
}

/// What the trust sheet asks its host to do. Closures rather than a Router so the sheet can be
/// presented from the chat header, from the inbox or from a deep link without knowing which.
struct TrustActions {
    /// Open the safety-number comparison for the contact (`Router.navigate(to: .verify(userId))`).
    var onVerifyKeys: @MainActor () -> Void
    /// Apply a conversation-level disappearing timer; the chat's `setDisappearingTimer` fits directly.
    var onEnableDisappearing: @MainActor (TimeInterval) -> Void
    /// Show the key-change review (today the same verification screen, framed as a re-check).
    var onReviewKeyChange: @MainActor () -> Void

    init(
        onVerifyKeys: @escaping @MainActor () -> Void = {},
        onEnableDisappearing: @escaping @MainActor (TimeInterval) -> Void = { _ in },
        onReviewKeyChange: @escaping @MainActor () -> Void = {}
    ) {
        self.onVerifyKeys = onVerifyKeys
        self.onEnableDisappearing = onEnableDisappearing
        self.onReviewKeyChange = onReviewKeyChange
    }
}
