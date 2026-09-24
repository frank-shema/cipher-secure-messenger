import CipherDesign
import SwiftUI

/// Dimmed surround with a square window, accent corner brackets and a sweeping scan line, plus the
/// instruction and the "not a Cipher code" hint. Purely decorative: the whole frame is scanned.
struct ViewfinderOverlay: View {
    let contactName: String
    /// Increments on every rejected code; drives the hint and its shake.
    let rejectionCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    private let window: CGFloat = 240

    var body: some View {
        ZStack {
            CipherColor.overlay
                .mask {
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerRadius: CipherRadius.lg)
                                .frame(width: window, height: window)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .ignoresSafeArea()
            frame
            VStack {
                Spacer()
                caption
                    .padding(.bottom, CipherSpacing.xxl)
            }
        }
        .onAppear { sweep = !reduceMotion }
        .accessibilityElement(children: .contain)
    }

    private var frame: some View {
        ZStack {
            CornerBrackets(length: 28, lineWidth: 4, cornerRadius: CipherRadius.lg)
                .stroke(CipherColor.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: window, height: window)
                .cipherShadow(.glow)
            if !reduceMotion {
                Rectangle()
                    .fill(CipherGradient.primaryAction)
                    .frame(width: window - 24, height: 2)
                    .opacity(0.9)
                    .offset(y: sweep ? window / 2 - 16 : -window / 2 + 16)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: sweep)
            }
        }
        .accessibilityHidden(true)
    }

    private var caption: some View {
        VStack(spacing: CipherSpacing.sm) {
            Text(String(localized: "verify.scanner.instruction", defaultValue: "Point at \(contactName)'s code"))
                .font(CipherTypography.headline)
                .foregroundStyle(.white)
            Text(String(localized: "verify.scanner.hint", defaultValue: "It's on their verification screen, under \"Your code\"."))
                .font(CipherTypography.caption)
                .foregroundStyle(.white.opacity(0.8))
            if rejectionCount > 0 {
                Label(
                    String(localized: "verify.scanner.rejected", defaultValue: "That's not a Cipher verification code"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.warning)
                .padding(.horizontal, CipherSpacing.md)
                .padding(.vertical, CipherSpacing.sm)
                .background(Color.black.opacity(0.55), in: .capsule)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .id(rejectionCount)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, CipherSpacing.xl)
        .animation(CipherMotion.gentle.crossfadeIfReduced(reduceMotion), value: rejectionCount)
    }
}

/// Four L-shaped brackets on the corners of a rounded square.
struct CornerBrackets: Shape {
    var length: CGFloat
    var lineWidth: CGFloat
    var cornerRadius: CGFloat

    /// A corner's position plus the direction (±1) its two arms extend in.
    private struct Corner {
        var origin: CGPoint
        var dx: CGFloat
        var dy: CGFloat
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let radius = cornerRadius
        let corners = [
            Corner(origin: CGPoint(x: inset.minX, y: inset.minY), dx: 1, dy: 1),
            Corner(origin: CGPoint(x: inset.maxX, y: inset.minY), dx: -1, dy: 1),
            Corner(origin: CGPoint(x: inset.maxX, y: inset.maxY), dx: -1, dy: -1),
            Corner(origin: CGPoint(x: inset.minX, y: inset.maxY), dx: 1, dy: -1)
        ]
        for corner in corners {
            let origin = corner.origin
            path.move(to: CGPoint(x: origin.x, y: origin.y + corner.dy * length))
            path.addLine(to: CGPoint(x: origin.x, y: origin.y + corner.dy * radius))
            path.addQuadCurve(to: CGPoint(x: origin.x + corner.dx * radius, y: origin.y), control: origin)
            path.addLine(to: CGPoint(x: origin.x + corner.dx * length, y: origin.y))
        }
        return path
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        ViewfinderOverlay(contactName: "Bob", rejectionCount: 1)
    }
}
