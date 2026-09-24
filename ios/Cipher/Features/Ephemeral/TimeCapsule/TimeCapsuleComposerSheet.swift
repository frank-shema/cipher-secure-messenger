import CipherDesign
import SwiftUI

/// Picks when a Time Capsule opens: three presets or a custom date at least a minute out. The
/// result lands in the composer's `unlockAt` and travels inside the ciphertext; the sheet never
/// touches the network.
struct TimeCapsuleComposerSheet: View {
    @Binding var unlockAt: Date?
    let schedule: TimeCapsuleSchedule

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var choice: TimeCapsuleChoice
    @State private var customDate: Date
    @State private var problem: String?

    init(unlockAt: Binding<Date?>, now: @escaping @Sendable () -> Date = { Date() }) {
        _unlockAt = unlockAt
        let schedule = TimeCapsuleSchedule(now: now)
        self.schedule = schedule
        let existing = unlockAt.wrappedValue
        _choice = State(initialValue: existing.map(TimeCapsuleChoice.custom) ?? .preset(.oneHour))
        _customDate = State(initialValue: existing ?? schedule.now().addingTimeInterval(TimeCapsulePreset.oneHour.interval))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpacing.xl) {
                    presets
                    if choice.isCustom {
                        customPicker.transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    TimeCapsuleExplainer(unlockAt: schedule.preview(choice))
                    if let problem {
                        Text(problem)
                            .font(.footnote)
                            .foregroundStyle(CipherColor.danger)
                            .accessibilityLabel(problem)
                    }
                }
                .padding(CipherSpacing.xl)
                .animation(CipherMotion.snappy.crossfadeIfReduced(reduceMotion), value: choice.isCustom)
            }
            .safeAreaInset(edge: .bottom) { sealButton }
            .background(CipherColor.background.ignoresSafeArea())
            .navigationTitle(String(localized: "capsule.sheet.title", defaultValue: "Time Capsule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .presentationDetents([.large])
    }

    private var presets: some View {
        HStack(spacing: CipherSpacing.sm) {
            ForEach(TimeCapsulePreset.allCases) { preset in
                TimeCapsulePresetChip(title: preset.title, accessibilityLabel: preset.accessibilityLabel,
                                      isSelected: choice == .preset(preset)) {
                    choice = .preset(preset)
                    problem = nil
                }
            }
            TimeCapsulePresetChip(title: String(localized: "capsule.preset.custom", defaultValue: "Custom"),
                                  accessibilityLabel: String(localized: "capsule.preset.a11y.custom", defaultValue: "Pick a date and time"),
                                  isSelected: choice.isCustom) {
                customDate = max(customDate, schedule.earliestCustom)
                choice = .custom(customDate)
                problem = nil
            }
        }
    }

    private var customPicker: some View {
        DatePicker(
            String(localized: "capsule.picker.label", defaultValue: "Opens at"),
            selection: $customDate,
            in: schedule.earliestCustom...,
            displayedComponents: [.date, .hourAndMinute]
        )
        .datePickerStyle(.graphical)
        .tint(CipherColor.accentSecondary)
        .onChange(of: customDate) { _, date in
            choice = .custom(date)
            problem = nil
        }
        .accessibilityLabel(String(localized: "capsule.picker.a11y", defaultValue: "Unlock date and time"))
    }

    private var sealButton: some View {
        CipherButton(String(localized: "capsule.action.seal", defaultValue: "Seal until then"), systemImage: "envelope.badge.clock") {
            do {
                unlockAt = try schedule.resolve(choice)
                dismiss()
            } catch {
                problem = error.localizedDescription
            }
        }
        .padding(.horizontal, CipherSpacing.xl)
        .padding(.vertical, CipherSpacing.md)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
        }
        if unlockAt != nil {
            ToolbarItem(placement: .destructiveAction) {
                Button(String(localized: "capsule.action.remove", defaultValue: "Remove"), role: .destructive) {
                    unlockAt = nil
                    dismiss()
                }
            }
        }
    }
}

#Preview("New capsule") {
    @Previewable @State var unlockAt: Date?
    TimeCapsuleComposerSheet(unlockAt: $unlockAt)
}

#Preview("Editing") {
    @Previewable @State var unlockAt: Date? = Date().addingTimeInterval(86_400 * 2)
    TimeCapsuleComposerSheet(unlockAt: $unlockAt)
}
