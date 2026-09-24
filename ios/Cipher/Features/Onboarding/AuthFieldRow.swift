import CipherDesign
import SwiftUI

/// A field plus its inline validation line, reserved at a fixed height so the form never jumps.
struct AuthFieldRow<Field: View>: View {
    let issue: String?
    @ViewBuilder let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpacing.xs) {
            field
            Text(issue ?? " ")
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.danger)
                .padding(.horizontal, CipherSpacing.sm)
                .accessibilityHidden(issue == nil)
        }
    }
}

#Preview {
    @Previewable @State var text = "al"
    AuthFieldRow(issue: "At least 3 characters.") {
        CipherTextField(title: "Username", text: $text)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
