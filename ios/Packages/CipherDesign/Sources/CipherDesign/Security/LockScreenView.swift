import SwiftUI

/// The app lock screen: lock glyph, title, an optional biometric shortcut and a PIN pad.
public struct LockScreenView: View {
    private let title: String
    private let biometricAvailable: Bool
    private let errorTrigger: Int
    private let onBiometric: () -> Void
    private let onPIN: (String) -> Void

    /// Creates a lock screen.
    /// - Parameters:
    ///   - title: Heading such as "Unlock Cipher".
    ///   - biometricAvailable: Shows a Face ID / Touch ID button when `true`.
    ///   - digits: PIN length forwarded to the pad.
    ///   - errorTrigger: Increment after a wrong PIN to shake the pad.
    ///   - onBiometric: Called when the biometric button is tapped.
    ///   - onPIN: Called with a complete PIN.
    public init(
        title: String = "Unlock Cipher",
        biometricAvailable: Bool,
        digits: PINLength = .six,
        errorTrigger: Int = 0,
        onBiometric: @escaping () -> Void,
        onPIN: @escaping (String) -> Void
    ) {
        self.title = title
        self.biometricAvailable = biometricAvailable
        self.digits = digits
        self.errorTrigger = errorTrigger
        self.onBiometric = onBiometric
        self.onPIN = onPIN
    }

    private let digits: PINLength

    public var body: some View {
        ZStack {
            CipherColor.background.ignoresSafeArea()
            VStack(spacing: CipherSpacing.xxl) {
                VStack(spacing: CipherSpacing.md) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(CipherColor.accent)
                        .shadow(color: CipherColor.accent.opacity(0.5), radius: 12)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(CipherColor.textPrimary)
                    Text("Enter your PIN to continue")
                        .font(.footnote)
                        .foregroundStyle(CipherColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                PINPadView(digits: digits, errorTrigger: errorTrigger, onComplete: onPIN)
                if biometricAvailable {
                    Button(action: onBiometric) {
                        Label("Use Face ID", systemImage: "faceid")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(CipherColor.accent)
                }
            }
            .padding(CipherSpacing.xl)
        }
    }
}

#Preview("LockScreenView") {
    LockScreenView(biometricAvailable: true, onBiometric: {}, onPIN: { _ in })
}
