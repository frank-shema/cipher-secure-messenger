import CipherCore
import Foundation

/// Typing in both directions over the WebSocket. Outgoing signals are fire-and-forget (a lost
/// `typing.stop` is covered by the chat's own timeout); incoming ones are fanned out per conversation
/// from the realtime pump, so only the open chat ever sees them.
actor RealtimeTypingSignaller: TypingSignaller {
    private let realtime: any RealtimeGateway
    private var observers: [UUID: (ConversationID, AsyncStream<TypingSignal>.Continuation)] = [:]

    init(realtime: any RealtimeGateway) {
        self.realtime = realtime
    }

    func setTyping(_ isTyping: Bool, in conversationId: ConversationID) async {
        do {
            try await realtime.send(isTyping ? .typingStart(conversationId: conversationId) : .typingStop(conversationId: conversationId))
        } catch {
            AppLog.realtime.debug("typing signal dropped: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    func incomingTyping(in conversationId: ConversationID) async -> AsyncStream<TypingSignal> {
        let key = UUID()
        let (stream, continuation) = AsyncStream<TypingSignal>.makeStream(bufferingPolicy: .bufferingNewest(4))
        observers[key] = (conversationId, continuation)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(key) }
        }
        return stream
    }

    /// Called by the realtime pump for every typing event the relay pushes.
    func dispatch(_ signal: TypingSignal) {
        for (conversationId, continuation) in observers.values where conversationId == signal.conversationId {
            continuation.yield(signal)
        }
    }

    func finishAll() {
        for (_, continuation) in observers.values { continuation.finish() }
        observers.removeAll()
    }

    private func remove(_ key: UUID) {
        observers.removeValue(forKey: key)
    }
}
