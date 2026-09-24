import CipherCore
import CipherDesign
import SwiftUI

/// Sheet that walks through confirming, choosing and repeating a PIN. The pad is re-created on every
/// step (`.id(step)`) so a completed entry never carries over into the next prompt.
struct PINSetupSheet: View {
    @State private var model: PINSetupViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(intent: PINSetupIntent, lock: AppLockManager) {
        _model = State(initialValue: PINSetupViewModel(intent: intent, lock: lock))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CipherColor.background.ignoresSafeArea()
                VStack(spacing: CipherSpacing.xl) {
                    header
                    if model.canChooseLength {
                        lengthPicker
                    }
                    PINPadView(digits: model.digits, errorTrigger: model.errorTrigger) { pin in
                        Task { await model.submit(pin) }
                    }
                    .id(model.step)
                    .transition(reduceMotion ? .opacity : .push(from: .trailing))
                    feedback
                }
                .padding(CipherSpacing.xl)
                .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: model.step)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                        .disabled(model.isBusy)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(model.isBusy)
        .onChange(of: model.isFinished) { _, finished in
            if finished { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: CipherSpacing.sm) {
            Image(systemName: model.intent.isDuress ? "theatermasks.fill" : "lock.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(CipherColor.accent)
                .accessibilityHidden(true)
            Text(model.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(CipherColor.textPrimary)
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var lengthPicker: some View {
        Picker(String(localized: "pinSetup.length", defaultValue: "PIN length"), selection: $model.newLength) {
            ForEach(PINLength.allCases, id: \.self) { length in
                Text(String(localized: "pinSetup.length.digits", defaultValue: "\(length.rawValue) digits")).tag(length)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
        .accessibilityLabel(String(localized: "pinSetup.length", defaultValue: "PIN length"))
    }

    @ViewBuilder
    private var feedback: some View {
        if let message = model.message {
            Text(message)
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.danger)
                .multilineTextAlignment(.center)
                .transition(.opacity)
        } else if model.step == .enterNew, !model.intent.isDuress {
            Text(String(localized: "pinSetup.hint.strength", defaultValue: "Avoid repeated digits and runs like 1234."))
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview("Create PIN") {
    PINSetupSheet(intent: .createPIN, lock: .preview(enabled: false, locked: false))
}

#Preview("Change duress PIN") {
    PINSetupSheet(intent: .changeDuressPIN, lock: .preview(locked: false))
}
