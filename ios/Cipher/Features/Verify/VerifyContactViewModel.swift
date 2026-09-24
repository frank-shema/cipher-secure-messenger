import CipherCore
import CipherCrypto
import CipherDesign
import Foundation
import Observation

/// Drives the safety-fingerprint screen for one contact: the eight emoji and safety number derived
/// from both parties' pinned keys, this account's QR payload, the live trust state and the result of
/// scanning the other person's code.
///
/// The contact is observed rather than fetched once, so a `key.changed` event arriving while the
/// screen is open recomputes the fingerprint instead of letting the person verify stale keys.
@MainActor
@Observable
final class VerifyContactViewModel {
    let userId: UserID

    private(set) var phase: VerifyPhase = .loading
    private(set) var contact: Contact?
    private(set) var fingerprint: SafetyFingerprint?
    private(set) var safetyNumber: SafetyNumber?
    private(set) var qrPayload = ""
    private(set) var keyChange: KeyChangeInfo?
    private(set) var outcome: VerificationOutcome?
    private(set) var isBusy = false
    private(set) var errorMessage: String?

    var isScannerPresented = false
    /// True while the key-change review card covers the fingerprint; starts true for a changed key
    /// so the person reads what happened before comparing anything.
    var isReviewingKeyChange = false

    private let dependencies: VerifyDependencies
    private let haptics: any HapticEngine
    private var myKeys: PublicKeyBundle?
    private var computeGeneration = 0
    private var hasSeededReview = false

    init(userId: UserID, dependencies: VerifyDependencies, haptics: any HapticEngine = NoopHapticEngine()) {
        self.userId = userId
        self.dependencies = dependencies
        self.haptics = haptics
    }

    var contactName: String {
        contact?.user.displayName ?? String(localized: "verify.contact.fallback", defaultValue: "this contact")
    }

    var trust: TrustState {
        contact?.trust ?? .unverified
    }

    // MARK: - Lifecycle

    /// Loads this device's public keys, then follows the contact until the task is cancelled.
    /// Attach with `.task` so navigating away ends the observation.
    func run() async {
        await loadMyKeys()
        for await latest in await dependencies.contacts.observe(userId: userId) {
            await apply(latest)
        }
        if contact == nil {
            phase = .unavailable(String(
                localized: "verify.unavailable.noContact",
                defaultValue: "This contact is not in your address book yet."
            ))
        }
    }

    // MARK: - Actions

    /// The person compared the emoji or safety number over a call and confirmed they match.
    func confirmReadAloud() async {
        await markVerified(method: .readAloud)
    }

    /// Feeds a scanned or pasted string. Returns `false` when it is not a Cipher code at all so the
    /// scanner keeps running; a decodable code always closes the scanner because its outcome, match or
    /// mismatch, is the answer the person came for.
    @discardableResult
    func handleScanned(_ raw: String) -> Bool {
        let payload: QRPayload
        do {
            payload = try QRPayload.decode(raw)
        } catch {
            VerifyLog.scanner.notice("rejected code: \(String(describing: error), privacy: .public)")
            haptics.play(.warning)
            return false
        }
        isScannerPresented = false
        Task { await resolve(payload) }
        return true
    }

    /// Clears the key-change warning without a fingerprint comparison. Keys stay as pinned; the
    /// contact simply returns to "unverified", so the chat banner stops shouting but the shield stays grey.
    func trustNewKeys() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await dependencies.contacts.setTrust(userId: userId, trust: .unverified)
            isReviewingKeyChange = false
            VerifyLog.verify.info("trusted new keys for \(self.userId.description, privacy: .public)")
        } catch {
            errorMessage = error.localizedDescription
            VerifyLog.verify.error("trust reset failed: \(String(describing: error), privacy: .public)")
        }
    }

    func beginVerifyAgain() {
        isReviewingKeyChange = false
        outcome = nil
    }

    func presentScanner() {
        outcome = nil
        isScannerPresented = true
    }

    func dismissOutcome() {
        outcome = nil
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Internals

    private func loadMyKeys() async {
        do {
            let upload = try await dependencies.identityKeys.publicKeys()
            let mine = PublicKeyBundle(
                userId: dependencies.currentUser.id,
                identityKey: upload.identityKey,
                signingKey: upload.signingKey,
                version: 0,
                createdAt: dependencies.clock.now()
            )
            myKeys = mine
            qrPayload = QRPayload(bundle: mine).encoded
        } catch {
            phase = .unavailable(String(localized: "verify.unavailable.myKeys", defaultValue: "Your identity keys could not be read."))
            VerifyLog.verify.error("own keys unavailable: \(String(describing: error), privacy: .public)")
        }
    }

    private func apply(_ latest: Contact) async {
        contact = latest
        keyChange = KeyChangeInfo(contact: latest)
        if keyChange != nil, !hasSeededReview {
            hasSeededReview = true
            isReviewingKeyChange = true
        } else if keyChange == nil {
            isReviewingKeyChange = false
        }
        guard let mine = myKeys else { return }
        guard let theirs = latest.keys, theirs.hasValidKeyLengths else {
            phase = .unavailable(String(
                localized: "verify.unavailable.theirKeys",
                defaultValue: "\(latest.user.displayName) has not published keys yet."
            ))
            return
        }
        computeGeneration += 1
        let generation = computeGeneration
        let compute = dependencies.fingerprint
        let result = await Task.detached(priority: .userInitiated) { () -> (SafetyFingerprint, SafetyNumber?) in
            let print = compute(mine, theirs)
            let number: SafetyNumber?
            do {
                number = try SafetyNumberFormatter().format(print)
            } catch {
                number = nil
            }
            return (print, number)
        }.value
        guard generation == computeGeneration else { return }
        fingerprint = result.0
        safetyNumber = result.1
        phase = .ready
        if result.1 == nil {
            VerifyLog.verify.error("safety number formatting failed for \(latest.id.description, privacy: .public)")
        }
    }

    private func resolve(_ payload: QRPayload) async {
        guard let current = contact, let pinned = current.keys else {
            outcome = .wrongPerson
            haptics.play(.warning)
            return
        }
        guard payload.userId == current.id else {
            outcome = .wrongPerson
            haptics.play(.warning)
            VerifyLog.verify.notice("scanned code for another user while verifying \(current.id.description, privacy: .public)")
            return
        }
        guard payload.matches(pinned) else {
            outcome = .keyMismatch
            haptics.play(.warning)
            VerifyLog.verify.error("scanned keys differ from pinned keys for \(current.id.description, privacy: .public)")
            return
        }
        await markVerified(method: .qrCode)
    }

    private func markVerified(method: VerificationMethod) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let verified = try await dependencies.verify.execute(userId: userId)
            contact = verified
            keyChange = nil
            isReviewingKeyChange = false
            outcome = .matched(method)
            haptics.play(.verified)
            let how = String(describing: method)
            VerifyLog.verify.info("verified \(self.userId.description, privacy: .public) via \(how, privacy: .public)")
        } catch {
            errorMessage = error.localizedDescription
            haptics.play(.warning)
            VerifyLog.verify.error("verify failed: \(String(describing: error), privacy: .public)")
        }
    }
}
