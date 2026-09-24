import CipherCore
import CipherDesign
import SwiftUI

/// Centred notice for protocol-level events (key verified, timer changed, screenshot, view-once
/// opened). Phrased around the contact's name so it reads as a sentence, not a log line.
struct SystemMessageView: View {
    let event: SystemEvent
    let contactName: String
    let date: Date

    private var symbol: String {
        switch event.kind {
        case .screenshotTaken: "camera.viewfinder"
        case .viewOnceOpened: "eye"
        case .disappearingChanged: "timer"
        case .keyVerified: "checkmark.shield"
        }
    }

    private var tint: Color {
        switch event.kind {
        case .keyVerified: CipherColor.success
        case .screenshotTaken: CipherColor.warning
        case .viewOnceOpened, .disappearingChanged: CipherColor.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: CipherSpacing.xs) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
            Text(MessageFormatting.systemText(for: event.kind, contactName: contactName))
                .font(.caption)
            Text(MessageFormatting.time(date))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(CipherColor.textSecondary.opacity(0.7))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, CipherSpacing.md)
        .padding(.vertical, CipherSpacing.xs + 2)
        .background(CipherColor.surfaceElevated, in: Capsule())
        .overlay(Capsule().strokeBorder(CipherColor.divider))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: CipherSpacing.md) {
        ForEach(SystemEvent.Kind.allCases, id: \.self) { kind in
            SystemMessageView(event: SystemEvent(kind: kind), contactName: "Bob", date: PreviewMessaging.frozenNow)
        }
    }
    .padding()
    .background(CipherColor.background)
}
