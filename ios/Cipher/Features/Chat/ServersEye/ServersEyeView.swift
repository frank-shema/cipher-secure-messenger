import CipherCore
import CipherDesign
import SwiftUI

/// Full-screen proof of the blind relay: the conversation as the person reads it beside the exact
/// envelopes the relay stores. The right column shows routing metadata and opaque bytes only, and
/// the two columns share one scroll view so they stay aligned message for message.
struct ServersEyeView: View {
    let messages: [Message]
    let contactName: String
    let envelopes: any EnvelopeProviding

    @Environment(\.dismiss) private var dismiss
    @State private var loaded: [MessageID: Envelope] = [:]

    private var visible: [Message] {
        messages.filter { !$0.content.isReaction }.suffix(60)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    Section {
                        ForEach(visible) { message in
                            ServersEyeRow(message: message, envelope: loaded[message.id], contactName: contactName)
                            Divider().overlay(CipherColor.divider)
                        }
                    } header: {
                        columnHeaders
                    }
                }
                .padding(.horizontal, CipherSpacing.md)
            }
            .background(CipherColor.background.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) { explainer }
            .navigationTitle(String(localized: "serversEye.title", defaultValue: "Server's-Eye View"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
            .task(id: visible.map(\.id)) { await loadEnvelopes() }
        }
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: CipherSpacing.md) {
            Image(systemName: "eye.trianglebadge.exclamationmark")
                .font(.title2)
                .foregroundStyle(CipherColor.accentSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CipherSpacing.xs) {
                Text(String(localized: "serversEye.explainer.title", defaultValue: "The relay only ever sees this"))
                    .font(CipherTypography.headline)
                    .foregroundStyle(CipherColor.textPrimary)
                Text(String(
                    localized: "serversEye.explainer.body",
                    defaultValue: """
                    Who, when, a counter and sealed bytes. No text, no filenames, no keys. \
                    Everything on the left is decrypted on your device alone.
                    """
                ))
                    .font(.footnote)
                    .foregroundStyle(CipherColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CipherSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CipherColor.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(CipherColor.divider).frame(height: 0.5) }
    }

    private var columnHeaders: some View {
        HStack(spacing: CipherSpacing.md) {
            columnTitle(String(localized: "serversEye.column.you", defaultValue: "What you see"), symbol: "person.fill")
            Rectangle().fill(.clear).frame(width: 1)
            columnTitle(String(localized: "serversEye.column.server", defaultValue: "What the server stores"), symbol: "server.rack")
        }
        .padding(.vertical, CipherSpacing.sm)
        .background(CipherColor.background)
        .accessibilityAddTraits(.isHeader)
    }

    private func columnTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(CipherColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadEnvelopes() async {
        for message in visible where loaded[message.id] == nil {
            guard !Task.isCancelled else { return }
            do {
                if let envelope = try await envelopes.envelope(for: message.id) {
                    loaded[message.id] = envelope
                }
            } catch {
                ChatLog.serversEye.error("envelope unavailable message=\(message.id.description, privacy: .public)")
            }
        }
        ChatLog.serversEye.info("servers-eye loaded \(self.loaded.count, privacy: .public) envelope(s)")
    }
}

#Preview {
    let bundle = PreviewMessaging.bundle()
    ServersEyeView(messages: PreviewMessaging.sampleMessages, contactName: "Bob", envelopes: bundle.chat.envelopes)
}
