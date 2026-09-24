import SwiftUI

/// A circular avatar showing up to two initials on a hue derived
/// deterministically from a seed, so the same contact always gets the same color.
public struct InitialsAvatar<Ring: View>: View {
    private let name: String
    private let seed: String
    private let size: CGFloat
    private let ring: Ring

    /// Creates an avatar.
    /// - Parameters:
    ///   - name: Display name used to derive the initials.
    ///   - seed: Stable identifier hashed for the hue. Defaults to `name`.
    ///   - size: Diameter in points.
    ///   - ring: Optional overlay (presence dot, verified shield) drawn over the avatar.
    public init(
        name: String,
        seed: String? = nil,
        size: CGFloat = 44,
        @ViewBuilder ring: () -> Ring
    ) {
        self.name = name
        self.seed = seed ?? name
        self.size = size
        self.ring = ring()
    }

    public var body: some View {
        let hue = AvatarIdentity.hue(for: seed)
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.55, brightness: 0.78),
                            Color(hue: hue, saturation: 0.7, brightness: 0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            Text(AvatarIdentity.initials(from: name))
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) { ring }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Avatar for \(name)"))
    }
}

/// Pure helpers that derive an avatar's identity from a name and seed.
/// Separated from the generic view so they can be called without a type witness.
public enum AvatarIdentity {
    /// Deterministic hue in `0...1` derived from a djb2 hash of `seed`.
    public static func hue(for seed: String) -> Double {
        var hash: UInt32 = 5381
        for byte in seed.utf8 {
            hash = (hash &* 33) &+ UInt32(byte)
        }
        return Double(hash % 360) / 360
    }

    /// Up to two uppercase initials from the first and last word of `name`.
    public static func initials(from name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard let first = words.first?.first else { return "?" }
        if words.count > 1, let last = words.last?.first {
            return String([first, last]).uppercased()
        }
        return String(first).uppercased()
    }
}

public extension InitialsAvatar where Ring == EmptyView {
    /// Creates an avatar with no ring overlay.
    init(name: String, seed: String? = nil, size: CGFloat = 44) {
        self.init(name: name, seed: seed, size: size) { EmptyView() }
    }
}

#Preview {
    HStack(spacing: CipherSpacing.lg) {
        InitialsAvatar(name: "Ada Lovelace", size: 56)
        InitialsAvatar(name: "Grace Hopper", size: 44) {
            PresenceDot(online: true)
        }
        InitialsAvatar(name: "Turing", size: 36)
    }
    .padding()
    .background(CipherColor.background)
}
