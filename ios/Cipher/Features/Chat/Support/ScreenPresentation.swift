/// How a screen that can be both modal and routed is being shown. Modal screens bring their own
/// `NavigationStack` and a Done button; pushed ones live on the host's stack and inherit its bar.
enum ScreenPresentation: Hashable, Sendable {
    case sheet
    case pushed
}
