import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Query(sort: \Topic.name) private var topics: [Topic]
    @Query private var sessions: [StudySession]

    @State private var calendarMode: CalendarViewMode = .week
    @State private var focusKey: String

    /// Chart/calendar ignore in-progress sessions so values stay fixed until Stop.
    private var completedSessions: [StudySession] {
        sessions.filter { $0.status == .completed }
    }

    private var stats: AppStats {
        StatisticsService.getStats(
            topics: topics,
            sessions: completedSessions
        )
    }

    private var todayKey: String {
        TimeUtils.chicagoTodayParts().todayKey
    }

    private var canGoPrev: Bool {
        switch calendarMode {
        case .year:
            let year = TimeUtils.parts(from: focusKey)?.year ?? 2026
            return TimeUtils.canGoToPreviousYear(year)
        case .month:
            let parts = TimeUtils.parts(from: focusKey) ?? (2026, 1, 1)
            return TimeUtils.canGoToPreviousMonth(year: parts.year, month: parts.month)
        case .week:
            return TimeUtils.canGoToPreviousWeek(containing: focusKey)
        }
    }

    init() {
        let parts = TimeUtils.chicagoTodayParts()
        _focusKey = State(initialValue: parts.todayKey)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StudyCalendarView(
                        viewMode: $calendarMode,
                        focusKey: focusKey,
                        days: stats.days,
                        todayKey: todayKey,
                        trackingStartDate: stats.trackingStartDate,
                        canGoPrev: canGoPrev,
                        onPrev: goPrev,
                        onToday: goToday,
                        onNext: goNext,
                        onSelectDay: { key in
                            focusKey = key
                            calendarMode = .week
                        },
                        onSelectMonth: { year, month in
                            focusKey = String(format: "%04d-%02d-01", year, month)
                            calendarMode = .month
                        }
                    )

                    chartSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        let parts = TimeUtils.parts(from: focusKey) ?? (2026, 1, 1)
        switch calendarMode {
        case .year:
            AggregateBarChartView(
                title: "Total study hours in \(parts.year)",
                buckets: StatisticsService.yearMonthBuckets(
                    year: parts.year,
                    dayTotals: stats.dayTotals
                ),
                topicBreakdown: StatisticsService.topicBreakdown(
                    dayPrefix: String(format: "%04d-", parts.year),
                    days: stats.days
                )
            )
        case .month:
            AggregateBarChartView(
                title: "Study hours distribution by day",
                buckets: StatisticsService.monthWeekdayBuckets(
                    year: parts.year,
                    month: parts.month,
                    dayTotals: stats.dayTotals
                ),
                topicBreakdown: StatisticsService.topicBreakdown(
                    dayPrefix: String(format: "%04d-%02d-", parts.year, parts.month),
                    days: stats.days
                )
            )
        case .week:
            WeekChartView(
                week: StatisticsService.weekSeries(
                    containing: focusKey,
                    dayTotals: stats.dayTotals
                ),
                dayDetails: stats.days
            )
        }
    }

    private func goPrev() {
        guard canGoPrev else { return }
        switch calendarMode {
        case .year:
            guard let parts = TimeUtils.parts(from: focusKey) else { return }
            focusKey = String(format: "%04d-%02d-%02d", parts.year - 1, parts.month, min(parts.day, 28))
        case .month:
            guard let parts = TimeUtils.parts(from: focusKey) else { return }
            if parts.month == 1 {
                focusKey = String(format: "%04d-12-01", parts.year - 1)
            } else {
                focusKey = String(format: "%04d-%02d-01", parts.year, parts.month - 1)
            }
        case .week:
            focusKey = TimeUtils.addDays(to: focusKey, days: -7)
        }
    }

    private func goNext() {
        switch calendarMode {
        case .year:
            guard let parts = TimeUtils.parts(from: focusKey) else { return }
            focusKey = String(format: "%04d-%02d-%02d", parts.year + 1, parts.month, min(parts.day, 28))
        case .month:
            guard let parts = TimeUtils.parts(from: focusKey) else { return }
            if parts.month == 12 {
                focusKey = String(format: "%04d-01-01", parts.year + 1)
            } else {
                focusKey = String(format: "%04d-%02d-01", parts.year, parts.month + 1)
            }
        case .week:
            focusKey = TimeUtils.addDays(to: focusKey, days: 7)
        }
    }

    private func goToday() {
        focusKey = todayKey
    }
}
