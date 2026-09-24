import CipherCore
import CipherPersistence
import Foundation

/// The SwiftData store already records first openings durably; this only names it as the port.
extension PersistenceStore: ViewOnceMarking {}
