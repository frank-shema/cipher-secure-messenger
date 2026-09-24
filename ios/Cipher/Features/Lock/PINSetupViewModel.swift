import CipherCore
import CipherDesign
import Foundation
import Observation

/// What a `PINSetupSheet` is being asked to do. Everything but creating the first PIN starts by
/// confirming the current one, so a phone left unlocked on a desk cannot have its lock rewritten.
enum PINSetupIntent: Hashable, Identifiable, Sendable {
    case createPIN
    case changePIN
    case disableLock
    case createDuressPIN
    case changeDuressPIN

    var id: Self { self }

    var isDuress: Bool {
        self == .createDuressPIN || self == .changeDuressPIN
    }

    var requiresCurrentPIN: Bool {
        self != .createPIN
    }
}

/// The three-step state machine behind the sheet: confirm the current PIN, enter the new one, repeat it.
@MainActor
@Observable
final class PINSetupViewModel {
    enum Step: Hashable {
        case verifyCurrent
        case enterNew
        case confirmNew
    }

    let intent: PINSetupIntent
    private(set) var step: Step
    private(set) var errorTrigger = 0
    private(set) var message: String?
    private(set) var isFinished = false
    private(set) var isBusy = false
    /// Set when saving a new real PIN silently removed the duress PIN, so the sheet can say so.
    private(set) var duressPINDropped = false
    var newLength: PINLength

    @ObservationIgnored private var candidate: String?
    @ObservationIgnored private let lock: AppLockManager

    init(intent: PINSetupIntent, lock: AppLockManager) {
        self.intent = intent
        self.lock = lock
        self.step = intent.requiresCurrentPIN ? .verifyCurrent : .enterNew
        self.newLength = lock.settings.pinLength
    }

    /// The real PIN may change length; the duress PIN must match the real one so the pad completes at the
    /// same digit for both.
    var canChooseLength: Bool {
        step == .enterNew && !intent.isDuress
    }

    var digits: PINLength {
        switch step {
        case .verifyCurrent: lock.settings.pinLength
        case .enterNew, .confirmNew: intent.isDuress ? lock.settings.pinLength : newLength
        }
    }

    var title: String {
        switch step {
        case .verifyCurrent: String(localized: "pinSetup.step.verify", defaultValue: "Enter your current PIN")
        case .enterNew where intent.isDuress: String(localized: "pinSetup.step.enterDuress", defaultValue: "Choose a duress PIN")
        case .enterNew: String(localized: "pinSetup.step.enter", defaultValue: "Choose a PIN")
        case .confirmNew: String(localized: "pinSetup.step.confirm", defaultValue: "Enter it again")
        }
    }

    func submit(_ pin: String) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        switch step {
        case .verifyCurrent: await verifyCurrent(pin)
        case .enterNew: enterNew(pin)
        case .confirmNew: await confirmNew(pin)
        }
    }

    private func verifyCurrent(_ pin: String) async {
        guard await lock.confirm(pin) else {
            fail(lock.isLockedOut
                ? String(localized: "pinSetup.error.lockedOut", defaultValue: "Too many attempts. Try again later.")
                : String(localized: "pinSetup.error.wrongPIN", defaultValue: "That is not your current PIN."))
            return
        }
        if intent == .disableLock {
            do {
                try lock.disableLock()
                isFinished = true
            } catch {
                fail(error.localizedDescription)
            }
            return
        }
        advance(to: .enterNew)
    }

    private func enterNew(_ pin: String) {
        do {
            try PINRules.validate(pin)
        } catch {
            fail(error.localizedDescription)
            return
        }
        candidate = pin
        advance(to: .confirmNew)
    }

    private func confirmNew(_ pin: String) async {
        guard let candidate, PINRules.constantTimeEquals(pin, candidate) else {
            self.candidate = nil
            fail(String(localized: "pinSetup.error.mismatch", defaultValue: "The PINs did not match. Start again."))
            step = .enterNew
            return
        }
        do {
            if intent.isDuress {
                try await lock.setDuressPIN(candidate)
            } else {
                duressPINDropped = try await lock.setPIN(candidate, length: newLength)
            }
            isFinished = true
        } catch {
            self.candidate = nil
            fail(error.localizedDescription)
            step = .enterNew
        }
    }

    private func advance(to next: Step) {
        message = nil
        step = next
    }

    private func fail(_ text: String) {
        message = text
        errorTrigger += 1
    }
}
