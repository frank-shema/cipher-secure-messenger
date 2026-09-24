import SwiftUI

/// The kind of sensitive data Cipher detected in a draft.
public enum SensitiveContentKind: Sendable, CaseIterable {
    case password, card, iban, oneTimeCode

    /// A short noun for the detected content.
    public var noun: String {
        switch self {
        case .password: return "a password"
        case .card: return "a card number"
        case .iban: return "a bank account number"
        case .oneTimeCode: return "a one-time code"
        }
    }

    /// The SF Symbol representing this kind.
    public var symbol: String {
        switch self {
        case .password: return "key.horizontal.fill"
        case .card: return "creditcard.fill"
        case .iban: return "building.columns.fill"
        case .oneTimeCode: return "number.circle.fill"
        }
    }
}

/// An inline suggestion shown above the composer when a draft looks sensitive,
/// offering to send it as view-once with a short auto-delete timer.
public struct SensitiveContentChip: View {
    private let kind: SensitiveContentKind
    private let onAccept: () -> Void
    private let onDismiss: () -> Void

    /// Creates the chip.
    /// - Parameters:
    ///   - kind: What was detected.
    ///   - onAccept: Called when the person accepts the view-once suggestion.
    ///   - onDismiss: Called when the person dismisses the suggestion.
    public init(kind: SensitiveContentKind, onAccept: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.kind = kind
        self.onAccept = onAccept
        self.onDismiss = onDismiss
    }

    private var message: String {
        "Looks like \(kind.noun). Send as view-once and auto-delete in 1 minute?"
    }

    public var body: some View {
        HStack(alignment: .top, spacing: CipherSpacing.md) {
            Image(systemName: kind.symbol)
                .font(.title3)
                .foregroundStyle(CipherColor.accentSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CipherSpacing.sm) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(CipherColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Send as view-once", action: onAccept)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(CipherColor.accentSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CipherColor.textSecondary)
                    .padding(CipherSpacing.sm)
            }
            .accessibilityLabel("Dismiss suggestion")
        }
        .padding(CipherSpacing.md)
        .background(CipherColor.surfaceElevated, in: RoundedRectangle(cornerRadius: CipherRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CipherRadius.md, style: .continuous)
                .strokeBorder(CipherColor.accentSecondary.opacity(0.35))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
    }
}

#Preview("SensitiveContentChip") {
    VStack(spacing: CipherSpacing.md) {
        ForEach(SensitiveContentKind.allCases, id: \.self) { kind in
            SensitiveContentChip(kind: kind, onAccept: {}, onDismiss: {})
        }
    }
    .padding(CipherSpacing.lg)
    .background(CipherColor.background)
}
