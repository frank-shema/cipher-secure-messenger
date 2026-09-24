import SwiftUI

/// A monospace key/value dump for the Server's-Eye panel: exactly the ciphertext
/// and metadata a server would see. Long values truncate in the middle; tapping a
/// row expands it, and each row has a copy affordance.
public struct ServerEyeRawView: View {
    private let fields: [(label: String, value: String)]
    private let onCopy: ((String) -> Void)?

    @State private var expanded: Set<Int> = []

    /// Creates the raw view.
    /// - Parameters:
    ///   - fields: Ordered label/value pairs to display.
    ///   - onCopy: Receives the value to copy; defaults to the system pasteboard.
    public init(fields: [(label: String, value: String)], onCopy: ((String) -> Void)? = nil) {
        self.fields = fields
        self.onCopy = onCopy
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                row(index: index, label: field.label, value: field.value)
                if index < fields.count - 1 {
                    Divider().overlay(CipherColor.textSecondary.opacity(0.15))
                }
            }
        }
        .background(CipherColor.surface, in: RoundedRectangle(cornerRadius: CipherRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CipherRadius.md, style: .continuous)
                .strokeBorder(CipherColor.accent.opacity(0.2))
        )
    }

    private func row(index: Int, label: String, value: String) -> some View {
        let isExpanded = expanded.contains(index)
        return HStack(alignment: .top, spacing: CipherSpacing.md) {
            VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundStyle(CipherColor.accent)
                Text(value)
                    .font(.footnote.monospaced())
                    .foregroundStyle(CipherColor.textPrimary)
                    .lineLimit(isExpanded ? nil : 1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                if isExpanded { expanded.remove(index) } else { expanded.insert(index) }
            }
            Button { copy(value) } label: {
                Image(systemName: "doc.on.doc")
                    .font(.footnote)
                    .foregroundStyle(CipherColor.textSecondary)
                    .padding(CipherSpacing.xs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy \(label)")
        }
        .padding(.horizontal, CipherSpacing.lg)
        .padding(.vertical, CipherSpacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand")
    }

    private func copy(_ value: String) {
        if let onCopy {
            onCopy(value)
            return
        }
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
}

#Preview("ServerEyeRawView") {
    ServerEyeRawView(fields: [
        ("recipient", "7f3a…c21e (sealed sender)"),
        ("ciphertext", "AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyAhIiMkJSYnKCkqKywtLi8wMTIzNDU2Nzg5Ojs8PT4/QA=="),
        ("timestamp", "1727212800"),
        ("size", "1,024 B")
    ])
    .padding(CipherSpacing.lg)
    .background(CipherColor.background)
}
