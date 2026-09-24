import SwiftUI

/// The number of digits a PIN has.
public enum PINLength: Int, Sendable, CaseIterable {
    case four = 4
    case six = 6
}

/// A numeric keypad with a dots indicator. When the last digit is entered
/// `onComplete` receives the PIN; bump `errorTrigger` to shake the dots and clear.
public struct PINPadView: View {
    private let digits: PINLength
    private let errorTrigger: Int
    private let onComplete: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entry = ""
    @State private var isShowingError = false

    /// Creates a PIN pad.
    /// - Parameters:
    ///   - digits: PIN length, four or six.
    ///   - errorTrigger: Increment to signal a wrong PIN; the dots shake and the entry clears.
    ///   - onComplete: Called with the full PIN once all digits are entered.
    public init(digits: PINLength = .six, errorTrigger: Int = 0, onComplete: @escaping (String) -> Void) {
        self.digits = digits
        self.errorTrigger = errorTrigger
        self.onComplete = onComplete
    }

    private let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    public var body: some View {
        VStack(spacing: CipherSpacing.xxl) {
            dots
            VStack(spacing: CipherSpacing.lg) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: CipherSpacing.xl) {
                        ForEach(row, id: \.self) { digit in key(digit) }
                    }
                }
                HStack(spacing: CipherSpacing.xl) {
                    Color.clear.frame(width: 76, height: 76)
                    key("0")
                    PINKeyButton(accessibilityLabel: "Delete", action: deleteLast) {
                        Image(systemName: "delete.left").font(.title2)
                    }
                    .disabled(entry.isEmpty)
                }
            }
        }
        .onChange(of: errorTrigger) { _, _ in
            entry = ""
            isShowingError = true
        }
        .onChange(of: entry) { _, value in
            if !value.isEmpty { isShowingError = false }
            if value.count == digits.rawValue { onComplete(value) }
        }
        .accessibilityElement(children: .contain)
    }

    private var dots: some View {
        HStack(spacing: CipherSpacing.lg) {
            ForEach(0..<digits.rawValue, id: \.self) { index in
                Circle()
                    .fill(index < entry.count ? dotColor : CipherColor.textSecondary.opacity(0.25))
                    .frame(width: 14, height: 14)
                    .scaleEffect(index == entry.count - 1 && !reduceMotion ? 1.15 : 1)
            }
        }
        .animation(CipherMotion.snappy.reduced(reduceMotion), value: entry)
        .shake(on: errorTrigger, reduceMotion: reduceMotion)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.count) of \(digits.rawValue) digits entered")
        .accessibilityValue(isShowingError ? "Incorrect PIN" : "")
    }

    private var dotColor: Color { isShowingError ? CipherColor.danger : CipherColor.accent }

    private func key(_ digit: String) -> some View {
        PINKeyButton(accessibilityLabel: digit, action: { append(digit) }, label: { Text(digit) })
    }

    private func append(_ digit: String) {
        guard entry.count < digits.rawValue else { return }
        entry.append(digit)
    }

    private func deleteLast() {
        guard !entry.isEmpty else { return }
        entry.removeLast()
    }
}

#Preview("PINPadView") {
    struct Demo: View {
        @State private var errors = 0
        var body: some View {
            PINPadView(digits: .six, errorTrigger: errors) { pin in
                if pin != "123456" { errors += 1 }
            }
            .padding(CipherSpacing.xl)
            .background(CipherColor.background)
        }
    }
    return Demo()
}
