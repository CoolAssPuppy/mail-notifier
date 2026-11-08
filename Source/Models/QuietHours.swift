import Foundation

/// A daily interval in the Mac's local time. The start is included and the end is excluded.
struct QuietHours {
    let isEnabled: Bool
    let startMinute: Int
    let endMinute: Int

    init(isEnabled: Bool, startMinute: Int, endMinute: Int) {
        self.isEnabled = isEnabled
        self.startMinute = Self.normalizedMinute(startMinute)
        self.endMinute = Self.normalizedMinute(endMinute)
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled, startMinute != endMinute else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return false }
        let currentMinute = hour * 60 + minute

        if startMinute < endMinute {
            return currentMinute >= startMinute && currentMinute < endMinute
        }
        return currentMinute >= startMinute || currentMinute < endMinute
    }

    func shouldSuppress(receivedAt: Date?, deliveredAt: Date,
                        calendar: Calendar = .current) -> Bool {
        contains(deliveredAt, calendar: calendar) ||
            (receivedAt.map { contains($0, calendar: calendar) } ?? false)
    }

    /// Give the time picker a fixed day so today's daylight-saving gap cannot change its hour.
    static func pickerDate(for minute: Int, calendar: Calendar = .current) -> Date {
        let normalized = normalizedMinute(minute)
        let components = DateComponents(year: 2001, month: 1, day: 15,
                                        hour: normalized / 60, minute: normalized % 60)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    static func normalizedMinute(_ minute: Int) -> Int {
        min(max(minute, 0), 1_439)
    }
}
