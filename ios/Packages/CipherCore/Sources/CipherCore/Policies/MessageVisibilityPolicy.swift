import Foundation

/// What the chat row should draw for a message's content right now.
public enum MessageVisibility: Hashable, Sendable {
    public enum BlurReason: Hashable, Sendable {
        /// Press and hold to read.
        case whisper
        /// Tap to open once.
        case viewOnce
        /// Locked until `remaining` seconds have passed.
        case timeCapsule(remaining: TimeInterval)
    }

    public enum ConsumedReason: Hashable, Sendable {
        case viewOnceOpened
        case expired
    }

    case revealed
    case blurred(BlurReason)
    case consumed(ConsumedReason)

    public var isRevealed: Bool {
        if case .revealed = self { return true }
        return false
    }

    public var isConsumed: Bool {
        if case .consumed = self { return true }
        return false
    }
}

/// Per-device facts about a message that never travel over the wire: whether the viewer is holding
/// the whisper, whether the view-once was opened and closed, and when it was read. The policy is a
/// pure function of flags plus this state so a row can re-evaluate on every tick of a timer.
public struct MessageLocalViewState: Hashable, Sendable {
    /// The whisper is being pressed right now.
    public var isHoldingToReveal: Bool
    /// Incoming: when the viewer opened the view-once. Outgoing: when the recipient's
    /// `view_once_opened` system event arrived.
    public var viewOnceOpenedAt: Date?
    /// The viewer opened and then closed the view-once; there is no second look.
    public var viewOnceDismissed: Bool
    /// When the disappearing countdown started on this device.
    public var readAt: Date?

    public init(
        isHoldingToReveal: Bool = false,
        viewOnceOpenedAt: Date? = nil,
        viewOnceDismissed: Bool = false,
        readAt: Date? = nil
    ) {
        self.isHoldingToReveal = isHoldingToReveal
        self.viewOnceOpenedAt = viewOnceOpenedAt
        self.viewOnceDismissed = viewOnceDismissed
        self.readAt = readAt
    }

    public static let initial = MessageLocalViewState()
}

/// Decides blurred / revealed / consumed for the privacy flags. Rules are checked in a fixed order,
/// most final first: something already expired is gone whatever else is set, and a sealed capsule
/// has nothing to reveal or hold, so those win over view-once and whisper.
public struct MessageVisibilityPolicy: Sendable {
    public init() {}

    public func visibility(of message: Message, localState: MessageLocalViewState, now: Date) -> MessageVisibility {
        visibility(
            flags: message.flags,
            direction: message.direction,
            expiresAt: message.expiresAt,
            localState: localState,
            now: now
        )
    }

    public func visibility(
        flags: MessageFlags,
        direction: MessageDirection,
        expiresAt: Date?,
        localState: MessageLocalViewState,
        now: Date
    ) -> MessageVisibility {
        if Self.hasExpired(flags: flags, expiresAt: expiresAt, readAt: localState.readAt, now: now) {
            return .consumed(.expired)
        }
        if case .sealed(let remaining) = TimeCapsuleState(flags: flags, now: now) {
            return .blurred(.timeCapsule(remaining: remaining))
        }
        if flags.viewOnce, let verdict = Self.viewOnceVerdict(direction: direction, localState: localState) {
            return verdict
        }
        if flags.whisper {
            return localState.isHoldingToReveal ? .revealed : .blurred(.whisper)
        }
        return .revealed
    }

    /// Two clocks can end a message: the relay-visible `expiresAt` and the read-relative timer that
    /// only the two devices know about. Whichever fires first wins.
    private static func hasExpired(flags: MessageFlags, expiresAt: Date?, readAt: Date?, now: Date) -> Bool {
        if let expiresAt, now >= expiresAt { return true }
        guard let disappearAfter = flags.disappearAfter else { return false }
        return DisappearingTimer(seconds: disappearAfter).isExpired(readAt: readAt, now: now)
    }

    /// Returns nil when the view-once is currently open, so whisper can still apply on top of it.
    /// The sender never gets to look again either: a view-once that lingers on the sending device
    /// is exactly the screenshot risk the feature exists to reduce.
    private static func viewOnceVerdict(direction: MessageDirection, localState: MessageLocalViewState) -> MessageVisibility? {
        switch direction {
        case .outgoing:
            return localState.viewOnceOpenedAt == nil ? .blurred(.viewOnce) : .consumed(.viewOnceOpened)
        case .incoming:
            guard localState.viewOnceOpenedAt != nil else { return .blurred(.viewOnce) }
            return localState.viewOnceDismissed ? .consumed(.viewOnceOpened) : nil
        }
    }
}
