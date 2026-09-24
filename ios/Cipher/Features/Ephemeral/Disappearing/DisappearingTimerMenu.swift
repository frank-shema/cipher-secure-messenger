import CipherCore
import CipherDesign
import SwiftUI

/// The disappearing-messages picker for the conversation header: off, 30 s, 5 min, 1 h, 1 day.
/// A `Menu` rather than a sheet because changing the timer is a one-tap decision that both sides
/// see announced in the transcript; the current choice is ticked and mirrored on the label.
struct DisappearingTimerMenu: View {
    let current: DisappearingTimer
    let onSelect: (DisappearingTimer) -> Void

    init(current: DisappearingTimer, onSelect: @escaping (DisappearingTimer) -> Void) {
        self.current = current
        self.onSelect = onSelect
    }

    /// Convenience over the raw seconds stored on `Conversation.disappearingTimer`.
    init(seconds: TimeInterval?, onSelect: @escaping (DisappearingTimer) -> Void) {
        self.init(current: DisappearingTimer(seconds: seconds), onSelect: onSelect)
    }

    var body: some View {
        Menu {
            Section {
                ForEach(DisappearingTimer.allCases) { timer in
                    Button {
                        onSelect(timer)
                    } label: {
                        if timer == current {
                            Label(timer.title, systemImage: "checkmark")
                        } else {
                            Text(timer.title)
                        }
                    }
                    .accessibilityAddTraits(timer == current ? .isSelected : [])
                }
            } header: {
                Text(String(localized: "disappearing.menu.header", defaultValue: "Delete after reading"))
            }
        } label: {
            Label {
                Text(String(localized: "disappearing.menu.title", defaultValue: "Disappearing messages"))
                if current.isEnabled {
                    Text(current.title)
                }
            } icon: {
                Image(systemName: current.systemImage)
            }
        }
        .accessibilityLabel(String(localized: "disappearing.menu.a11y", defaultValue: "Disappearing messages"))
        .accessibilityValue(current.title)
    }
}

/// Compact header badge showing the active timer next to the presence line.
struct DisappearingTimerBadge: View {
    let timer: DisappearingTimer

    var body: some View {
        if timer.isEnabled {
            Label(timer.badge, systemImage: "timer")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(CipherColor.accent)
                .padding(.horizontal, CipherSpacing.xs + 2)
                .padding(.vertical, 2)
                .background(CipherColor.accent.opacity(0.12), in: Capsule())
                .accessibilityLabel(String(localized: "disappearing.badge.a11y",
                                           defaultValue: "Messages disappear \(timer.sentenceFragment)"))
        }
    }
}

#Preview("Menu") {
    @Previewable @State var current = DisappearingTimer.fiveMinutes
    VStack(spacing: CipherSpacing.xl) {
        Menu {
            DisappearingTimerMenu(current: current) { current = $0 }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
        }
        DisappearingTimerBadge(timer: current)
        Text(current.title)
            .font(CipherTypography.body)
            .foregroundStyle(CipherColor.textSecondary)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
