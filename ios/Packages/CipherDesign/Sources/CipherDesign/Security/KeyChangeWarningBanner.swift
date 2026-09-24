import SwiftUI

/// A full-width red banner shown when a contact's safety number changes, with a
/// call to action to review the new keys before continuing.
public struct KeyChangeWarningBanner: View {
    private let contactName: String
    private let onReview: () -> Void

    /// Creates the banner.
    /// - Parameters:
    ///   - contactName: The contact whose keys changed.
    ///   - onReview: Called when the person taps "Review".
    public init(contactName: String, onReview: @escaping () -> Void) {
        self.contactName = contactName
        self.onReview = onReview
    }

    public var body: some View {
        HStack(alignment: .center, spacing: CipherSpacing.md) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                Text("\(contactName)'s safety number changed")
                    .font(.subheadline.weight(.semibold))
                Text("Verify before you send anything sensitive.")
                    .font(.footnote)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Review", action: onReview)
                .font(.subheadline.weight(.bold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.white)
                .foregroundStyle(CipherColor.danger)
        }
        .padding(.horizontal, CipherSpacing.lg)
        .padding(.vertical, CipherSpacing.md)
        .frame(maxWidth: .infinity)
        .background(CipherColor.danger)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: \(contactName)'s safety number changed. Verify before you send anything sensitive.")
        .accessibilityAction(named: "Review", onReview)
    }
}

#Preview("KeyChangeWarningBanner") {
    VStack(spacing: 0) {
        KeyChangeWarningBanner(contactName: "Amara") {}
        Spacer()
    }
    .background(CipherColor.background)
}
