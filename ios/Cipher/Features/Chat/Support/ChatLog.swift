import os

/// Loggers for the messaging features. Only identifiers, counts and states are ever interpolated:
/// no message bodies, filenames, keys or tokens.
enum ChatLog {
    static let chat = Logger(subsystem: "com.cipher.app", category: "chat")
    static let conversations = Logger(subsystem: "com.cipher.app", category: "conversations")
    static let serversEye = Logger(subsystem: "com.cipher.app", category: "servers-eye")
}
