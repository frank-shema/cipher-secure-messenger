import CipherDesign
import SwiftUI

/// The "Scan their code" sheet. Handles the camera permission states, shows the live viewfinder when
/// allowed and degrades to pasting the payload on the Simulator, on devices without a camera and when
/// permission was refused, so verification is never blocked by hardware.
struct QRScannerScreen: View {
    let contactName: String
    /// Returns `true` when the code was accepted; the sheet then dismisses itself.
    let onCode: @MainActor (String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var authorization = CameraAuthorization.current
    @State private var cameraError: CameraError?
    @State private var rejectionCount = 0
    @State private var isPastePresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                CipherColor.background.ignoresSafeArea()
                content
            }
            .navigationTitle(String(localized: "verify.scanner.title", defaultValue: "Scan their code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                        .foregroundStyle(CipherColor.accent)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPastePresented = true
                    } label: {
                        Label(String(localized: "verify.scanner.paste", defaultValue: "Paste code"), systemImage: "doc.on.clipboard")
                            .foregroundStyle(CipherColor.accent)
                    }
                    .accessibilityLabel(String(localized: "verify.scanner.paste.a11y", defaultValue: "Enter a verification code manually"))
                }
            }
        }
        .sheet(isPresented: $isPastePresented) {
            PastePayloadSheet(contactName: contactName, onSubmit: accept)
        }
        .task {
            if authorization == .undetermined {
                authorization = await CameraAuthorization.request()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let cameraError {
            fallback(
                icon: "camera.badge.ellipsis",
                title: cameraError.localizedDescription,
                message: String(
                    localized: "verify.scanner.fallback.paste",
                    defaultValue: "You can paste the code \(contactName) shares with you instead."
                )
            )
        } else {
            switch authorization {
            case .authorized:
                QRScannerView(onCode: accept, onFailure: { cameraError = $0 })
                    .ignoresSafeArea()
                ViewfinderOverlay(contactName: contactName, rejectionCount: rejectionCount)
            case .undetermined:
                ProgressView()
                    .tint(CipherColor.accent)
                    .accessibilityLabel(String(localized: "verify.scanner.requesting", defaultValue: "Requesting camera access"))
            case .denied, .restricted:
                fallback(
                    icon: "camera.fill",
                    title: String(localized: "verify.scanner.denied.title", defaultValue: "Camera access is off"),
                    message: String(
                        localized: "verify.scanner.denied.message",
                        defaultValue: "Allow the camera in Settings to scan \(contactName)'s code, or paste the code instead."
                    ),
                    showsSettings: true
                )
            case .unavailable:
                fallback(
                    icon: "qrcode.viewfinder",
                    title: String(localized: "verify.scanner.unavailable.title", defaultValue: "No camera here"),
                    message: String(
                        localized: "verify.scanner.unavailable.message",
                        defaultValue: "Paste the verification code \(contactName) shares with you."
                    )
                )
            }
        }
    }

    private func fallback(icon: String, title: String, message: String, showsSettings: Bool = false) -> some View {
        VStack(spacing: CipherSpacing.xl) {
            EmptyStateView(
                icon: icon,
                title: title,
                message: message,
                action: EmptyStateView.Action(title: String(localized: "verify.scanner.paste", defaultValue: "Paste code")) {
                    isPastePresented = true
                }
            )
            if showsSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                CipherButton(
                    String(localized: "verify.scanner.openSettings", defaultValue: "Open Settings"),
                    systemImage: "gear",
                    variant: .ghost
                ) {
                    openURL(url)
                }
                .padding(.horizontal, CipherSpacing.xxl)
            }
        }
    }

    private func accept(_ code: String) -> Bool {
        let accepted = onCode(code)
        if accepted {
            dismiss()
        } else {
            rejectionCount += 1
        }
        return accepted
    }
}

#Preview("Simulator fallback") {
    QRScannerScreen(contactName: "Bob") { _ in true }
}
