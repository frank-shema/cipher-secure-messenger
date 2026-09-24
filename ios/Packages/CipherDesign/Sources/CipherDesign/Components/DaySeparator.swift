import SwiftUI

/// A centered date chip with hairlines, used between message days.
public struct DaySeparator: View {
    private let date: Date

    /// Creates a separator for `date`.
    public init(date: Date) {
        self.date = date
    }

    public var body: some View {
        HStack(spacing: CipherSpacing.md) {
            CipherColor.divider.frame(height: 1)
            Text(DaySeparator.label(for: date))
                .font(CipherTypography.caption)
                .foregroundStyle(CipherColor.textSecondary)
                .padding(.horizontal, CipherSpacing.md)
                .padding(.vertical, CipherSpacing.xs)
                .background(CipherColor.surfaceElevated, in: Capsule())
            CipherColor.divider.frame(height: 1)
        }
        .padding(.vertical, CipherSpacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(DaySeparator.label(for: date)))
    }

    /// "Today", "Yesterday", a weekday within the last week, or a medium date.
    public static func label(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days > 0 && days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    VStack {
        DaySeparator(date: .now)
        DaySeparator(date: .now.addingTimeInterval(-86_400))
        DaySeparator(date: .now.addingTimeInterval(-3 * 86_400))
        DaySeparator(date: .now.addingTimeInterval(-40 * 86_400))
    }
    .padding(CipherSpacing.xl)
    .background(CipherColor.background)
}
