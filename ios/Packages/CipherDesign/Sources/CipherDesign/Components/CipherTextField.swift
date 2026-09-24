import SwiftUI

/// A text field whose title floats above the value once focused or filled.
/// Supports secure entry for passphrases.
public struct CipherTextField: View {
    private let title: String
    @Binding private var text: String
    private let isSecure: Bool
    @FocusState private var isFocused: Bool
    @State private var revealSecure = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a floating-label field.
    /// - Parameters:
    ///   - title: Placeholder that floats to a label.
    ///   - text: Bound value.
    ///   - isSecure: Masks input and adds a reveal toggle.
    public init(title: String, text: Binding<String>, isSecure: Bool = false) {
        self.title = title
        self._text = text
        self.isSecure = isSecure
    }

    private var isFloating: Bool { isFocused || !text.isEmpty }

    public var body: some View {
        HStack(alignment: .center, spacing: CipherSpacing.sm) {
            ZStack(alignment: .leading) {
                Text(title)
                    .font(isFloating ? CipherTypography.caption : CipherTypography.body)
                    .foregroundStyle(isFocused ? CipherColor.accent : CipherColor.textSecondary)
                    .offset(y: isFloating ? -14 : 0)
                    .allowsHitTesting(false)
                field
                    .font(CipherTypography.body)
                    .foregroundStyle(CipherColor.textPrimary)
                    .focused($isFocused)
                    .offset(y: isFloating ? 8 : 0)
                    .opacity(isFloating ? 1 : 0.01)
            }
            .frame(minHeight: 40)
            if isSecure {
                Button {
                    revealSecure.toggle()
                } label: {
                    Image(systemName: revealSecure ? "eye.slash" : "eye")
                        .foregroundStyle(CipherColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(revealSecure ? "Hide passphrase" : "Show passphrase"))
            }
        }
        .padding(.horizontal, CipherSpacing.lg)
        .padding(.vertical, CipherSpacing.sm)
        .background(CipherColor.surfaceElevated, in: .rect(cornerRadius: CipherRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: CipherRadius.md)
                .strokeBorder(isFocused ? CipherColor.accent : CipherColor.divider, lineWidth: isFocused ? 1.5 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isFloating)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isFocused)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }

    @ViewBuilder
    private var field: some View {
        if isSecure && !revealSecure {
            SecureField("", text: $text)
                .textContentType(.password)
        } else {
            TextField("", text: $text)
                .autocorrectionDisabled(isSecure)
        }
    }
}

#Preview {
    @Previewable @State var name = "Ada"
    @Previewable @State var passphrase = ""
    VStack(spacing: CipherSpacing.lg) {
        CipherTextField(title: "Display name", text: $name)
        CipherTextField(title: "Passphrase", text: $passphrase, isSecure: true)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
