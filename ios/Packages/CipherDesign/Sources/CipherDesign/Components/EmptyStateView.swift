import SwiftUI

/// Centered illustration, title, message and optional action for empty screens.
public struct EmptyStateView: View {
    /// An optional call to action.
    public struct Action: Sendable {
        public let title: String
        public let handler: @MainActor @Sendable () -> Void

        /// Creates an action.
        public init(title: String, handler: @escaping @MainActor @Sendable () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    private let icon: String
    private let title: String
    private let message: String
    private let action: Action?

    /// Creates an empty state.
    /// - Parameters:
    ///   - icon: SF Symbol name.
    ///   - title: Short headline.
    ///   - message: Supporting copy.
    ///   - action: Optional primary action.
    public init(icon: String, title: String, message: String, action: Action? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action
    }

    public var body: some View {
        VStack(spacing: CipherSpacing.lg) {
            ZStack {
                Circle()
                    .fill(CipherGradient.hero)
                    .frame(width: 96, height: 96)
                    .opacity(0.25)
                    .blur(radius: 12)
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(CipherGradient.primaryAction)
            }
            .accessibilityHidden(true)
            VStack(spacing: CipherSpacing.sm) {
                Text(title)
                    .font(CipherTypography.headline)
                    .foregroundStyle(CipherColor.textPrimary)
                Text(message)
                    .font(CipherTypography.body)
                    .foregroundStyle(CipherColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let action {
                CipherButton(action.title) { action.handler() }
                    .frame(maxWidth: 280)
                    .padding(.top, CipherSpacing.sm)
            }
        }
        .padding(CipherSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    EmptyStateView(
        icon: "lock.shield",
        title: "No conversations yet",
        message: "Start a chat and every message is end-to-end encrypted before it leaves this device.",
        action: .init(title: "New message") {}
    )
    .background(CipherColor.background)
}
