import Foundation
import SwiftData

struct DayTopicStat: Identifiable, Equatable {
    var id: UUID
    var name: String
    var color: String
    var seconds: Int
}

struct DayStats: Equatable {
    var totalSeconds: Int
    var topics: [DayTopicStat]
}

struct TopicStat: Identifiable, Equatable {
    var id: UUID
    var name: String
    var color: String
    var totalSeconds: Int
}

struct WeekDayStat: Identifiable, Equatable {
    var id: String { date }
    var date: String
    var label: String
    var seconds: Int
    var minutes: Int
}

struct ChartBucket: Identifiable, Equatable {
    var id: String
    var label: String
    var seconds: Int
}

struct AppStats: Equatable {
    var todaySeconds: Int
    var totalSeconds: Int
    var days: [String: DayStats]
    var week: [WeekDayStat]
    var topics: [TopicStat]
    var trackingStartDate: String?
    var calendarEpoch: String
    /// Day totals keyed by YYYY-MM-DD for chart aggregation.
    var dayTotals: [String: Int]
}

enum StatisticsService {
    static func getStats(
        topics: [Topic],
        sessions: [StudySession],
        now: Date = .now
    ) -> AppStats {
        let todayKey = TimeUtils.chicagoDateKey(for: now)
        let earliest = topics.map(\.createdAt).min()
        let trackingStart = TimeUtils.trackingStartDateKey(earliestTopicCreatedAt: earliest)

        var todaySeconds = 0
        var totalSeconds = 0
        var dayMap: [String: [UUID: DayTopicStat]] = [:]
        var dayTotals: [String: Int] = [:]
        var topicTotals: [UUID: TopicStat] = [:]

        for topic in topics {
            topicTotals[topic.id] = TopicStat(
                id: topic.id,
                name: topic.name,
                color: topic.color,
                totalSeconds: 0
            )
        }

        for session in sessions {
            guard let topic = session.topic else { continue }
            let effective = session.effectiveSeconds(at: now)
            guard effective > 0 else { continue }

            let allocation = TimeUtils.allocateAccumulatedToChicagoDays(
                end: session.endMoment(at: now),
                accumulatedSeconds: effective
            )

            var counted = 0
            for (day, seconds) in allocation {
                if let trackingStart, day < trackingStart { continue }
                guard seconds > 0 else { continue }

                counted += seconds
                dayTotals[day, default: 0] += seconds

                if day == todayKey {
                    todaySeconds += seconds
                }

                var topicsForDay = dayMap[day] ?? [:]
                var row = topicsForDay[topic.id] ?? DayTopicStat(
                    id: topic.id,
                    name: topic.name,
                    color: topic.color,
                    seconds: 0
                )
                row.seconds += seconds
                topicsForDay[topic.id] = row
                dayMap[day] = topicsForDay
            }

            var topicStat = topicTotals[topic.id] ?? TopicStat(
                id: topic.id,
                name: topic.name,
                color: topic.color,
                totalSeconds: 0
            )
            topicStat.totalSeconds += counted
            topicTotals[topic.id] = topicStat
            totalSeconds += counted
        }

        var days: [String: DayStats] = [:]
        for (day, topicDict) in dayMap {
            let topicRows = topicDict.values.sorted {
                if $0.seconds != $1.seconds { return $0.seconds > $1.seconds }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            days[day] = DayStats(
                totalSeconds: topicRows.reduce(0) { $0 + $1.seconds },
                topics: topicRows
            )
        }

        let sortedTopics = topicTotals.values.sorted {
            if $0.totalSeconds != $1.totalSeconds {
                return $0.totalSeconds > $1.totalSeconds
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return AppStats(
            todaySeconds: todaySeconds,
            totalSeconds: totalSeconds,
            days: days,
            week: weekSeries(containing: todayKey, dayTotals: dayTotals),
            topics: sortedTopics,
            trackingStartDate: trackingStart,
            calendarEpoch: TimeUtils.calendarEpochKey,
            dayTotals: dayTotals
        )
    }

    static func weekSeries(
        containing focusKey: String,
        dayTotals: [String: Int]
    ) -> [WeekDayStat] {
        TimeUtils.weekKeys(containing: focusKey).map { dayKey in
            let seconds = max(0, dayTotals[dayKey] ?? 0)
            return WeekDayStat(
                date: dayKey,
                label: TimeUtils.weekdayLabel(for: dayKey),
                seconds: seconds,
                minutes: seconds / 60
            )
        }
    }

    /// 12 monthly buckets for a year.
    static func yearMonthBuckets(year: Int, dayTotals: [String: Int]) -> [ChartBucket] {
        (1...12).map { month in
            let prefix = String(format: "%04d-%02d", year, month)
            let seconds = dayTotals
                .filter { $0.key.hasPrefix(prefix) }
                .reduce(0) { $0 + $1.value }
            return ChartBucket(
                id: prefix,
                label: TimeUtils.shortMonthLabel(month: month),
                seconds: seconds
            )
        }
    }

    /// One bucket per day of the selected month.
    static func monthDayBuckets(year: Int, month: Int, dayTotals: [String: Int]) -> [ChartBucket] {
        let totalDays = TimeUtils.daysInMonth(year: year, month: month)
        return (1...totalDays).map { day in
            let key = String(format: "%04d-%02d-%02d", year, month, day)
            return ChartBucket(
                id: key,
                label: "\(day)",
                seconds: max(0, dayTotals[key] ?? 0)
            )
        }
    }

    /// 7 weekday buckets (Mon–Sun) aggregated across the selected month.
    static func monthWeekdayBuckets(year: Int, month: Int, dayTotals: [String: Int]) -> [ChartBucket] {
        let totalDays = TimeUtils.daysInMonth(year: year, month: month)
        var totals = Array(repeating: 0, count: 7)
        for day in 1...totalDays {
            let key = String(format: "%04d-%02d-%02d", year, month, day)
            let weekday = TimeUtils.mondayBasedWeekday(year: year, month: month, day: day)
            totals[weekday] += max(0, dayTotals[key] ?? 0)
        }
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return labels.enumerated().map { index, label in
            ChartBucket(id: "wd-\(index)", label: label, seconds: totals[index])
        }
    }

    /// Topic totals for days matching a date-key prefix (e.g. "2026-" or "2026-07-").
    static func topicBreakdown(
        dayPrefix: String,
        days: [String: DayStats]
    ) -> [DayTopicStat] {
        var map: [UUID: DayTopicStat] = [:]
        for (key, day) in days where key.hasPrefix(dayPrefix) {
            for topic in day.topics {
                var row = map[topic.id] ?? DayTopicStat(
                    id: topic.id,
                    name: topic.name,
                    color: topic.color,
                    seconds: 0
                )
                row.seconds += topic.seconds
                map[topic.id] = row
            }
        }
        return map.values.sorted {
            if $0.seconds != $1.seconds { return $0.seconds > $1.seconds }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Topic totals for an explicit set of day keys (e.g. one week).
    static func topicBreakdown(
        dayKeys: [String],
        days: [String: DayStats]
    ) -> [DayTopicStat] {
        var map: [UUID: DayTopicStat] = [:]
        for key in dayKeys {
            for topic in days[key]?.topics ?? [] {
                var row = map[topic.id] ?? DayTopicStat(
                    id: topic.id,
                    name: topic.name,
                    color: topic.color,
                    seconds: 0
                )
                row.seconds += topic.seconds
                map[topic.id] = row
            }
        }
        return map.values.sorted {
            if $0.seconds != $1.seconds { return $0.seconds > $1.seconds }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
