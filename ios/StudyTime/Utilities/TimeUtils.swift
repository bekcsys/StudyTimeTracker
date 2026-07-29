import Foundation

enum TimeUtils {
    static let chicago = TimeZone(identifier: "America/Chicago")!
    static let calendarEpoch = CalendarDate(year: 2026, month: 7, day: 1)
    static let calendarEpochKey = "2026-07-01"

    struct CalendarDate: Comparable {
        let year: Int
        let month: Int
        let day: Int

        var key: String {
            String(format: "%04d-%02d-%02d", year, month, day)
        }

        static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
            if lhs.year != rhs.year { return lhs.year < rhs.year }
            if lhs.month != rhs.month { return lhs.month < rhs.month }
            return lhs.day < rhs.day
        }

        static func from(key: String) -> CalendarDate? {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return CalendarDate(year: parts[0], month: parts[1], day: parts[2])
        }
    }

    private static var chicagoCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chicago
        return calendar
    }

    static func chicagoDateKey(for date: Date) -> String {
        let comps = chicagoCalendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            comps.year ?? 0,
            comps.month ?? 0,
            comps.day ?? 0
        )
    }

    static func chicagoTodayParts(now: Date = .now) -> (year: Int, month: Int, todayKey: String) {
        let comps = chicagoCalendar.dateComponents([.year, .month, .day], from: now)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        return (
            year,
            month,
            String(format: "%04d-%02d-%02d", year, month, day)
        )
    }

    static func trackingStartDateKey(earliestTopicCreatedAt: Date?) -> String? {
        guard let earliestTopicCreatedAt else { return nil }
        let topicDay = CalendarDate.from(key: chicagoDateKey(for: earliestTopicCreatedAt))!
        let start = max(calendarEpoch, topicDay)
        return start.key
    }

    static func addDays(to dateKey: String, days: Int) -> String {
        guard let base = dateFrom(key: dateKey) else { return dateKey }
        guard let shifted = chicagoCalendar.date(byAdding: .day, value: days, to: base) else {
            return dateKey
        }
        return chicagoDateKey(for: shifted)
    }

    static func dateFrom(key: String) -> Date? {
        guard let parts = CalendarDate.from(key: key) else { return nil }
        var comps = DateComponents()
        comps.year = parts.year
        comps.month = parts.month
        comps.day = parts.day
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return chicagoCalendar.date(from: comps)
    }

    static func isBeforeCalendarEpoch(year: Int, month: Int) -> Bool {
        year < calendarEpoch.year
            || (year == calendarEpoch.year && month < calendarEpoch.month)
    }

    static func canGoToPreviousMonth(year: Int, month: Int) -> Bool {
        if month == 1 {
            return !isBeforeCalendarEpoch(year: year - 1, month: 12)
        }
        return !isBeforeCalendarEpoch(year: year, month: month - 1)
    }

    static func allocateAccumulatedToChicagoDays(
        end: Date,
        accumulatedSeconds: Int
    ) -> [String: Int] {
        let seconds = max(0, accumulatedSeconds)
        guard seconds > 0 else { return [:] }
        let start = end.addingTimeInterval(TimeInterval(-seconds))
        return allocateSecondsAcrossChicagoDays(start: start, end: end)
    }

    static func allocateSecondsAcrossChicagoDays(
        start: Date,
        end: Date
    ) -> [String: Int] {
        var totals: [String: Int] = [:]
        var cursor = start
        guard end > cursor else { return totals }

        while cursor < end {
            let dayKey = chicagoDateKey(for: cursor)
            guard let nextMidnight = dateFrom(key: addDays(to: dayKey, days: 1)) else {
                break
            }
            let segmentEnd = min(end, nextMidnight)
            let seconds = Int(segmentEnd.timeIntervalSince(cursor))
            if seconds > 0 {
                totals[dayKey, default: 0] += seconds
            }
            cursor = segmentEnd
        }
        return totals
    }

    static func weekdayLabel(for dateKey: String) -> String {
        guard let date = dateFrom(key: dateKey) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = chicago
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    static func monthLabel(year: Int, month: Int) -> String {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = chicagoCalendar.date(from: comps) else {
            return "\(month)/\(year)"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = chicago
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = chicagoCalendar.date(from: comps),
              let range = chicagoCalendar.range(of: .day, in: .month, for: date)
        else {
            return 30
        }
        return range.count
    }

    /// Monday-based weekday index: Mon=0 … Sun=6
    static func mondayBasedWeekday(year: Int, month: Int, day: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        guard let date = chicagoCalendar.date(from: comps) else { return 0 }
        let weekday = chicagoCalendar.component(.weekday, from: date) // Sun=1
        return weekday == 1 ? 6 : weekday - 2
    }

    static func mondayBasedWeekday(for dateKey: String) -> Int {
        guard let parts = CalendarDate.from(key: dateKey) else { return 0 }
        return mondayBasedWeekday(year: parts.year, month: parts.month, day: parts.day)
    }

    /// Monday of the week that contains `dateKey`.
    static func weekStartKey(for dateKey: String) -> String {
        let offset = mondayBasedWeekday(for: dateKey)
        return addDays(to: dateKey, days: -offset)
    }

    static func weekKeys(containing dateKey: String) -> [String] {
        let start = weekStartKey(for: dateKey)
        return (0...6).map { addDays(to: start, days: $0) }
    }

    static func dayLabel(for dateKey: String) -> String {
        guard let date = dateFrom(key: dateKey) else { return dateKey }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = chicago
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }

    static func weekLabel(containing dateKey: String) -> String {
        let keys = weekKeys(containing: dateKey)
        guard let first = keys.first, let last = keys.last else { return dateKey }
        guard let start = dateFrom(key: first), let end = dateFrom(key: last) else {
            return "\(first) – \(last)"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = chicago
        formatter.dateFormat = "MMM d"
        let startText = formatter.string(from: start)
        formatter.dateFormat = "MMM d, yyyy"
        let endText = formatter.string(from: end)
        return "\(startText) – \(endText)"
    }

    static func shortMonthLabel(month: Int) -> String {
        var comps = DateComponents()
        comps.year = 2000
        comps.month = month
        comps.day = 1
        guard let date = chicagoCalendar.date(from: comps) else { return "\(month)" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = chicago
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    static func canGoToPreviousYear(_ year: Int) -> Bool {
        year - 1 >= calendarEpoch.year
    }

    static func canGoToPreviousDay(_ dateKey: String) -> Bool {
        let prev = addDays(to: dateKey, days: -1)
        return prev >= calendarEpochKey
    }

    static func canGoToPreviousWeek(containing dateKey: String) -> Bool {
        let prevEnd = addDays(to: weekStartKey(for: dateKey), days: -1)
        return prevEnd >= calendarEpochKey
    }

    static func parts(from dateKey: String) -> (year: Int, month: Int, day: Int)? {
        guard let parts = CalendarDate.from(key: dateKey) else { return nil }
        return (parts.year, parts.month, parts.day)
    }
}
