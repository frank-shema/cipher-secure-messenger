import CipherCore

/// Core's detector kind under a local name. It cannot be written as `CipherCore.SensitiveContentKind`
/// because the module also exports an enum named `CipherCore`, and CipherDesign declares a chip enum
/// with the same short name; this file imports only Core so the lookup is unambiguous.
typealias SensitiveKind = SensitiveContentKind
