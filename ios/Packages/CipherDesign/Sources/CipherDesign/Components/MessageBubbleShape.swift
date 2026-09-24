import SwiftUI

/// A rounded message bubble with an optional tail on the leading or trailing
/// bottom corner.
public struct MessageBubbleShape: Shape {
    /// Which corner carries the tail.
    public enum Tail: Sendable {
        case leading, trailing, none
    }

    private let tail: Tail
    private let radius: CGFloat

    /// Creates a bubble shape.
    /// - Parameters:
    ///   - tail: Tail placement. Incoming bubbles use `.leading`, outgoing `.trailing`.
    ///   - radius: Corner radius; defaults to `CipherRadius.bubble`.
    public init(tail: Tail, radius: CGFloat = CipherRadius.bubble) {
        self.tail = tail
        self.radius = radius
    }

    public func path(in rect: CGRect) -> Path {
        let corner = min(radius, min(rect.width, rect.height) / 2)
        let tailSize: CGFloat = tail == .none ? 0 : 6
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.minY + corner), radius: corner,
                    startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

        if tail == .trailing {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX + tailSize, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY - tailSize / 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - corner, y: rect.maxY),
                control: CGPoint(x: rect.maxX - corner / 2, y: rect.maxY)
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
            path.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner), radius: corner,
                        startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }

        if tail == .leading {
            path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX - tailSize, y: rect.maxY),
                control: CGPoint(x: rect.minX + corner / 2, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - corner),
                control: CGPoint(x: rect.minX, y: rect.maxY - tailSize / 2)
            )
        } else {
            path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + corner, y: rect.maxY - corner), radius: corner,
                        startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.addArc(center: CGPoint(x: rect.minX + corner, y: rect.minY + corner), radius: corner,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(alignment: .leading, spacing: CipherSpacing.md) {
        Text("Keys verified. Nobody else can read this.")
            .font(CipherTypography.body)
            .foregroundStyle(CipherColor.textPrimary)
            .padding(.horizontal, CipherSpacing.lg)
            .padding(.vertical, CipherSpacing.md)
            .background(CipherColor.bubbleIncoming, in: MessageBubbleShape(tail: .leading))
        Text("Security you can see and feel.")
            .font(CipherTypography.body)
            .foregroundStyle(CipherColor.bubbleOutgoingText)
            .padding(.horizontal, CipherSpacing.lg)
            .padding(.vertical, CipherSpacing.md)
            .background(CipherGradient.outgoingBubble, in: MessageBubbleShape(tail: .trailing))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
