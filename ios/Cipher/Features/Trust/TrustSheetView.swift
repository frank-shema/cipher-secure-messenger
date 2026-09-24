import CipherCore
import CipherDesign
import SwiftUI

/// "Why this chat is secure": the ring, then every protection as a check or cross with the action
/// that flips it. Navigation actions dismiss the sheet first so the destination is not stacked under
/// it; the disappearing-timer action stays put and the ring re-scores in place.
struct TrustSheetView: View {
    let viewModel: TrustRingViewModel
    let actions: TrustActions
    /// Injected so previews render stable dates; the chat passes its own clock.
    var now: () -> Date = { Date() }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CipherSpacing.xl) {
                    TrustSheetHeader(viewModel: viewModel)
                    if viewModel.reasons.isEmpty {
                        SkeletonView(cornerRadius: CipherRadius.lg)
                            .frame(height: 220)
                            .accessibilityHidden(true)
                    } else {
                        protections
                    }
                    footer
                }
                .padding(.horizontal, CipherSpacing.lg)
                .padding(.bottom, CipherSpacing.xxl)
            }
            .background(CipherColor.background.ignoresSafeArea())
            .navigationTitle(String(localized: "trust.sheet.title", defaultValue: "Why this chat is secure"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                        .accessibilityLabel(String(localized: "trust.sheet.done.a11y", defaultValue: "Close trust details"))
                }
            }
            .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: viewModel.report)
            .task { viewModel.start() }
            .onDisappear { viewModel.stop() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var protections: some View {
        SectionCard(title: String(localized: "trust.sheet.section.protections", defaultValue: "Protections")) {
            ForEach(Array(viewModel.reasons.enumerated()), id: \.element.id) { index, reason in
                if index > 0 {
                    Divider().overlay(CipherColor.divider)
                }
                TrustReasonRow(
                    reason: reason,
                    contact: viewModel.contact,
                    disappearingTimer: viewModel.conversation.disappearingTimer,
                    now: now(),
                    actions: dismissingActions
                )
                .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .bottom)))
            }
        }
    }

    private var footer: some View {
        Label {
            Text(String(
                localized: "trust.sheet.footer",
                defaultValue: "Scored on this device from your pinned keys and settings. Nothing is sent to the relay."
            ))
        } icon: {
            Image(systemName: "iphone.and.arrow.forward.inward")
                .accessibilityHidden(true)
        }
        .font(CipherTypography.caption)
        .foregroundStyle(CipherColor.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Verification and review are pushes on the host's navigation stack, so the sheet leaves first.
    private var dismissingActions: TrustActions {
        TrustActions(
            onVerifyKeys: {
                dismiss()
                actions.onVerifyKeys()
            },
            onEnableDisappearing: { timer in
                actions.onEnableDisappearing(timer)
                var updated = viewModel.conversation
                updated.disappearingTimer = timer
                viewModel.update(conversation: updated)
            },
            onReviewKeyChange: {
                dismiss()
                actions.onReviewKeyChange()
            }
        )
    }
}

#Preview("Unverified") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            TrustSheetView(viewModel: TrustPreview.viewModel(.unverified), actions: TrustActions(), now: { PreviewMessaging.frozenNow })
        }
}

#Preview("Key changed") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            TrustSheetView(viewModel: TrustPreview.viewModel(.keyChanged), actions: TrustActions(), now: { PreviewMessaging.frozenNow })
        }
}

#Preview("Verified") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            TrustSheetView(viewModel: TrustPreview.viewModel(.verified), actions: TrustActions(), now: { PreviewMessaging.frozenNow })
        }
}
