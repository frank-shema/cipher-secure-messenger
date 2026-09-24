import CipherCore
import CipherDesign
import Foundation
import Observation
import UIKit

/// State for `SettingsView`: the public keys (read from the identity store, never the private halves),
/// the relay address override and the DEBUG demo companion switch.
@MainActor
@Observable
final class SettingsViewModel {
    enum KeysState: Hashable {
        case loading
        case loaded(identityKey: String, signingKey: String)
        case unavailable(String)
    }

    private(set) var keys: KeysState = .loading
    var serverURLText: String
    private(set) var serverIssue: String?
    private(set) var activeEndpoints: ServerEndpoints
    var demoCompanionEnabled: Bool {
        didSet { AppPreferences.setDemoCompanionEnabled(demoCompanionEnabled, in: defaults) }
    }

    @ObservationIgnored private let container: AppContainer
    @ObservationIgnored private let defaults: UserDefaults

    init(container: AppContainer) {
        self.container = container
        self.defaults = container.defaults
        self.serverURLText = AppPreferences.serverURLOverride(in: container.defaults) ?? ""
        self.activeEndpoints = container.endpoints
        self.demoCompanionEnabled = AppPreferences.isDemoCompanionEnabled(in: container.defaults)
    }

    /// "0.1.0 (1)" from the bundle; falls back to "—" in previews where the bundle is not the app.
    var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String
        let build = info["CFBundleVersion"] as? String
        switch (short, build) {
        case let (short?, build?): return "\(short) (\(build))"
        case let (short?, nil): return short
        default: return "—"
        }
    }

    /// True when the typed override differs from what this launch is using, so the UI can say a
    /// restart is needed: the API client is built once at launch from the resolved endpoints.
    var overrideNeedsRestart: Bool {
        ServerEndpoints.resolve(override: AppPreferences.serverURLOverride(in: defaults)) != activeEndpoints
    }

    func loadKeys() async {
        do {
            let upload = try await container.identityKeyStore.publicKeys()
            keys = .loaded(identityKey: upload.identityKey.base64EncodedString(), signingKey: upload.signingKey.base64EncodedString())
        } catch {
            AppLog.settings.notice("public keys unavailable: \(String(describing: type(of: error)), privacy: .public)")
            keys = .unavailable(PresentableProblem(error: error).detail)
        }
    }

    func applyServerURL() {
        let trimmed = serverURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            AppPreferences.setServerURLOverride(nil, in: defaults)
            serverIssue = nil
            container.toastCenter.show(
                String(localized: "settings.server.reset.toast", defaultValue: "Using the default relay"),
                style: .success,
                systemImage: "server.rack"
            )
            return
        }
        guard ServerEndpoints.parse(trimmed) != nil else {
            serverIssue = String(localized: "settings.server.invalid", defaultValue: "Enter an http:// or https:// address with a host.")
            return
        }
        AppPreferences.setServerURLOverride(trimmed, in: defaults)
        serverIssue = nil
        AppLog.settings.info("server override saved")
        container.toastCenter.show(
            String(localized: "settings.server.saved.toast", defaultValue: "Relay address saved"),
            style: .success,
            systemImage: "checkmark"
        )
    }

    func resetServerURL() {
        serverURLText = ""
        applyServerURL()
    }

    func copy(_ value: String, describedAs label: String) {
        UIPasteboard.general.string = value
        container.haptics.play(.sent)
        container.toastCenter.show(
            label + " " + String(localized: "settings.copied.suffix", defaultValue: "copied"),
            style: .success,
            systemImage: "doc.on.doc"
        )
    }
}
