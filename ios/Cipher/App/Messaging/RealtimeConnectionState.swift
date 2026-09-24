import CipherCore

/// Core's socket state under a name that stays unambiguous in files that also import CipherDesign,
/// whose `ConnectionState` is the banner's presentation enum. (`CipherCore.ConnectionState` cannot be
/// spelled because the module also exports an enum named `CipherCore`.)
typealias RealtimeConnectionState = ConnectionState
