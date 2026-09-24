import Foundation
import os

extension CoreLog {
    /// Sensitive-content scanning, trust scoring, duress mode and visibility decisions. These paths
    /// touch plaintext by definition, so they log kinds, counts and scores only, never the text.
    static let security = Logger(subsystem: "com.cipher.core", category: "security")
}
