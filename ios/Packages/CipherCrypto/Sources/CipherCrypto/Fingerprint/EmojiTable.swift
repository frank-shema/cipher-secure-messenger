import Foundation

/// The curated 256-entry emoji table for safety fingerprints (PROTOCOL.md §4). Each digest byte maps
/// to exactly one entry, so the table is the contract both devices must share byte-for-byte; never
/// reorder or replace entries without bumping the protocol version.
///
/// Curation rules, because people compare these by eye across a room or over a phone call:
/// - visually distinct silhouettes and colours; no near-lookalikes (one dog, one cat, one whale);
/// - no skin-tone or gender variants, no flags, no ZWJ sequences, no text-presentation glyphs that
///   need a variation selector, so every entry is a single code point that renders identically
///   on every supported OS version;
/// - familiar animals, food, objects and places that are easy to name aloud in any language.
public enum EmojiTable {
    public static let count = 256

    /// The table, indexed by digest byte.
    public static let entries: [String] = [
        // Animals
        "🐶", "🐱", "🐭", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧",
        "🐦", "🐤", "🦆", "🦅", "🦉", "🦇", "🐺", "🐴", "🦄", "🐝", "🐛", "🦋", "🐌", "🐞", "🐜", "🦂",
        "🐢", "🐍", "🦎", "🐙", "🦑", "🦐", "🦀", "🐡", "🐠", "🐬", "🐳", "🦈", "🐊", "🦓", "🦍", "🐘",
        "🦛", "🦏", "🐪", "🦒", "🦘", "🐑", "🐐", "🦌", "🦃", "🦜", "🦚", "🦩", "🦔", "🦥", "🦦", "🦖",
        // Food
        "🍎", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍒", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥒",
        "🌽", "🥕", "🧄", "🥔", "🥐", "🥨", "🧀", "🥚", "🍳", "🥞", "🥓", "🍔", "🍟", "🍕", "🌭", "🌮",
        "🥗", "🍿", "🥫", "🍱", "🍙", "🍜", "🍣", "🥟", "🍦", "🍩", "🍪", "🎂", "🍫", "🍭", "🍯", "☕",
        "🍵", "🍺", "🍷", "🧊", "🫐", "🥜", "🍞", "🍬",
        // Nature
        "🌵", "🎄", "🌴", "🌱", "🍀", "🍁", "🍄", "🌾", "💐", "🌷", "🌹", "🌻", "🌺", "🪷", "🌍", "🌙",
        "⭐", "✨", "⚡", "🔥", "🌈", "🌞", "⛄", "💧", "🌊", "🌋", "🗻", "🐚",
        // Objects
        "⌚", "📱", "💻", "📷", "📺", "🎧", "🎤", "🎸", "🎹", "🎺", "🥁", "🎯", "🎲", "🎮", "🧩", "🪁",
        "🎁", "🎈", "🎀", "🏆", "⚽", "🏀", "🏈", "🏓", "🥊", "🎳", "🔑", "🔒", "🔔", "📌", "🧲", "🔭",
        "💡", "🔦", "🔨", "🪓", "🧬", "💊", "💉", "🧶", "👓", "🎩", "👑", "💍", "👟", "📚", "📦", "💰",
        "💎", "🧭", "⏰", "⌛", "🎓", "🧸", "🎠", "🛒", "🧹", "🚪", "🛁", "🎉", "🏮", "📡", "🔋", "🔌",
        "🧱", "🪄", "🔮", "🎣", "🎨", "🎭", "🎵", "🃏",
        // Places
        "🚗", "🚌", "🚑", "🚜", "🚲", "🛵", "🚂", "🚀", "🛸", "🚁", "⛵", "🚤", "🛶", "🚢", "⚓", "🚦",
        "🏠", "🏰", "🗼", "🗽", "🎪", "⛺", "🗿", "⛲",
        // Faces
        "😎", "🤠", "🥶", "🤖", "👻", "💀", "👽", "🎃", "🤡", "👾", "🧠", "👀",
    ]

    /// Lookup by digest byte; the table has exactly 256 entries so every byte value is covered.
    public static func emoji(for byte: UInt8) -> String {
        entries[Int(byte)]
    }
}
