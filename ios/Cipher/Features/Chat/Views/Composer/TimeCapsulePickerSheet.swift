import CipherDesign
import SwiftUI

/// Picks when a Time Capsule opens. Presets cover the common cases; the wheel handles birthdays.
/// The chosen instant is stored in the composer and travels inside the ciphertext as `unlockAt`.
struct TimeCapsulePickerSheet: View {
    @Binding var unlockAt: Date?
    let now: Date

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Date

    init(unlockAt: Binding<Date?>, now: Date) {
        _unlockAt = unlockAt
        self.now = now
        _selection = State(initialValue: unlockAt.wrappedValue ?? now.addingTimeInterval(60 * 60))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CipherSpacing.xl) {
                Text(String(
                    localized: "chat.capsule.explainer",
                    defaultValue: "The message is sealed on their device until this moment. The relay never knows there is a timer."
                ))
                    .font(.subheadline)
                    .foregroundStyle(CipherColor.textSecondary)

                HStack(spacing: CipherSpacing.sm) {
                    ForEach(ComposerOptions.capsulePresets, id: \.self) { preset in
                        let target = now.addingTimeInterval(preset)
                        Button {
                            selection = target
                        } label: {
                            Text(CountdownRing.label(forRemaining: preset))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, CipherSpacing.sm)
                        }
                        .buttonStyle(CipherButtonStyle(abs(selection.timeIntervalSince(target)) < 1 ? .primary : .ghost))
                        .accessibilityLabel(String(localized: "chat.capsule.preset.a11y",
                                                   defaultValue: "Open in \(CountdownRing.label(forRemaining: preset))"))
                    }
                }

                DatePicker(
                    String(localized: "chat.capsule.picker", defaultValue: "Opens at"),
                    selection: $selection,
                    in: now.addingTimeInterval(60)...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(CipherColor.accentSecondary)

                Spacer()

                CipherButton(String(localized: "chat.capsule.seal", defaultValue: "Seal until then"), systemImage: "envelope.badge.clock") {
                    unlockAt = selection
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(CipherSpacing.xl)
            .background(CipherColor.background.ignoresSafeArea())
            .navigationTitle(String(localized: "chat.capsule.title", defaultValue: "Time Capsule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                }
                if unlockAt != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(String(localized: "chat.capsule.remove", defaultValue: "Remove")) {
                            unlockAt = nil
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    @Previewable @State var unlockAt: Date?
    TimeCapsulePickerSheet(unlockAt: $unlockAt, now: PreviewMessaging.frozenNow)
}
