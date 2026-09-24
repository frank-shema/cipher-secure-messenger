import CipherCore
import Foundation
import Testing
@testable import Cipher

struct DemoBotMemoryTests {
    private func makeDefaults() throws -> UserDefaults {
        let suite = "DemoBotMemoryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func countersContinueAcrossLaunches() throws {
        let defaults = try makeDefaults()
        let conversation = ConversationID(UUID())
        let firstLaunch = DemoBotMemory(defaults: defaults)
        #expect(firstLaunch.reserveSendCounter(conversationId: conversation, atLeast: 0) == 0)
        #expect(firstLaunch.reserveSendCounter(conversationId: conversation, atLeast: 1) == 1)
        #expect(firstLaunch.reserveSendCounter(conversationId: conversation, atLeast: 2) == 2)

        // A new process rebuilds the in-memory store, whose counter starts at 0 again.
        let secondLaunch = DemoBotMemory(defaults: defaults)
        #expect(secondLaunch.reserveSendCounter(conversationId: conversation, atLeast: 0) == 3)
        #expect(secondLaunch.reserveSendCounter(conversationId: conversation, atLeast: 1) == 4)
    }

    @Test func countersAreIndependentPerConversation() throws {
        let defaults = try makeDefaults()
        let memory = DemoBotMemory(defaults: defaults)
        let first = ConversationID(UUID())
        let second = ConversationID(UUID())
        #expect(memory.reserveSendCounter(conversationId: first, atLeast: 0) == 0)
        #expect(memory.reserveSendCounter(conversationId: first, atLeast: 1) == 1)
        #expect(memory.reserveSendCounter(conversationId: second, atLeast: 0) == 0)
    }

    @Test func floorWinsWhenTheStoreIsAhead() throws {
        let defaults = try makeDefaults()
        let memory = DemoBotMemory(defaults: defaults)
        let conversation = ConversationID(UUID())
        #expect(memory.reserveSendCounter(conversationId: conversation, atLeast: 7) == 7)
        #expect(memory.reserveSendCounter(conversationId: conversation, atLeast: 0) == 8)
    }

    @Test func forgettingGreetingsKeepsCounters() throws {
        let defaults = try makeDefaults()
        let memory = DemoBotMemory(defaults: defaults)
        let conversation = ConversationID(UUID())
        _ = memory.reserveSendCounter(conversationId: conversation, atLeast: 0)
        memory.forgetEveryone()
        #expect(memory.reserveSendCounter(conversationId: conversation, atLeast: 0) == 1)
    }
}
